import 'package:flutter/material.dart';

/// Logo do VagaVision (olho/escudo) desenhado em código.
/// Aproximação do desenho do Figma; para fidelidade total, exporte o logo como SVG
/// e use o pacote flutter_svg.
class LogoVagaVision extends StatelessWidget {
  const LogoVagaVision({super.key, this.largura = 84, this.cor = Colors.white});

  final double largura;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(largura, largura * 0.75), painter: _LogoPainter(cor));
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 80, size.height / 60); // espaço de desenho 80 x 60
    final traco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = cor;

    // contorno externo + pontas superiores
    canvas.drawPath(
      Path()
        ..moveTo(24, 3)
        ..lineTo(3, 7)
        ..cubicTo(3, 34, 20, 50, 40, 52)
        ..cubicTo(60, 50, 77, 34, 77, 7)
        ..lineTo(56, 3),
      traco,
    );
    // arco interno
    canvas.drawPath(
      Path()
        ..moveTo(24, 3)
        ..cubicTo(16, 24, 26, 40, 40, 44)
        ..cubicTo(54, 40, 64, 24, 56, 3),
      traco,
    );
    // íris e brilho
    const centro = Offset(40, 23);
    canvas.drawCircle(centro, 10, traco);
    canvas.drawArc(Rect.fromCircle(center: centro, radius: 5), -1.3, 1.7, false, traco);
    // ponta inferior
    canvas.drawPath(
      Path()
        ..moveTo(35, 49)
        ..lineTo(40, 57)
        ..lineTo(45, 49),
      traco,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.cor != cor;
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
