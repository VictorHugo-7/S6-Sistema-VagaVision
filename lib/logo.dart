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

/// Logo da Microsoft (4 quadrados nas cores oficiais).
class LogoMicrosoft extends StatelessWidget {
  const LogoMicrosoft({super.key, this.tamanho = 20});

  final double tamanho;

  @override
  Widget build(BuildContext context) {
    const folga = 2.0;
    final lado = (tamanho - folga) / 2;
    Widget q(Color c) => Container(width: lado, height: lado, color: c);
    return SizedBox(
      width: tamanho,
      height: tamanho,
      child: Column(
        children: [
          Row(children: [q(const Color(0xFFF25022)), const SizedBox(width: folga), q(const Color(0xFF7FBA00))]),
          const SizedBox(height: folga),
          Row(children: [q(const Color(0xFF00A4EF)), const SizedBox(width: folga), q(const Color(0xFFFFB900))]),
        ],
      ),
    );
  }
}
