import 'package:flutter/material.dart';

import 'theme.dart';

/// Logo do VagaVision (olho dentro de um escudo), desenhado em vetor.
/// Aproximação do logo do Figma; para o original, exporte-o como SVG.
class LogoVaga extends StatelessWidget {
  const LogoVaga({super.key, this.cor = Colors.white, this.fundo = Cores.azul, this.largura = 130});

  final Color cor, fundo;
  final double largura;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largura,
      height: largura * 0.9,
      child: CustomPaint(painter: _LogoPainter(cor, fundo)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.cor, this.fundo);

  final Color cor, fundo;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final traco = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // escudo externo
    final escudo = Path()
      ..moveTo(p(50, 88).dx, p(50, 88).dy)
      ..cubicTo(30 * s, 84 * s, 9 * s, 62 * s, 5 * s, 24 * s)
      ..lineTo(p(21, 12).dx, p(21, 12).dy)
      ..lineTo(p(28, 18).dx, p(28, 18).dy)
      ..moveTo(p(50, 88).dx, p(50, 88).dy)
      ..cubicTo(70 * s, 84 * s, 91 * s, 62 * s, 95 * s, 24 * s)
      ..lineTo(p(79, 12).dx, p(79, 12).dy)
      ..lineTo(p(72, 18).dx, p(72, 18).dy);
    canvas.drawPath(escudo, traco);

    // arco interno
    final arco = Path()
      ..moveTo(p(28, 20).dx, p(28, 20).dy)
      ..cubicTo(28 * s, 56 * s, 38 * s, 76 * s, 50 * s, 76 * s)
      ..cubicTo(62 * s, 76 * s, 72 * s, 56 * s, 72 * s, 20 * s);
    canvas.drawPath(arco, traco);

    // olho
    canvas.drawCircle(p(50, 38), 17 * s, traco);
    canvas.drawCircle(p(50, 38), 10.5 * s, Paint()..color = cor);
    canvas.drawCircle(p(55, 33), 3.4 * s, Paint()..color = fundo);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.cor != cor || old.fundo != fundo;
}

/// Logo do Google ("G" colorido) desenhado em código.
class LogoGoogle extends StatelessWidget {
  const LogoGoogle({super.key, this.tamanho = 20});

  final double tamanho;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(tamanho, tamanho), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final azul = Path()
      ..moveTo(23.49, 12.27)
      ..cubicTo(23.49, 11.48, 23.42, 10.73, 23.3, 10)
      ..lineTo(12, 10)
      ..lineTo(12, 14.51)
      ..lineTo(18.47, 14.51)
      ..cubicTo(18.18, 15.99, 17.33, 17.24, 16.07, 18.09)
      ..lineTo(16.07, 21.09)
      ..lineTo(19.93, 21.09)
      ..cubicTo(22.19, 19, 23.49, 15.92, 23.49, 12.27)
      ..close();
    canvas.drawPath(azul, Paint()..color = const Color(0xFF4285F4)..isAntiAlias = true);
    final verde = Path()
      ..moveTo(12, 24)
      ..cubicTo(15.24, 24, 17.95, 22.92, 19.93, 21.09)
      ..lineTo(16.07, 18.09)
      ..cubicTo(14.99, 18.81, 13.62, 19.25, 12, 19.25)
      ..cubicTo(8.87, 19.25, 6.22, 17.14, 5.27, 14.29)
      ..lineTo(1.29, 14.29)
      ..lineTo(1.29, 17.38)
      ..cubicTo(3.26, 21.3, 7.31, 24, 12, 24)
      ..close();
    canvas.drawPath(verde, Paint()..color = const Color(0xFF34A853)..isAntiAlias = true);
    final amarelo = Path()
      ..moveTo(5.27, 14.29)
      ..cubicTo(5.02, 13.57, 4.89, 12.8, 4.89, 12)
      ..cubicTo(4.89, 11.2, 5.03, 10.43, 5.27, 9.71)
      ..lineTo(5.27, 6.62)
      ..lineTo(1.29, 6.62)
      ..cubicTo(0.47, 8.24, 0, 10.06, 0, 12)
      ..cubicTo(0, 13.94, 0.47, 15.76, 1.29, 17.38)
      ..lineTo(5.27, 14.29)
      ..close();
    canvas.drawPath(amarelo, Paint()..color = const Color(0xFFFBBC05)..isAntiAlias = true);
    final vermelho = Path()
      ..moveTo(12, 4.75)
      ..cubicTo(13.77, 4.75, 15.35, 5.36, 16.6, 6.55)
      ..lineTo(20.02, 3.13)
      ..cubicTo(17.95, 1.19, 15.24, 0, 12, 0)
      ..cubicTo(7.31, 0, 3.26, 2.7, 1.29, 6.62)
      ..lineTo(5.27, 9.71)
      ..cubicTo(6.22, 6.86, 8.87, 4.75, 12, 4.75)
      ..close();
    canvas.drawPath(vermelho, Paint()..color = const Color(0xFFEA4335)..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}
