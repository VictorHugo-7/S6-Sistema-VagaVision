import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'garagem_controller.dart';
import 'projecao.dart';
import 'theme.dart';

/// Cena da garagem: desenha o pátio em 3D (perspectiva) com o visual do Figma
/// e trata os gestos (arrastar, pinça/scroll para zoom, toque para alternar a vaga).
class GaragemScene extends StatefulWidget {
  const GaragemScene({super.key, required this.controller});

  final GaragemController controller;

  @override
  State<GaragemScene> createState() => _GaragemSceneState();
}

class _GaragemSceneState extends State<GaragemScene> with SingleTickerProviderStateMixin {
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _ultimo = Duration.zero;
  Size _tamanho = Size.zero;
  double _escalaAnterior = 1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _ultimo).inMicroseconds / 1e6;
      _ultimo = elapsed;
      widget.controller.tick(math.min(dt, 0.05));
      _frame.value++;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _tamanho = Size(c.maxWidth, c.maxHeight);
      widget.controller.ajustarTela(_tamanho);
      return Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) widget.controller.zoom(math.exp(-e.scrollDelta.dy * 0.0015));
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) => _escalaAnterior = 1,
          onScaleUpdate: (d) {
            final delta = d.scale / _escalaAnterior;
            _escalaAnterior = d.scale;
            if (d.pointerCount >= 2 && delta != 1) widget.controller.zoom(delta);
            widget.controller.arrastar(d.focalPointDelta.dx, d.focalPointDelta.dy, _tamanho);
          },
          onTapUp: (d) => widget.controller.toque(d.localPosition, _tamanho),
          child: CustomPaint(
            size: Size.infinite,
            painter: _CenaPainter(widget.controller, _frame),
          ),
        ),
      );
    });
  }
}

class _Face {
  const _Face(this.normal, this.cantos);

  final V3 normal;
  final List<V3> cantos;
}

class _CenaPainter extends CustomPainter {
  _CenaPainter(this.c, Listenable repaint) : super(repaint: repaint);

  final GaragemController c;

  static const _corCabine = Cores.fundo;
  static const _corPneu = Color(0xFF14284A);

  // Faces visíveis de uma caixa unitária (a face de baixo nunca aparece).
  static const _faces = [
    _Face(V3(1, 0, 0), [V3(1, -1, -1), V3(1, -1, 1), V3(1, 1, 1), V3(1, 1, -1)]),
    _Face(V3(-1, 0, 0), [V3(-1, -1, 1), V3(-1, -1, -1), V3(-1, 1, -1), V3(-1, 1, 1)]),
    _Face(V3(0, 1, 0), [V3(-1, 1, -1), V3(1, 1, -1), V3(1, 1, 1), V3(-1, 1, 1)]),
    _Face(V3(0, 0, 1), [V3(-1, -1, 1), V3(1, -1, 1), V3(1, 1, 1), V3(-1, 1, 1)]),
    _Face(V3(0, 0, -1), [V3(1, -1, -1), V3(-1, -1, -1), V3(-1, 1, -1), V3(1, 1, -1)]),
  ];

  static final _luz = const V3(24, 32, 14).normalizado();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Cores.fundo);
    final cam = c.camara(size);

    _moldura(canvas, cam);
    for (final v in c.vagas) {
      _vaga(canvas, cam, v);
    }
    _divisorias(canvas, cam);

    // carros ordenados do mais longe para o mais perto (algoritmo do pintor)
    final itens = <(double, VoidCallback)>[];
    for (final v in c.vagas.where((v) => v.ocupada)) {
      itens.add((cam.distancia(V3(v.x, 0.5, v.z)), () => _carro(canvas, cam, v)));
    }
    itens.sort((a, b) => b.$1.compareTo(a.$1));
    for (final item in itens) {
      item.$2();
    }
  }

  /// Moldura branca arredondada do pátio (a "caixa" do Figma), no chão.
  void _moldura(Canvas canvas, Camara cam) {
    final pts = cam.poligono(_arredondado(0, 0, ConfigPatio.larguraPatio, ConfigPatio.profundidadePatio, 2.4, 0.005));
    if (pts == null) return;
    canvas.drawPath(
      Path()..addPolygon(pts, true),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = Cores.moldura,
    );
  }

  /// Retângulo da vaga: verde se livre, vermelho se ocupada.
  void _vaga(Canvas canvas, Camara cam, Vaga v) {
    final pts = cam.poligono(_arredondado(v.x, v.z, ConfigPatio.vagaW, ConfigPatio.vagaD, 0.35, 0.02));
    if (pts == null) return;
    canvas.drawPath(Path()..addPolygon(pts, true), Paint()..color = v.ocupada ? Cores.ocupada : Cores.livre);
  }

  /// Faixas cinza-claras entre as vagas vizinhas.
  void _divisorias(Canvas canvas, Camara cam) {
    final zFileira = ConfigPatio.aisle / 2 + ConfigPatio.vagaD / 2;
    for (final z in [-zFileira, zFileira]) {
      for (var i = 0; i < ConfigPatio.cols - 1; i++) {
        final x = (i - (ConfigPatio.cols - 1) / 2 + 0.5) * ConfigPatio.passo;
        _retanguloPlano(canvas, cam, x, z, 0.17, ConfigPatio.vagaD, 0.02, Cores.divisor);
      }
    }
  }

  /// Pontos de um retângulo com cantos arredondados no plano do chão (y fixo).
  List<V3> _arredondado(double cx, double cz, double w, double d, double r, double y) {
    const passos = 5;
    final hw = w / 2 - r;
    final hd = d / 2 - r;
    final cantos = [
      (1.0, -1.0, -math.pi / 2),
      (1.0, 1.0, 0.0),
      (-1.0, 1.0, math.pi / 2),
      (-1.0, -1.0, math.pi),
    ];
    final pts = <V3>[];
    for (final (sx, sz, a0) in cantos) {
      for (var i = 0; i <= passos; i++) {
        final a = a0 + (math.pi / 2) * i / passos;
        pts.add(V3(cx + sx * hw + r * math.cos(a), y, cz + sz * hd + r * math.sin(a)));
      }
    }
    return pts;
  }

  void _retanguloPlano(Canvas canvas, Camara cam, double cx, double cz, double w, double d, double y, Color cor) {
    final pts = cam.poligono([
      V3(cx - w / 2, y, cz - d / 2),
      V3(cx + w / 2, y, cz - d / 2),
      V3(cx + w / 2, y, cz + d / 2),
      V3(cx - w / 2, y, cz + d / 2),
    ]);
    if (pts == null) return;
    canvas.drawPath(Path()..addPolygon(pts, true), Paint()..color = cor);
  }

  V3 _girar(V3 l, double a) {
    final cs = math.cos(a), sn = math.sin(a);
    return V3(l.x * cs + l.z * sn, l.y, -l.x * sn + l.z * cs);
  }

  void _caixa(Canvas canvas, Camara cam, V3 centro, V3 tam, double giro, Color cor) {
    V3 escalar(V3 p) => V3(p.x * tam.x / 2, p.y * tam.y / 2, p.z * tam.z / 2);
    for (final f in _faces) {
      final n = _girar(f.normal, giro);
      final centroFace = centro + _girar(escalar(f.normal), giro);
      final paraOlho = cam.ortografica ? cam.frente * -1 : cam.olho - centroFace;
      if (n.dot(paraOlho) <= 0) continue;

      final pts = cam.poligono(f.cantos.map((p) => centro + _girar(escalar(p), giro)).toList());
      if (pts == null) continue;

      final k = 0.45 + 0.65 * math.max(0, n.dot(_luz));
      final sombreada = Color.from(
        alpha: 1,
        red: (cor.r * k).clamp(0.0, 1.0),
        green: (cor.g * k).clamp(0.0, 1.0),
        blue: (cor.b * k).clamp(0.0, 1.0),
      );
      final caminho = Path()..addPolygon(pts, true);
      canvas.drawPath(caminho, Paint()..color = sombreada);
      // contorno fino para o carro não se misturar com a vaga vermelha
      canvas.drawPath(
        caminho,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0x55000000),
      );
    }
  }

  void _carro(Canvas canvas, Camara cam, Vaga v) {
    final base = V3(v.x, 0, v.z);
    V3 mundo(V3 local) => base + _girar(local, v.giro);

    // rodas e corpo ordenados por distância; a cabine fica sempre por cima
    final partes = <(double, V3, V3, Color)>[];
    for (final sx in [-1.0, 1.0]) {
      for (final sz in [-1.0, 1.0]) {
        final centro = mundo(V3(sx * 0.78, 0.3, sz * 0.95));
        partes.add((cam.distancia(centro), centro, const V3(0.28, 0.6, 0.6), _corPneu));
      }
    }
    final corpo = mundo(const V3(0, 0.45, 0));
    partes.add((cam.distancia(corpo), corpo, const V3(1.6, 0.56, 2.9), Cores.ocupada));
    partes.sort((a, b) => b.$1.compareTo(a.$1));
    for (final p in partes) {
      _caixa(canvas, cam, p.$2, p.$3, v.giro, p.$4);
    }
    _caixa(canvas, cam, mundo(const V3(0, 0.86, -0.2)), const V3(1.3, 0.46, 1.45), v.giro, _corCabine);
  }

  @override
  bool shouldRepaint(covariant _CenaPainter old) => old.c != c;
}
