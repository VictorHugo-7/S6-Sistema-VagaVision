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
