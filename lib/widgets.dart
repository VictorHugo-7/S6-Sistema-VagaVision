import 'package:flutter/material.dart';

import 'theme.dart';

class BotaoAzul extends StatelessWidget {
  const BotaoAzul({super.key, required this.texto, required this.onTap, this.altura = alvoToque, this.pequeno = false});

  final String texto;
  final VoidCallback onTap;
  final double altura;
  final bool pequeno;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Cores.azulBotao,
      borderRadius: BorderRadius.circular(pequeno ? 6 : 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(pequeno ? 6 : 12),
        onTap: onTap,
        child: Container(
          height: altura,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: pequeno ? 10 : 16),
          child: Text(texto, style: mono(pequeno ? 12 : 13, peso: FontWeight.w700, cor: Colors.white)),
        ),
      ),
    );
  }
}

/// Centraliza a folha das telas de alertas com largura e altura máximas
/// (em telas grandes o cartão não estica por toda a janela).
class PaginaFolha extends StatelessWidget {
  const PaginaFolha({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}

/// Cartão branco arredondado usado nas telas de alertas.
class FolhaBranca extends StatelessWidget {
  const FolhaBranca({super.key, required this.titulo, required this.filhos, required this.rodape});

  final String titulo;
  final List<Widget> filhos;
  final Widget rodape;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
      child: Column(
        children: [
          Text(titulo, style: mono(20, peso: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 18),
          Container(
            height: 8,
            decoration: BoxDecoration(color: Cores.azul, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 16),
          Expanded(child: ListView(children: filhos)),
          const SizedBox(height: 12),
          rodape,
        ],
      ),
    );
  }
}
