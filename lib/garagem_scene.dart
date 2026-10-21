import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'entorno_bloco_u.dart';
import 'garagem_controller.dart';
import 'meu_carro.dart';
import 'projecao.dart';
import 'theme.dart';

/// Cena do bloco: vista 2D no estilo do Figma ou vista 3D com carros.
/// Trata os gestos (arrastar, pinça/scroll para zoom, toque para selecionar).
class GaragemScene extends StatefulWidget {
  const GaragemScene({super.key, required this.controller, this.meuCarro});

  final GaragemController controller;

  /// Vaga onde o usuário estacionou (destacada no mapa).
  final MeuCarro? meuCarro;

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
          child: ClipRect(
            child: CustomPaint(
              size: Size.infinite,
              painter: _CenaPainter(
                widget.controller,
                _frame,
                fundo: context.paleta.fundo,
                escuro: Theme.of(context).brightness == Brightness.dark,
                meuCarro: widget.meuCarro,
              ),
            ),
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
  _CenaPainter(this.c, Listenable repaint, {required this.fundo, required this.escuro, this.meuCarro}) : super(repaint: repaint);

  final GaragemController c;
  final Color fundo;
  final bool escuro; // modo escuro: escurece a cena toda por cima
  final MeuCarro? meuCarro;

  static const _corLinha = Color(0xFFDEDFD8);
  static const _corVidro = Color(0xFF1B1E22);
  static const _corPneu = Color(0xFF0E0F11);

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
    if (size.width <= 0 || size.height <= 0) return; // evita NaN com área vazia
    canvas.drawRect(Offset.zero & size, Paint()..color = fundo);
    final cam = c.camara(size);
    if (c.modo == Modo.d2) {
      _pintar2d(canvas, cam);
    } else {
      _pintar3d(canvas, cam);
    }
    if (escuro) {
      // modo escuro: véu azul-escuro sobre o chão, os prédios e as vagas
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x8C050B14));
    }
    _destacarMeuCarro(canvas, cam); // por cima do véu: continua bem visível
  }

  /// Destaca a vaga do usuário ("Onde estacionei?"): contorno que pulsa e a etiqueta "Meu carro".
  void _destacarMeuCarro(Canvas canvas, Camara cam) {
    final m = meuCarro;
    if (m == null || !m.estacionado || m.nivel != c.nivel) return;
    final v = c.buscarVaga(m.nivel!, m.codigo!);
    if (v == null) return;
    const amarelo = Color(0xFFFFD93D);
    final pulso = 0.5 + 0.5 * math.sin(DateTime.now().millisecondsSinceEpoch / 260);
    final d2 = c.modo == Modo.d2;
    final w = d2 ? ConfigPatio.vagaLarg2d : ConfigPatio.spotW - 0.2;
    final d = d2 ? ConfigPatio.vagaProf2d : ConfigPatio.spotD - 0.4;
    final pts = cam.poligono([
      V3(v.x - w / 2, 0.05, v.z - d / 2),
      V3(v.x + w / 2, 0.05, v.z - d / 2),
      V3(v.x + w / 2, 0.05, v.z + d / 2),
      V3(v.x - w / 2, 0.05, v.z + d / 2),
    ]);
    if (pts != null) {
      canvas.drawPath(
        Path()..addPolygon(pts, true),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 + 2 * pulso
          ..strokeJoin = StrokeJoin.round
          ..color = amarelo,
      );
    }
    final ponta = cam.ponto(V3(v.x, d2 ? 0.3 : 3.0, v.z));
    if (ponta == null) return;
    final tp = TextPainter(
      text: TextSpan(text: 'Meu carro', style: mono(11, peso: FontWeight.w700, cor: const Color(0xFF111111))),
      textDirection: TextDirection.ltr,
    )..layout();
    final caixa = RRect.fromRectAndRadius(
      Rect.fromCenter(center: ponta - const Offset(0, 22), width: tp.width + 16, height: tp.height + 8),
      const Radius.circular(10),
    );
    final cor = Paint()..color = amarelo;
    canvas.drawRRect(caixa, cor);
    canvas.drawPath(
      Path()
        ..moveTo(ponta.dx - 5, caixa.bottom - 1)
        ..lineTo(ponta.dx + 5, caixa.bottom - 1)
        ..lineTo(ponta.dx, ponta.dy)
        ..close(),
      cor,
    );
    tp.paint(canvas, caixa.center - Offset(tp.width / 2, tp.height / 2));
  }

  // ---------- 2D (Figma): vagas lisas verde/vermelho, divisórias brancas e moldura ----------

  void _pintar2d(Canvas canvas, Camara cam) {
    final a = cam.ponto(const V3(-ConfigPatio.quadroMeiaLargura, 0, -ConfigPatio.quadroMeiaAltura));
    final b = cam.ponto(const V3(ConfigPatio.quadroMeiaLargura, 0, ConfigPatio.quadroMeiaAltura));
    if (a != null && b != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromPoints(a, b), const Radius.circular(12)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    for (final v in c.vagas) {
      _retanguloPlano(canvas, cam, v.x, v.z, ConfigPatio.vagaLarg2d, ConfigPatio.vagaProf2d, 0.02,
          v.ocupada ? Cores.ocupada : Cores.livre);
      if (v.id % ConfigPatio.cols != ConfigPatio.cols - 1) {
        _retanguloPlano(
            canvas, cam, v.x + ConfigPatio.spotW / 2, v.z, 0.12, ConfigPatio.vagaProf2d, 0.03, Colors.white);
      }
    }
  }

  // ---------- 3D: trecho do Bloco U com o entorno real e carros nas vagas ocupadas ----------

  void _pintar3d(Canvas canvas, Camara cam) {
    _pintarChaoEntorno(canvas, cam);

    for (final v in c.vagas) {
      _retanguloPlano(canvas, cam, v.x, v.z, ConfigPatio.spotW - 0.18, ConfigPatio.spotD - 0.3, 0.01, _corLinha,
          contorno: true);
      final cor = v.ocupada ? Cores.ocupada.withValues(alpha: 0.55) : Cores.livre.withValues(alpha: 0.5);
      _retanguloPlano(canvas, cam, v.x, v.z, ConfigPatio.spotW - 0.5, ConfigPatio.spotD - 0.9, 0.02, cor);
    }

    // objetos 3D ordenados do mais longe para o mais perto (algoritmo do pintor)
    final itens = <(double, VoidCallback)>[];
    for (final p in EntornoBlocoU.predios) {
      final centro = p.centro, tam = p.tamanho;
      itens.add((_distanciaCaixa(cam, centro, tam), () => _caixa(canvas, cam, centro, tam, 0, Cores.predio3d)));
    }
    for (final v in c.vagas.where((v) => v.ocupada)) {
      itens.add((cam.distancia(V3(v.x, 0.5, v.z)), () => _carro(canvas, cam, v)));
    }
    itens.sort((a, b) => b.$1.compareTo(a.$1));
    for (final item in itens) {
      item.$2();
    }

    for (final v in c.vagas) {
      _rotulo(canvas, cam, v);
    }
  }

  /// Chão do entorno: vias, calçadas, canteiro e o resto das vagas (só contorno).
  void _pintarChaoEntorno(Canvas canvas, Camara cam) {
    void area(AreaPlanta a, Color cor) =>
        _retanguloPlano(canvas, cam, a.cx, a.cz, a.largura, a.profundidade, 0, cor);

    area(EntornoBlocoU.chao, Cores.chao3d);
    for (final a in EntornoBlocoU.vias) {
      area(a, Cores.via3d);
    }
    for (final a in EntornoBlocoU.calcadas) {
      area(a, Cores.calcada3d);
    }
    for (final a in EntornoBlocoU.fileiras) {
      area(a, Cores.piso3d);
    }
    area(EntornoBlocoU.canteiro, Cores.canteiro3d);
    final divisoria = _corLinha.withValues(alpha: 0.35);
    for (final a in EntornoBlocoU.divisoriasContexto) {
      area(a, divisoria);
    }
  }

  /// Distância da câmera ao ponto mais próximo da caixa (ordena prédios grandes melhor que o centro).
  double _distanciaCaixa(Camara cam, V3 centro, V3 tam) {
    final o = cam.olho;
    return cam.distancia(V3(
      o.x.clamp(centro.x - tam.x / 2, centro.x + tam.x / 2).toDouble(),
      o.y.clamp(0, tam.y).toDouble(),
      o.z.clamp(centro.z - tam.z / 2, centro.z + tam.z / 2).toDouble(),
    ));
  }

  void _retanguloPlano(
    Canvas canvas,
    Camara cam,
    double cx,
    double cz,
    double w,
    double d,
    double y,
    Color cor, {
    bool contorno = false,
  }) {
    final pts = cam.poligono([
      V3(cx - w / 2, y, cz - d / 2),
      V3(cx + w / 2, y, cz - d / 2),
      V3(cx + w / 2, y, cz + d / 2),
      V3(cx - w / 2, y, cz + d / 2),
    ]);
    if (pts == null) return;
    final paint = Paint()..color = cor;
    if (contorno) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
    }
    canvas.drawPath(Path()..addPolygon(pts, true), paint);
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
      canvas.drawPath(Path()..addPolygon(pts, true), Paint()..color = sombreada);
    }
  }

  void _carro(Canvas canvas, Camara cam, Vaga v) {
    final base = V3(v.x, 0, v.z);
    V3 mundo(V3 local) => base + _girar(local, v.giro);

    // rodas e corpo ordenados por distância; a cabine fica sempre por cima
    final partes = <(double, V3, V3, Color)>[];
    for (final sx in [-1.0, 1.0]) {
      for (final sz in [-1.0, 1.0]) {
        final centro = mundo(V3(sx * 0.82, 0.32, sz * 1.15));
        partes.add((cam.distancia(centro), centro, const V3(0.3, 0.64, 0.64), _corPneu));
      }
    }
    final corpo = mundo(const V3(0, 0.5, 0));
    partes.add((cam.distancia(corpo), corpo, const V3(1.7, 0.62, 3.5), v.corCarro));
    partes.sort((a, b) => b.$1.compareTo(a.$1));
    for (final p in partes) {
      _caixa(canvas, cam, p.$2, p.$3, v.giro, p.$4);
    }
    _caixa(canvas, cam, mundo(const V3(0, 0.93, -0.25)), const V3(1.4, 0.5, 1.7), v.giro, _corVidro);
  }

  void _rotulo(Canvas canvas, Camara cam, Vaga v) {
    final p = cam.ponto(V3(v.x, 1.55, v.z));
    if (p == null) return;
    final tp = TextPainter(
      text: TextSpan(text: v.code, style: mono(11, cor: const Color.fromRGBO(255, 255, 255, 0.9))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CenaPainter old) => old.c != c || old.fundo != fundo || old.escuro != escuro || old.meuCarro != meuCarro;
}
