import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'logo.dart';

class CoresCena {
  CoresCena._();

  static const fundo = Color(0xFF060D18);
  static const livre = Color(0xFF4ADE80);
  static const ocupada = Color(0xFFF2545B);
  static const varredura = Color(0xFF8FB4FF);
  static const texto = Color(0xFFE8ECF3);
  static const textoSuave = Color(0xFF9AA7BD);
  static const erro = Color(0xFFE5604F);
}

TextStyle _mono(double tamanho, FontWeight peso, Color cor) =>
    GoogleFonts.ibmPlexMono(fontSize: tamanho, fontWeight: peso, color: cor);

class FundoCena extends StatelessWidget {
  const FundoCena({super.key});

  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _PintorFundo(), size: Size.infinite);
}

class _PintorFundo extends CustomPainter {
  const _PintorFundo();

  @override
  void paint(Canvas canvas, Size size) => _pintarFundo(canvas, size);

  @override
  bool shouldRepaint(_PintorFundo oldDelegate) => false;
}

void _pintarFundo(Canvas canvas, Size size) {
  final tudo = Offset.zero & size;
  canvas.drawRect(tudo, Paint()..color = CoresCena.fundo);
  void brilho(Offset centro, double raio, Color cor) {
    if (raio <= 0) return;
    final pintura = Paint()
      ..shader = RadialGradient(colors: [cor, cor.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: centro, radius: raio));
    canvas.drawRect(tudo, pintura);
  }

  final maior = math.max(size.width, size.height);
  brilho(Offset(size.width * .25, size.height * .2), maior * .7, const Color(0xFF124BBD).withValues(alpha: .28));
  brilho(Offset(size.width * .85, size.height * .9), maior * .45, CoresCena.livre.withValues(alpha: .10));
}

class CenaEstacionamento extends StatefulWidget {
  const CenaEstacionamento({super.key, this.recuo = EdgeInsets.zero, this.comFundo = true});

  final EdgeInsets recuo;

  final bool comFundo;

  @override
  State<CenaEstacionamento> createState() => _CenaEstacionamentoState();
}

class _CenaEstacionamentoState extends State<CenaEstacionamento> with SingleTickerProviderStateMixin {
  late final AnimationController _relogio = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _relogio.stop();
      _relogio.value = 4.6 / _periodo;
    } else if (!_relogio.isAnimating) {
      _relogio.repeat();
    }
  }

  @override
  void dispose() {
    _relogio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PintorCena(_relogio, widget.recuo, widget.comFundo),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PintorCena extends CustomPainter {
  _PintorCena(this.relogio, this.recuo, this.comFundo) : super(repaint: relogio);

  final Animation<double> relogio;
  final EdgeInsets recuo;
  final bool comFundo;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (comFundo) _pintarFundo(canvas, size);
    final area = recuo.deflateRect(Offset.zero & size);
    if (area.width > 20 && area.height > 20) {
      final escala = math.min(area.width / 96, area.height / 66);
      canvas.translate(
        area.left + (area.width - 96 * escala) / 2 - 2 * escala,
        area.top + (area.height - 66 * escala) / 2 - 2 * escala,
      );
      canvas.scale(escala);
      _Patio(canvas, relogio.value * _periodo).pintar();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorCena oldDelegate) =>
      oldDelegate.relogio != relogio || oldDelegate.recuo != recuo || oldDelegate.comFundo != comFundo;
}

const double _periodo = 24;
const double _raio = 6;
const double _corredor = 35;
const double _x0 = 14;
const double _larguraVaga = 12;
const double _fundoVaga = 16;

double _xVaga(int coluna) => _x0 + _larguraVaga * coluna + _larguraVaga / 2;
double _yVaga(int fila) => fila < 0 ? 16 : 54;
String _rotulo(int fila, int coluna) => '${fila < 0 ? 'A' : 'B'}${6 - coluna}';

const _parados = <(int, int, Color)>[
  (-1, 5, Color(0xFF64748B)),
  (-1, 2, Color(0xFF475569)),
  (1, 0, Color(0xFF7C8BA3)),
  (1, 4, Color(0xFF526079)),
];

const _animados = <(int, int, Color, double)>[
  (-1, 4, Color(0xFFF26B5B), 0.0),
  (1, 2, Color(0xFFE8ECF3), 8.0),
  (-1, 1, Color(0xFF5AA9FF), 16.0),
];

class _Trecho {
  _Trecho.reta(this.a, this.b)
      : centro = null,
        ang0 = 0,
        ang1 = 0,
        comprimento = (b - a).distance;

  _Trecho.curva(Offset this.centro, this.ang0, this.ang1)
      : a = Offset.zero,
        b = Offset.zero,
        comprimento = _raio * (ang1 - ang0).abs();

  final Offset a, b;
  final Offset? centro;
  final double ang0, ang1, comprimento;
}

class _Pose {
  const _Pose(this.posicao, this.angulo);

  final Offset posicao;

  final double angulo;
}

double _comprimento(List<_Trecho> trechos) => trechos.fold<double>(0, (soma, t) => soma + t.comprimento);

_Pose _poseEm(List<_Trecho> trechos, double distancia) {
  var resto = distancia;
  for (var k = 0; k < trechos.length; k++) {
    final t = trechos[k];
    if (resto <= t.comprimento || k == trechos.length - 1) {
      final f = t.comprimento == 0 ? 0.0 : (resto / t.comprimento).clamp(0.0, 1.0);
      final centro = t.centro;
      if (centro == null) {
        final v = t.b - t.a;
        return _Pose(t.a + v * f, math.atan2(v.dy, v.dx));
      }
      final ang = t.ang0 + (t.ang1 - t.ang0) * f;
      final direcao = t.ang1 > t.ang0 ? ang + math.pi / 2 : ang - math.pi / 2;
      return _Pose(centro + Offset(math.cos(ang), math.sin(ang)) * _raio, direcao);
    }
    resto -= t.comprimento;
  }
  return const _Pose(Offset.zero, 0);
}

class _Caminhos {
  _Caminhos(int fila, int coluna) {
    final x = _xVaga(coluna);
    final yCurva = _corredor + fila * _raio;
    final centro = Offset(x - _raio, yCurva);
    final cima = fila < 0;
    entrada = [
      _Trecho.reta(const Offset(-14, _corredor), Offset(x - _raio, _corredor)),
      _Trecho.curva(centro, cima ? math.pi / 2 : -math.pi / 2, 0),
      _Trecho.reta(Offset(x, yCurva), Offset(x, _yVaga(fila))),
    ];
    re = [
      _Trecho.reta(Offset(x, _yVaga(fila)), Offset(x, yCurva)),
      _Trecho.curva(centro, 0, cima ? math.pi / 2 : -math.pi / 2),
    ];
    saida = [_Trecho.reta(Offset(x - _raio, _corredor), const Offset(118, _corredor))];
  }

  late final List<_Trecho> entrada, re, saida;
}

double _suave(double p) {
  if (p < .5) return 4 * p * p * p;
  final q = -2 * p + 2;
  return 1 - q * q * q / 2;
}

double _fase(double tau, double inicio, double fim) => ((tau - inicio) / (fim - inicio)).clamp(0.0, 1.0);

double _ocupacao(double tau) => _fase(tau, 3.0, 3.5) * (1 - _fase(tau, 11.8, 12.3));

class _EstadoCarro {
  const _EstadoCarro(this.pose, {this.movendo = false, this.re = false});

  final _Pose pose;
  final bool movendo, re;
}

_EstadoCarro? _carro(int fila, int coluna, double tau) {
  final c = _Caminhos(fila, coluna);
  if (tau < 3.6) {
    return _EstadoCarro(_poseEm(c.entrada, _comprimento(c.entrada) * _suave(_fase(tau, 0, 3.6))), movendo: true);
  }
  if (tau < 11.4) return _EstadoCarro(_poseEm(c.entrada, _comprimento(c.entrada)));
  if (tau < 13.4) {
    final p = _poseEm(c.re, _comprimento(c.re) * _suave(_fase(tau, 11.4, 13.4)));
    return _EstadoCarro(_Pose(p.posicao, p.angulo + math.pi), movendo: true, re: true);
  }
  if (tau < 13.7) return _EstadoCarro(_poseEm(c.saida, 0));
  if (tau < 16.4) {
    final f = _fase(tau, 13.7, 16.4);
    return _EstadoCarro(_poseEm(c.saida, _comprimento(c.saida) * f * f), movendo: true);
  }
  return null;
}

class _Patio {
  _Patio(this.c, this.t);

  final Canvas c;
  final double t;

  static final RRect _lote = RRect.fromLTRBR(4, 4, 96, 66, const Radius.circular(3));

  static final Path _pontos = () {
    final p = Path();
    for (var x = -40.0; x < 140; x += 5) {
      for (var y = -20.0; y < 90; y += 5) {
        p.addRect(Rect.fromLTWH(x, y, .35, .35));
      }
    }
    return p;
  }();

  double _tau(double atraso) => (t - atraso) % _periodo;

  Paint _traco(Color cor, double largura) => Paint()
    ..color = cor
    ..style = PaintingStyle.stroke
    ..strokeWidth = largura
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void pintar() {
    c.drawPath(_pontos, Paint()..color = Colors.white.withValues(alpha: .05));
    _pintarLote();

    final ocupacao = <String, double>{};
    for (final p in _parados) {
      ocupacao['${p.$1}:${p.$2}'] = 1;
    }
    for (final a in _animados) {
      ocupacao['${a.$1}:${a.$2}'] = _ocupacao(_tau(a.$4));
    }
    _pintarVagas(ocupacao);
    _pintarVarredura();

    for (final p in _parados) {
      _carroDesenho(Offset(_xVaga(p.$2), _yVaga(p.$1)), p.$1 < 0 ? -math.pi / 2 : math.pi / 2, p.$3);
    }
    for (final a in _animados) {
      final estado = _carro(a.$1, a.$2, _tau(a.$4));
      if (estado != null) {
        _carroDesenho(estado.pose.posicao, estado.pose.angulo, a.$3, movendo: estado.movendo, re: estado.re);
      }
    }
    for (final a in _animados) {
      _deteccao(a.$1, a.$2, _tau(a.$4));
    }
  }

  void _pintarLote() {
    c.drawRRect(_lote, Paint()..color = Colors.white.withValues(alpha: .025));
    const canto = Radius.circular(3);
    final borda = Path()
      ..moveTo(4, 27)
      ..lineTo(4, 7)
      ..arcToPoint(const Offset(7, 4), radius: canto)
      ..lineTo(93, 4)
      ..arcToPoint(const Offset(96, 7), radius: canto)
      ..lineTo(96, 27)
      ..moveTo(96, 43)
      ..lineTo(96, 63)
      ..arcToPoint(const Offset(93, 66), radius: canto)
      ..lineTo(7, 66)
      ..arcToPoint(const Offset(4, 63), radius: canto)
      ..lineTo(4, 43);
    c.drawPath(borda, _traco(Colors.white.withValues(alpha: .10), .35));

    final faixa = _traco(CoresCena.texto.withValues(alpha: .14), .4);
    for (var x = 6.0; x < 94; x += 4.8) {
      c.drawLine(Offset(x, _corredor), Offset(x + 2.4, _corredor), faixa);
    }
    final seta = _traco(CoresCena.varredura.withValues(alpha: .25), .5);
    for (final x in const [8.0, 90.0]) {
      c.drawPath(
        Path()
          ..moveTo(x, _corredor - 3.6)
          ..lineTo(x + 1.6, _corredor - 2.4)
          ..lineTo(x, _corredor - 1.2),
        seta,
      );
    }
  }

  void _pintarVagas(Map<String, double> ocupacao) {
    for (final fila in const [-1, 1]) {
      for (var i = 0; i < 6; i++) {
        final x0 = _x0 + _larguraVaga * i;
        final y0 = fila < 0 ? 8.0 : 46.0;
        final cor = Color.lerp(CoresCena.livre, CoresCena.ocupada, ocupacao['$fila:$i'] ?? 0.0)!;
        c.drawRect(Rect.fromLTWH(x0 + .4, y0, _larguraVaga - .8, _fundoVaga), Paint()..color = cor.withValues(alpha: .07));
        final led = RRect.fromRectAndRadius(
          Rect.fromLTWH(x0 + 3, fila < 0 ? 9.2 : 60.2, _larguraVaga - 6, .7),
          const Radius.circular(.35),
        );
        c.drawRRect(led.inflate(1.1), Paint()..color = cor.withValues(alpha: .10));
        c.drawRRect(led.inflate(.5), Paint()..color = cor.withValues(alpha: .22));
        c.drawRRect(led, Paint()..color = cor);
        _texto(
          _rotulo(fila, i),
          Offset(x0 + _larguraVaga / 2, fila < 0 ? 22.3 : 48.3),
          2.1,
          FontWeight.w600,
          CoresCena.texto.withValues(alpha: .32),
        );
      }
    }
    final linha = _traco(CoresCena.texto.withValues(alpha: .26), .4)..strokeCap = StrokeCap.butt;
    for (final (y0, y1, yFundo) in const [(8.0, 24.0, 8.0), (46.0, 62.0, 62.0)]) {
      for (var i = 0; i <= 6; i++) {
        final x = _x0 + _larguraVaga * i;
        c.drawLine(Offset(x, y0), Offset(x, y1), linha);
      }
      c.drawLine(Offset(_x0, yFundo), Offset(_x0 + 6 * _larguraVaga, yFundo), linha);
    }
  }

  void _pintarVarredura() {
    final x = 4 + 92 * ((t % 6) / 6);
    final rastro = Rect.fromLTWH(x - 10, 4, 10, 62);
    c.save();
    c.clipRRect(_lote);
    c.drawRect(
      rastro,
      Paint()
        ..shader = LinearGradient(
          colors: [CoresCena.varredura.withValues(alpha: 0), CoresCena.varredura.withValues(alpha: .10)],
        ).createShader(rastro),
    );
    c.drawRect(Rect.fromLTWH(x - .15, 4, .3, 62), Paint()..color = CoresCena.varredura.withValues(alpha: .35));
    c.restore();
  }

  void _carroDesenho(Offset p, double angulo, Color cor, {bool movendo = false, bool re = false}) =>
      desenharCarroVistoDeCima(c, p, angulo, cor, movendo: movendo, re: re);

  void _deteccao(int fila, int coluna, double tau) {
    String? estado;
    var cor = CoresCena.livre;
    var k = 0.0;
    if (tau >= 3.6 && tau < 6.2) {
      k = tau - 3.6;
      estado = 'ocupada';
      cor = CoresCena.ocupada;
    } else if (tau >= 13.6 && tau < 16.2) {
      k = tau - 13.6;
      estado = 'livre';
    }
    if (estado == null) return;

    final alfa = (math.min(1.0, k / .25) * math.min(1.0, (2.6 - k) / .4)).clamp(0.0, 1.0);
    final escala = 1 + .25 * (1 - _suave(math.min(1.0, k / .35)));
    final centro = Offset(_xVaga(coluna), _yVaga(fila));
    final r = Rect.fromCenter(
      center: centro,
      width: (_larguraVaga - 1.2) * escala,
      height: (_fundoVaga - 1.2) * escala,
    );
    const q = 2.4;
    final cantos = Path()
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
      ..lineTo(r.left, r.bottom - q);
    final corAlfa = cor.withValues(alpha: alfa);
    c.drawPath(cantos, _traco(corAlfa, .55));

    final etiqueta = _layout('${_rotulo(fila, coluna)} · $estado', 2.1, FontWeight.w700,
        const Color(0xFF06101C).withValues(alpha: alfa));
    final w = etiqueta.width + 2.4;
    final topo = fila < 0 ? r.bottom + 1 : r.top - 4.4;
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(centro.dx - w / 2, topo, w, 3.4), const Radius.circular(1.7)),
      Paint()..color = corAlfa,
    );
    etiqueta.paint(c, Offset(centro.dx - etiqueta.width / 2, topo + (3.4 - etiqueta.height) / 2));
    etiqueta.dispose();
  }

  TextPainter _layout(String texto, double tamanho, FontWeight peso, Color cor) => TextPainter(
        text: TextSpan(text: texto, style: _mono(tamanho, peso, cor)),
        textDirection: TextDirection.ltr,
      )..layout();

  void _texto(String texto, Offset centro, double tamanho, FontWeight peso, Color cor) {
    final tp = _layout(texto, tamanho, peso, cor);
    tp.paint(c, centro - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }
}

void desenharCarroVistoDeCima(
  Canvas c,
  Offset p,
  double angulo,
  Color cor, {
  double escala = 1,
  bool movendo = false,
  bool re = false,
}) {
  const comprimento = 9.4, largura = 5.0;
  RRect caixa(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  c.save();
  c.translate(p.dx, p.dy);
  c.rotate(angulo);
  c.scale(escala);
  if (movendo) {
    const luz = Color(0xFFFFECAA);
    final cone = Path()
      ..moveTo(comprimento / 2, -largura / 2 + .6)
      ..lineTo(comprimento / 2 + 16, -largura / 2 - 4)
      ..lineTo(comprimento / 2 + 16, largura / 2 + 4)
      ..lineTo(comprimento / 2, largura / 2 - .6)
      ..close();
    c.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(colors: [luz.withValues(alpha: re ? .12 : .28), luz.withValues(alpha: 0)])
            .createShader(const Rect.fromLTWH(comprimento / 2, -10, 16, 20)),
    );
  }
  c.drawRRect(caixa(-comprimento / 2 + .5, -largura / 2 + .7, comprimento + .3, largura + .3, 1.8),
      Paint()..color = Colors.black.withValues(alpha: .45));
  c.drawRRect(caixa(-comprimento / 2, -largura / 2, comprimento, largura, 1.7), Paint()..color = cor);
  c.drawRRect(caixa(-1.9, -largura / 2 + .55, 5.0, largura - 1.1, 1.1),
      Paint()..color = const Color(0xFF0A1220).withValues(alpha: .78));
  c.drawRRect(caixa(1.7, -largura / 2 + .8, 1.25, largura - 1.6, .5), Paint()..color = Colors.white.withValues(alpha: .18));
  c.drawRRect(caixa(-.8, -largura / 2 + .9, 1.9, largura - 1.8, .5), Paint()..color = Colors.white.withValues(alpha: .10));
  final farol = Paint()..color = const Color(0xFFFFF4C8);
  c.drawRRect(caixa(comprimento / 2 - .7, -largura / 2 + .45, .6, 1.1, .3), farol);
  c.drawRRect(caixa(comprimento / 2 - .7, largura / 2 - 1.55, .6, 1.1, .3), farol);
  final lanterna = Paint()..color = re ? const Color(0xFFFF6B6B) : const Color(0xFFFF5050).withValues(alpha: .65);
  c.drawRRect(caixa(-comprimento / 2 + .1, -largura / 2 + .45, .55, 1.1, .3), lanterna);
  c.drawRRect(caixa(-comprimento / 2 + .1, largura / 2 - 1.55, .55, 1.1, .3), lanterna);
  c.restore();
}

class MarcaCena extends StatelessWidget {
  const MarcaCena({super.key, required this.logo, this.tamanho = 20});

  final Widget logo;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 12),
        Text('VagaVision', style: _mono(tamanho, FontWeight.w700, Colors.white)),
      ],
    );
  }
}

class MancheteCena extends StatelessWidget {
  const MancheteCena({super.key, this.tamanhoTitulo = 38});

  final double tamanhoTitulo;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Encontre sua vaga\nantes de chegar.',
          style: _mono(tamanhoTitulo, FontWeight.w700, Colors.white).copyWith(height: 1.15),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'A câmera do Bloco U identifica as vagas livres e ocupadas e atualiza o mapa em tempo real.',
            style: _mono(14, FontWeight.w400, CoresCena.textoSuave).copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: 20),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Selo(cor: CoresCena.livre, texto: 'Livre'),
            _Selo(cor: CoresCena.ocupada, texto: 'Ocupada'),
            _Selo(cor: CoresCena.varredura, texto: 'Visão computacional'),
          ],
        ),
      ],
    );
  }
}

class _Selo extends StatelessWidget {
  const _Selo({required this.cor, required this.texto});

  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(texto, style: _mono(12, FontWeight.w600, CoresCena.texto)),
        ],
      ),
    );
  }
}

class TituloAcesso extends StatelessWidget {
  const TituloAcesso({super.key, required this.texto, required this.suave, this.compacto = false});

  final Color texto, suave;

  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Acesse sua conta', style: _mono(compacto ? 20 : 26, FontWeight.w700, texto)),
        if (!compacto) ...[
          const SizedBox(height: 8),
          Text(
            'Veja as vagas livres do campus em tempo real.',
            style: _mono(13, FontWeight.w400, suave).copyWith(height: 1.5),
          ),
        ],
      ],
    );
  }
}

class BotaoGoogle extends StatelessWidget {
  const BotaoGoogle({super.key, required this.onTap, required this.carregando, required this.claro});

  final VoidCallback? onTap;
  final bool carregando;

  final bool claro;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(14);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: raio,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: claro ? .08 : .28), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: raio,
          side: claro ? const BorderSide(color: Color(0xFFDADCE0)) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (carregando)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF124BBD)),
                    )
                  else
                    Semantics(label: 'Google', child: const LogoGoogle(tamanho: 20)),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Entrar com Google',
                      overflow: TextOverflow.ellipsis,
                      style: _mono(15, FontWeight.w700, const Color(0xFF1F2937)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DivisorOu extends StatelessWidget {
  const DivisorOu({super.key, required this.cor});

  final Color cor;

  @override
  Widget build(BuildContext context) {
    final linha = Expanded(child: Divider(height: 1, thickness: 1, color: cor.withValues(alpha: .25)));
    return Row(
      children: [
        linha,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('ou', style: _mono(12, FontWeight.w500, cor)),
        ),
        linha,
      ],
    );
  }
}

class CaixaMensagem extends StatelessWidget {
  const CaixaMensagem({super.key, required this.texto, this.cor = CoresCena.erro});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: .35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: cor),
            const SizedBox(width: 10),
            Expanded(child: Text(texto, style: _mono(12, FontWeight.w500, cor).copyWith(height: 1.45))),
          ],
        ),
      ),
    );
  }
}

class LayoutLoginVertical extends StatelessWidget {
  const LayoutLoginVertical({super.key, required this.marca, required this.folha, required this.child});

  final Widget marca;
  final Color folha;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borda = MediaQuery.paddingOf(context);
    return LayoutBuilder(builder: (context, c) {
      final alturaCena = (c.maxHeight * .36).clamp(190.0, 360.0);
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: alturaCena,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CenaEstacionamento(recuo: EdgeInsets.fromLTRB(12, borda.top + 52, 12, 14)),
                    Positioned(left: 20, top: borda.top + 16, child: marca),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: math.max(0.0, c.maxHeight - alturaCena)),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: folha,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + borda.bottom),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: child),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class EntradaSuave extends StatelessWidget {
  const EntradaSuave({super.key, required this.child, this.duracao = const Duration(milliseconds: 500)});

  final Widget child;
  final Duration duracao;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duracao,
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
      ),
      child: child,
    );
  }
}
