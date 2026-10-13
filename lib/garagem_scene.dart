import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'garagem_controller.dart';
import 'projecao.dart';
import 'theme.dart';

/// Cena do bloco: exibe o mapa 2D com o SVG de fundo e interações,
/// ou a vista 3D com carros.
class GaragemScene extends StatefulWidget {
  const GaragemScene({super.key, required this.controller});

  final GaragemController controller;

  @override
  State<GaragemScene> createState() => _GaragemSceneState();
}

class _GaragemSceneState extends State<GaragemScene>
    with SingleTickerProviderStateMixin {
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _ultimo = Duration.zero;
  Size _tamanho = Size.zero;
  double _escalaAnterior = 1;

  // Tamanho lógico do mapa SVG no mundo 2D
  static const double larguraMundoSvg = 36.0;
  static const double alturaMundoSvg = 36.0;

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
    return LayoutBuilder(
      builder: (context, c) {
        _tamanho = Size(c.maxWidth, c.maxHeight);
        return Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) {
              widget.controller.zoom(math.exp(-e.scrollDelta.dy * 0.0015));
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => _escalaAnterior = 1,
            onScaleUpdate: (d) {
              final delta = d.scale / _escalaAnterior;
              _escalaAnterior = d.scale;
              if (d.pointerCount >= 2 && delta != 1)
                widget.controller.zoom(delta);
              widget.controller.arrastar(
                d.focalPointDelta.dx,
                d.focalPointDelta.dy,
                _tamanho,
              );
            },
            onTapUp: (d) => widget.controller.toque(d.localPosition, _tamanho),
            child: ClipRect(
              child: ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (context, _, __) {
                  final cam = widget.controller.camara(_tamanho);

                  if (widget.controller.modo == Modo.d2) {
                    // Ponto central do mundo (0,0,0) projetado pela câmara na tela
                    final centro =
                        cam.ponto(const V3(0, 0, 0)) ??
                        Offset(_tamanho.width / 2, _tamanho.height / 2);
                    final p1 = cam.ponto(const V3(0, 0, 0));
                    final p2 = cam.ponto(const V3(1, 0, 0));

                    // Escala dinâmica de píxeis por unidade calculada diretamente da câmara
                    final escalaPixeis = (p1 != null && p2 != null)
                        ? (p2 - p1).dx.abs()
                        : 10.0;

                    final larguraCalculada = larguraMundoSvg * escalaPixeis;
                    final alturaCalculada = alturaMundoSvg * escalaPixeis;

                    return Stack(
                      children: [
                        // 1. Fundo do Mapa (SVG) escalado proporcionalmente com a câmara
                        Positioned(
                          left: centro.dx - (larguraCalculada / 2),
                          top: centro.dy - (alturaCalculada / 2),
                          width: larguraCalculada,
                          height: alturaCalculada,
                          child: SvgPicture.asset(
                            'assets/imagem_estacionamento_2.svg',
                            fit: BoxFit.contain,
                          ),
                        ),

                        // 2. CustomPaint com a camada de vagas (desenhada exatamente nas coordenadas da câmara)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CenaPainter(
                              widget.controller,
                              _frame,
                              apenas3d: false,
                              escalaPixeis: escalaPixeis,
                              centroMundo: centro,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // MODO 3D
                  return CustomPaint(
                    painter: _CenaPainter(
                      widget.controller,
                      _frame,
                      apenas3d: true,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Face {
  const _Face(this.normal, this.cantos);

  final V3 normal;
  final List<V3> cantos;
}

class _CenaPainter extends CustomPainter {
  _CenaPainter(
    this.c,
    Listenable repaint, {
    this.apenas3d = false,
    this.escalaPixeis = 1.0,
    this.centroMundo = Offset.zero,
  }) : super(repaint: repaint);

  final GaragemController c;
  final bool apenas3d;
  final double escalaPixeis;
  final Offset centroMundo;

  // =========================================================================
  // ⚙️ CONTROLES DE ALINHAMENTO DAS VAGAS (EIXO MUNDO SINCRO)
  // =========================================================================

  /// 1. TAMANHO RELATIVO DAS VAGAS
  static const double fatorEscala2D = 0.075;

  /// 2. ROTAÇÃO DO BLOCO DE VAGAS EM GRAUS
  static const double anguloVagasGraus = -133.5;

  /// 3. DESLOCAMENTO NO ESPAÇO VIRTUAL (DX, DY em unidades do mundo)
  /// Este offset varia proporcionalmente ao zoom, impedindo o desacoplamento!
  static const Offset offsetMundoVagas = Offset(-0.8, -1.5);

  // =========================================================================

  static const _corLinha = Color(0xFFDEDFD8);
  static const _corVidro = Color(0xFF1B1E22);
  static const _corPneu = Color(0xFF0E0F11);

  static const _faces = [
    _Face(V3(1, 0, 0), [
      V3(1, -1, -1),
      V3(1, -1, 1),
      V3(1, 1, 1),
      V3(1, 1, -1),
    ]),
    _Face(V3(-1, 0, 0), [
      V3(-1, -1, 1),
      V3(-1, -1, -1),
      V3(-1, 1, -1),
      V3(-1, 1, 1),
    ]),
    _Face(V3(0, 1, 0), [
      V3(-1, 1, -1),
      V3(1, 1, -1),
      V3(1, 1, 1),
      V3(-1, 1, 1),
    ]),
    _Face(V3(0, 0, 1), [
      V3(-1, -1, 1),
      V3(1, -1, 1),
      V3(1, 1, 1),
      V3(-1, 1, 1),
    ]),
    _Face(V3(0, 0, -1), [
      V3(1, -1, -1),
      V3(-1, -1, -1),
      V3(-1, 1, -1),
      V3(1, 1, -1),
    ]),
  ];

  static final _luz = const V3(24, 32, 14).normalizado();

  @override
  void paint(Canvas canvas, Size size) {
    final cam = c.camara(size);

    if (c.modo == Modo.d3) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Cores.azul);
      _pintar3d(canvas, cam);
    } else if (!apenas3d) {
      canvas.save();

      // Translação sincronizada com a escala atual do zoom
      final deslocamentoEmPixeis = Offset(
        offsetMundoVagas.dx * escalaPixeis,
        offsetMundoVagas.dy * escalaPixeis,
      );

      final pivo = centroMundo + deslocamentoEmPixeis;

      canvas.translate(pivo.dx, pivo.dy);
      canvas.scale(fatorEscala2D, fatorEscala2D);

      if (anguloVagasGraus != 0) {
        canvas.rotate(anguloVagasGraus * (math.pi / 180));
      }

      canvas.translate(-centroMundo.dx, -centroMundo.dy);

      _pintar2d(canvas, cam);

      canvas.restore();
    }
  }

  // ---------- 2D: Desenha os marcadores das vagas ----------

  void _pintar2d(Canvas canvas, Camara cam) {
    // ✅ COLOQUE ASSIM NO PINTOR:
for (final v in c.vagas) {
  _retanguloPlano(
    canvas,
    cam,
    v.x, // <--- Use a posição real da vaga aqui!
    v.z,
    ConfigPatio.vagaLarg2d,
    ConfigPatio.vagaProf2d,
    0.02,
    v.ocupada ? Cores.ocupada : Cores.livre,
  );
  
  // Se desenhar as linhas/divisórias brancas entre as vagas:
  // Onde desenha a divisória branca entre os carros:
if (v.id % ConfigPatio.cols != ConfigPatio.cols - 1) {
  _retanguloPlano(
    canvas,
    cam,
    v.x + (ConfigPatio.spotW / 2), // <--- Trocado aqui
    v.z,
    0.03,
    ConfigPatio.vagaProf2d,
    0.03,
    Colors.white,
  );
}
}
  }

  // ---------- 3D: Pátio tridimensional ----------

  void _pintar3d(Canvas canvas, Camara cam) {
    _retanguloPlano(
      canvas,
      cam,
      0,
      0,
      ConfigPatio.larguraPatio,
      ConfigPatio.profundidadePatio,
      0,
      Cores.piso3d,
    );
    _retanguloPlano(
      canvas,
      cam,
      0,
      0,
      ConfigPatio.larguraPatio - 1,
      ConfigPatio.aisle - 0.6,
      0.005,
      Cores.via3d,
    );

    for (final v in c.vagas) {
      _retanguloPlano(
        canvas,
        cam,
        v.x,
        v.z,
        ConfigPatio.spotW - 0.18,
        ConfigPatio.spotD - 0.3,
        0.01,
        _corLinha,
        contorno: true,
      );
      final cor = v.ocupada
          ? Cores.ocupada.withValues(alpha: 0.55)
          : Cores.livre.withValues(alpha: 0.5);
      _retanguloPlano(
        canvas,
        cam,
        v.x,
        v.z,
        ConfigPatio.spotW - 0.5,
        ConfigPatio.spotD - 0.9,
        0.02,
        cor,
      );
    }

    final itens = <(double, VoidCallback)>[];
    for (final cx in [-1.0, 1.0]) {
      for (final cz in [-1.0, 1.0]) {
        final centro = V3(
          cx * (ConfigPatio.larguraPatio / 2 - 1),
          2.6,
          cz * (ConfigPatio.profundidadePatio / 2 - 1),
        );
        itens.add((
          cam.distancia(centro),
          () => _caixa(
            canvas,
            cam,
            centro,
            const V3(0.9, 5.2, 0.9),
            0,
            Cores.coluna3d,
          ),
        ));
      }
    }
    for (final v in c.vagas.where((v) => v.ocupada)) {
      itens.add((
        cam.distancia(V3(v.x, 0.5, v.z)),
        () => _carro(canvas, cam, v),
      ));
    }
    itens.sort((a, b) => b.$1.compareTo(a.$1));
    for (final item in itens) {
      item.$2();
    }

    for (final v in c.vagas) {
      _rotulo(canvas, cam, v);
    }
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

  void _caixa(
    Canvas canvas,
    Camara cam,
    V3 centro,
    V3 tam,
    double giro,
    Color cor,
  ) {
    V3 escalar(V3 p) => V3(p.x * tam.x / 2, p.y * tam.y / 2, p.z * tam.z / 2);
    for (final f in _faces) {
      final n = _girar(f.normal, giro);
      final centroFace = centro + _girar(escalar(f.normal), giro);
      final paraOlho = cam.ortografica
          ? cam.frente * -1
          : cam.olho - centroFace;
      if (n.dot(paraOlho) <= 0) continue;

      final pts = cam.poligono(
        f.cantos.map((p) => centro + _girar(escalar(p), giro)).toList(),
      );
      if (pts == null) continue;

      final k = 0.45 + 0.65 * math.max(0, n.dot(_luz));
      final sombreada = Color.from(
        alpha: 1,
        red: (cor.r * k).clamp(0.0, 1.0),
        green: (cor.g * k).clamp(0.0, 1.0),
        blue: (cor.b * k).clamp(0.0, 1.0),
      );
      canvas.drawPath(
        Path()..addPolygon(pts, true),
        Paint()..color = sombreada,
      );
    }
  }

  void _carro(Canvas canvas, Camara cam, Vaga v) {
    final base = V3(v.x, 0, v.z);
    V3 mundo(V3 local) => base + _girar(local, v.giro);

    final partes = <(double, V3, V3, Color)>[];
    for (final sx in [-1.0, 1.0]) {
      for (final sz in [-1.0, 1.0]) {
        final centro = mundo(V3(sx * 0.82, 0.32, sz * 1.15));
        partes.add((
          cam.distancia(centro),
          centro,
          const V3(0.3, 0.64, 0.64),
          _corPneu,
        ));
      }
    }
    final corpo = mundo(const V3(0, 0.5, 0));
    partes.add((
      cam.distancia(corpo),
      corpo,
      const V3(1.7, 0.62, 3.5),
      v.corCarro,
    ));
    partes.sort((a, b) => b.$1.compareTo(a.$1));
    for (final p in partes) {
      _caixa(canvas, cam, p.$2, p.$3, v.giro, p.$4);
    }
    _caixa(
      canvas,
      cam,
      mundo(const V3(0, 0.93, -0.25)),
      const V3(1.4, 0.5, 1.7),
      v.giro,
      _corVidro,
    );
  }

  void _rotulo(Canvas canvas, Camara cam, Vaga v) {
    final p = cam.ponto(V3(v.x, 1.55, v.z));
    if (p == null) return;
    final tp = TextPainter(
      text: TextSpan(
        text: v.code,
        style: mono(11, cor: const Color.fromRGBO(255, 255, 255, 0.9)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CenaPainter old) => true;
}
