import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'carro_desenho.dart';
import 'carro_personalizado.dart';
import 'carros_controller.dart';
import 'cena_login.dart';
import 'entorno_bloco_u.dart';
import 'garagem_controller.dart';
import 'meu_carro.dart';
import 'projecao.dart';
import 'theme.dart';

class GaragemScene extends StatefulWidget {
  const GaragemScene({super.key, required this.controller, this.meuCarro, this.carros});

  final GaragemController controller;

  final MeuCarro? meuCarro;

  final CarrosController? carros;

  @override
  State<GaragemScene> createState() => _GaragemSceneState();
}

class _GaragemSceneState extends State<GaragemScene> with SingleTickerProviderStateMixin {
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _ultimo = Duration.zero;
  Size _tamanho = Size.zero;
  double _escalaAnterior = 1;
  double _giroAnterior = 0;

  static const _caminhoSvg = 'assets/mapa_modelo_construcoes.svg';

  /// Mapa 2D convertido em Picture: desenhado no mesmo canvas e com a mesma
  /// transformação das vagas, então as duas camadas nunca se desalinham.
  PictureInfo? _svg;

  /// Cor com que o SVG foi carregado; se o fundo do tema mudar, recarrega com a cor certa.
  Color? _corSvg;

  /// O SVG não tem cores próprias (usa `currentColor`): a cor das linhas vem daqui.
  static const _corMapaEscuro = Color(0xB3FFFFFF); // linhas brancas 70% (fundo escuro)
  static const _corMapaClaro = Color(0x99203D65); // linhas azul-marinho 60% (fundo claro)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A cor das linhas depende do FUNDO da cena, não do modo: no modo claro o fundo do mapa
    // também é azul-marinho, então linhas escuras sumiriam. Fundo escuro → linhas claras.
    final fundoEscuro = context.paleta.fundo.computeLuminance() < 0.35;
    final cor = fundoEscuro ? _corMapaEscuro : _corMapaClaro;
    if (cor != _corSvg) {
      _corSvg = cor;
      _carregarSvg(cor);
    }
  }

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

  Future<void> _carregarSvg(Color cor) async {
    try {
      final info = await vg.loadPicture(
        SvgAssetLoader(_caminhoSvg, theme: SvgTheme(currentColor: cor)),
        null,
      );
      if (!mounted) {
        info.picture.dispose();
        return;
      }
      widget.controller.definirTamanhoSvg(info.size);
      final antigo = _svg;
      setState(() => _svg = info);
      antigo?.picture.dispose();
    } catch (e) {
      // SVG ausente/inválido: o 2D mostra só as vagas, o app não quebra
      debugPrint('Não foi possível carregar $_caminhoSvg: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _svg?.picture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _tamanho = Size(c.maxWidth, c.maxHeight);
      widget.controller.prepararTela2d(_tamanho); // ao abrir o 2D: já centrado nas vagas
      return Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              // Shift + roda do mouse: gira o mapa 2D em torno do CENTRO da vista (como no Maps)
              final passo = e.scrollDelta.dy != 0 ? e.scrollDelta.dy : e.scrollDelta.dx;
              widget.controller.girar2d(passo * 0.003, foco: _tamanho.center(Offset.zero), tela: _tamanho);
            } else {
              // roda do mouse: no 2D aproxima/afasta em torno do cursor
              widget.controller.zoom(math.exp(-e.scrollDelta.dy * 0.0015), foco: e.localPosition, tela: _tamanho);
            }
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) {
            _escalaAnterior = 1;
            _giroAnterior = 0;
          },
          onScaleUpdate: (d) {
            final meio = _tamanho.center(Offset.zero);
            // Ctrl + arrastar (mouse): gira o mapa como um volante em torno do CENTRO da vista,
            // igual ao Google Maps no computador
            if (d.pointerCount == 1 && HardwareKeyboard.instance.isControlPressed) {
              final atual = d.localFocalPoint - meio;
              final antes = atual - d.focalPointDelta;
              if (atual.distance > 8 && antes.distance > 8) {
                var giro = atual.direction - antes.direction;
                if (giro > math.pi) giro -= 2 * math.pi;
                if (giro < -math.pi) giro += 2 * math.pi;
                widget.controller.girar2d(giro, foco: meio, tela: _tamanho);
              }
              return;
            }
            final delta = d.scale / _escalaAnterior;
            _escalaAnterior = d.scale;
            // move junto com os dedos e depois aplica o zoom em torno do ponto entre eles
            widget.controller.arrastar(d.focalPointDelta.dx, d.focalPointDelta.dy, _tamanho);
            // (com 1 dedo a escala é sempre 1; isto cobre pinça e trackpad)
            if (delta != 1) widget.controller.zoom(delta, foco: d.localFocalPoint, tela: _tamanho);
            // dois dedos girando (ou trackpad): gira em torno do ponto entre os dedos (como no Maps no celular)
            final giro = d.rotation - _giroAnterior;
            _giroAnterior = d.rotation;
            if (d.pointerCount >= 2 && giro != 0) {
              widget.controller.girar2d(giro, foco: d.localFocalPoint, tela: _tamanho);
            }
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
                carros: widget.carros,
                svg: _svg,
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
  _CenaPainter(this.c, Listenable repaint,
      {required this.fundo, required this.escuro, this.meuCarro, this.carros, this.svg})
      : super(repaint: repaint);

  final GaragemController c;
  final Color fundo;
  final bool escuro;
  final MeuCarro? meuCarro;
  final CarrosController? carros;

  /// Mapa 2D já carregado (null enquanto carrega).
  final PictureInfo? svg;

  CarroPersonalizado _carroDa(Vaga v) =>
      carros?.carroNaVaga(c.nivel, v.code)?.carro ??
      CarroPersonalizado.padrao(v.corCarro).copyWith(modelo: v.id.isEven ? ModeloCarro.seda : ModeloCarro.hatch);

  static const _corLinha = Color(0xFFDEDFD8);

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
    if (size.width <= 0 || size.height <= 0) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = fundo);
    if (c.modo == Modo.d2) {
      _pintar2d(canvas, size);
      _destacarMeuCarro(canvas, null, size);
    } else {
      final cam = c.camara(size);
      _pintar3d(canvas, cam, size);
      _destacarMeuCarro(canvas, cam, size);
    }
  }

  /// [cam] é `null` no 2D: lá a vaga é posicionada pelo mapa SVG.
  void _destacarMeuCarro(Canvas canvas, Camara? cam, Size size) {
    final m = meuCarro;
    if (m == null || !m.estacionado || m.nivel != c.nivel) return;
    final v = c.buscarVaga(m.nivel!, m.codigo!);
    if (v == null) return;
    const amarelo = Color(0xFFFFD93D);
    final pulso = 0.5 + 0.5 * math.sin(DateTime.now().millisecondsSinceEpoch / 260);
    final d2 = c.modo == Modo.d2;
    final w = ConfigPatio.spotW - 0.2;
    final d = d2 ? ConfigPatio.vagaProf2d : ConfigPatio.spotD - 0.4;
    final pts = cam == null
        ? [
            c.patioParaTela2d(v.x - w / 2, v.z - d / 2, size),
            c.patioParaTela2d(v.x + w / 2, v.z - d / 2, size),
            c.patioParaTela2d(v.x + w / 2, v.z + d / 2, size),
            c.patioParaTela2d(v.x - w / 2, v.z + d / 2, size),
          ]
        : cam.poligono([
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
    final ponta = cam == null ? c.patioParaTela2d(v.x, v.z, size) : cam.ponto(V3(v.x, 3.0, v.z));
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

  // ---------- 2D: mapa SVG do campus + vagas no visual novo (uma única transformação) ----------

  void _pintar2d(Canvas canvas, Size size) {
    final escala = c.escala2d(size);
    final k = c.escalaVagas2d;
    final s = escala * k; // pixels de tela por metro do pátio
    if (s <= 0) return;

    canvas.save();
    c.transformar2d(canvas, size); // pan, zoom e rotação do mapa
    final info = svg;
    if (info != null) canvas.drawPicture(info.picture); // fundo: mapa do campus

    // daqui em diante: 1 unidade = 1 metro do pátio, já girado na direção da faixa
    final cv = c.centroVagas2d;
    canvas.translate(cv.dx, cv.dy);
    canvas.rotate(c.angulo2d);
    canvas.scale(k);
    final px = 1 / s; // 1 pixel de tela, em metros

    final canteiro = Rect.fromCenter(
      center: Offset.zero,
      width: ConfigPatio.cols * ConfigPatio.spotW - 0.6,
      height: ConfigPatio.aisle * 0.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(canteiro, const Radius.circular(0.4)),
      Paint()..color = CoresCena.livre.withValues(alpha: 0.06),
    );

    final linha = Paint()
      ..color = CoresCena.texto.withValues(alpha: 0.28)
      ..strokeWidth = math.max(px, 0.05);

    for (final v in c.vagas) {
      final centro = Offset(v.x, v.z);
      final cima = v.z < 0;
      final cor = v.ocupada ? CoresCena.ocupada : CoresCena.livre;
      final r = Rect.fromCenter(center: centro, width: ConfigPatio.spotW, height: ConfigPatio.vagaProf2d);
      final yInterno = cima ? r.bottom : r.top;
      final paraDentro = cima ? 1.0 : -1.0;

      canvas.drawRect(r.deflate(0.08), Paint()..color = cor.withValues(alpha: 0.10));

      canvas.drawLine(Offset(r.left, r.top), Offset(r.left, r.bottom), linha);
      if (v.id % ConfigPatio.cols == ConfigPatio.cols - 1) {
        canvas.drawLine(Offset(r.right, r.top), Offset(r.right, r.bottom), linha);
      }
      canvas.drawLine(Offset(r.left, yInterno), Offset(r.right, yInterno), linha);

      final led = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centro.dx, yInterno - paraDentro * 0.32),
          width: ConfigPatio.spotW * 0.5,
          height: math.max(2 * px, 0.13),
        ),
        Radius.circular(math.max(px, 0.07)),
      );
      canvas.drawRRect(led.inflate(0.2), Paint()..color = cor.withValues(alpha: 0.10));
      canvas.drawRRect(led.inflate(0.09), Paint()..color = cor.withValues(alpha: 0.22));
      canvas.drawRRect(led, Paint()..color = cor);

      if (v.ocupada) {
        desenharCarro2d(
          canvas,
          Offset(centro.dx, centro.dy + paraDentro * 0.1),
          cima ? math.pi / 2 : -math.pi / 2,
          _carroDa(v),
          0.8,
        );
      }
    }

    final sel = c.selecionada;
    if (sel != null) {
      final r = Rect.fromCenter(
        center: Offset(sel.x, sel.z),
        width: ConfigPatio.spotW - 0.2,
        height: ConfigPatio.vagaProf2d - 0.2,
      );
      final q = math.min(r.width, r.height) * 0.22;
      canvas.drawPath(
        Path()
          ..moveTo(r.left, r.top + q)
          ..lineTo(r.left, r.top)
          ..lineTo(r.left + q, r.top)
          ..moveTo(r.right - q, r.top)
          ..lineTo(r.right, r.top)
          ..lineTo(r.right, r.top + q)
          ..moveTo(r.right, r.bottom - q)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.right - q, r.bottom)
          ..moveTo(r.left + q, r.bottom)
          ..lineTo(r.left, r.bottom)
          ..lineTo(r.left, r.bottom - q),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2 * px, 0.09)
          ..strokeCap = StrokeCap.round
          ..color = CoresCena.varredura,
      );
    }
    canvas.restore();

    if (c.mostrarBussola) _bussola(canvas, size);

    // códigos das vagas: desenhados na tela, sem girar o texto, e só quando a vaga
    // está grande o bastante para não virar um borrão (com zoom afastado eles somem)
    if (ConfigPatio.spotW * s < 22) return;
    final tamanhoTexto = (0.34 * s).clamp(8.0, 13.0);
    for (final v in c.vagas) {
      final cima = v.z < 0;
      final zEntrada = cima ? v.z - ConfigPatio.vagaProf2d / 2 : v.z + ConfigPatio.vagaProf2d / 2;
      final p = c.patioParaTela2d(v.x, zEntrada + (cima ? 0.55 : -0.55), size);
      final tp = TextPainter(
        text: TextSpan(
          text: v.code,
          style: mono(tamanhoTexto, peso: FontWeight.w600, cor: CoresCena.texto.withValues(alpha: 0.6)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
  }

  /// Bússola (só com o mapa girado): a ponta vermelha aponta para o norte do mapa.
  /// Tocar nela volta o norte para cima.
  void _bussola(Canvas canvas, Size size) {
    final centro = c.bussola2d(size);
    const r = GaragemController.raioBussola;
    canvas.drawCircle(centro, r, Paint()..color = const Color(0xE60A1220));
    canvas.drawCircle(
      centro,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.rotate(c.giro2d);
    const ponta = r * 0.72, base = r * 0.28;
    canvas.drawPath(
      Path()
        ..moveTo(0, -ponta)
        ..lineTo(base, 0)
        ..lineTo(-base, 0)
        ..close(),
      Paint()..color = CoresCena.ocupada,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, ponta)
        ..lineTo(base, 0)
        ..lineTo(-base, 0)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    canvas.restore();
  }

  void _pintar3d(Canvas canvas, Camara cam, Size size) {
    _pintarChaoEntorno(canvas, cam);
    if (escuro) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x8C050B14));
    }

    for (final v in c.vagas) {
      final cor = v.ocupada ? CoresCena.ocupada : CoresCena.livre;
      _retanguloPlano(canvas, cam, v.x, v.z, ConfigPatio.spotW - 0.12, ConfigPatio.spotD - 0.2, 0.01,
          cor.withValues(alpha: 0.16));
      _retanguloPlano(canvas, cam, v.x, v.z, ConfigPatio.spotW - 0.18, ConfigPatio.spotD - 0.3, 0.012,
          _corLinha.withValues(alpha: 0.45),
          contorno: true);
      final zLed = v.z + _paraCanteiro(v) * (ConfigPatio.spotD / 2 - 0.4);
      _retanguloPlano(canvas, cam, v.x, zLed, 1.5, 0.55, 0.02, cor.withValues(alpha: 0.12));
      _retanguloPlano(canvas, cam, v.x, zLed, 1.35, 0.32, 0.022, cor.withValues(alpha: 0.25));
      _retanguloPlano(canvas, cam, v.x, zLed, 1.2, 0.14, 0.025, cor);
    }

    for (final v in c.vagas.where((v) => v.ocupada)) {
      desenharChaoCarro3d(canvas, cam, V3(v.x, 0, v.z), v.giro, _carroDa(v));
    }

    final corPredio = escuro ? Color.lerp(Cores.predio3d, const Color(0xFF050B14), 0.5)! : Cores.predio3d;
    final itens = <(double, VoidCallback)>[];
    for (final p in EntornoBlocoU.predios) {
      final centro = p.centro, tam = p.tamanho;
      itens.add((_distanciaCaixa(cam, centro, tam), () => _caixa(canvas, cam, centro, tam, 0, corPredio)));
    }
    for (final v in c.vagas.where((v) => v.ocupada)) {
      itens.add((cam.distancia(V3(v.x, 0.5, v.z)), () => desenharCarro3d(canvas, cam, V3(v.x, 0, v.z), v.giro, _carroDa(v))));
    }
    itens.sort((a, b) => b.$1.compareTo(a.$1));
    for (final item in itens) {
      item.$2();
    }

    for (final v in c.vagas) {
      _rotulo(canvas, cam, v);
    }

    final sel = c.selecionada;
    if (sel != null) {
      _cantoneiras(canvas, cam, sel.x, sel.z, ConfigPatio.spotW - 0.1, ConfigPatio.spotD - 0.2, CoresCena.varredura);
    }
  }

  double _paraCanteiro(Vaga v) => v.z < 0 ? 1.0 : -1.0;

  void _cantoneiras(Canvas canvas, Camara cam, double cx, double cz, double w, double d, Color cor) {
    const q = 0.7;
    final pintura = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = cor;
    final cantos = [
      (cx - w / 2, cz - d / 2, 1.0, 1.0),
      (cx + w / 2, cz - d / 2, -1.0, 1.0),
      (cx + w / 2, cz + d / 2, -1.0, -1.0),
      (cx - w / 2, cz + d / 2, 1.0, -1.0),
    ];
    for (final (x, z, sx, sz) in cantos) {
      final canto = cam.ponto(V3(x, 0.04, z));
      final ax = cam.ponto(V3(x + sx * q, 0.04, z));
      final az = cam.ponto(V3(x, 0.04, z + sz * q));
      if (canto == null || ax == null || az == null) continue;
      canvas.drawPath(
        Path()
          ..moveTo(ax.dx, ax.dy)
          ..lineTo(canto.dx, canto.dy)
          ..lineTo(az.dx, az.dy),
        pintura,
      );
    }
  }

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

  void _rotulo(Canvas canvas, Camara cam, Vaga v) {
    final personalizado = v.ocupada ? carros?.carroNaVaga(c.nivel, v.code) : null;
    final p = cam.ponto(V3(v.x, personalizado == null ? 1.55 : 2.05, v.z));
    if (p == null) return;
    final texto = personalizado == null ? v.code : '${v.code} · ${personalizado.carro.nome}';
    final tp = TextPainter(
      text: TextSpan(text: texto, style: mono(11, peso: FontWeight.w700, cor: CoresCena.texto)),
      textDirection: TextDirection.ltr,
    )..layout();
    const bolinha = 6.0;
    final largura = tp.width + bolinha + 18;
    final caixa = RRect.fromRectAndRadius(
      Rect.fromCenter(center: p, width: largura, height: tp.height + 6),
      Radius.circular((tp.height + 6) / 2),
    );
    final cor = v.ocupada ? CoresCena.ocupada : CoresCena.livre;
    canvas.drawRRect(caixa, Paint()..color = const Color(0xCC0A1220));
    canvas.drawRRect(
      caixa,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = cor.withValues(alpha: 0.6),
    );
    canvas.drawCircle(Offset(caixa.left + 7 + bolinha / 2, p.dy), bolinha / 2, Paint()..color = cor);
    tp.paint(canvas, Offset(caixa.left + 7 + bolinha + 4, p.dy - tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(covariant _CenaPainter old) =>
      old.c != c ||
      old.fundo != fundo ||
      old.escuro != escuro ||
      old.meuCarro != meuCarro ||
      old.carros != carros ||
      old.svg != svg;
}