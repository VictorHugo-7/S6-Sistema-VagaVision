import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

/// Texto padrão do app (IBM Plex Mono, como no Figma).
TextStyle textoMono(double tamanho, {FontWeight peso = FontWeight.w600, Color cor = Cores.preto, double? altura}) =>
    GoogleFonts.ibmPlexMono(fontSize: tamanho, fontWeight: peso, color: cor, height: altura);

/// Moldura comum às telas do Figma: fundo azul, quadro arredondado com o conteúdo
/// e folha branca embaixo com o ícone redondo e o nome da tela ("Mapa", "Alertas").
class QuadroTela extends StatelessWidget {
  const QuadroTela({
    super.key,
    required this.titulo,
    required this.icone,
    required this.child,
    this.preenchido = false,
  });

  final String titulo;
  final Widget icone;
  final Widget child;

  /// `false`: só a linha branca em volta (tela Mapa). `true`: cartão branco cheio (tela Alertas).
  final bool preenchido;

  @override
  Widget build(BuildContext context) {
    final inferior = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Cores.fundo,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 12, 11, 11),
                    child: Container(
                      decoration: BoxDecoration(
                        color: preenchido ? Cores.branco : null,
                        borderRadius: BorderRadius.circular(30),
                        border: preenchido ? null : Border.all(color: Cores.moldura, width: 3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(preenchido ? 30 : 27),
                        child: child,
                      ),
                    ),
                  ),
                ),
                _Rodape(titulo: titulo, icone: icone, inferior: inferior),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({required this.titulo, required this.icone, required this.inferior});

  final String titulo;
  final Widget icone;
  final double inferior;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120 + inferior,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Cores.branco,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 38),
                  child: Text(titulo, style: textoMono(20)),
                ),
              ),
            ),
          ),
          Positioned(
            top: -35,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Cores.fundo, shape: BoxShape.circle),
                child: icone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
