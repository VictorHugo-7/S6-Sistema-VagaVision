import 'package:flutter/material.dart';

import '../historico.dart';
import '../painel_analise.dart';
import 'garagem_controller.dart';
import 'quadro_tela.dart';
import 'theme.dart';

/// Tela "Painel": previsão de lotação e análise da ocupação (versão celular).
class PainelPagina extends StatelessWidget {
  const PainelPagina({super.key, required this.historico, required this.controller});

  final HistoricoOcupacao historico;
  final GaragemController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final estilo = EstiloPainel(
      texto: p.texto,
      suave: p.textoSuave,
      cartao: p.campo,
      destaque: Cores.azulBotao,
      livre: Cores.livre,
      medio: const Color(0xFFE0B21F),
      ocupada: Cores.ocupada,
      fonte: (t, {peso, cor}) => textoMono(t, peso: peso ?? FontWeight.w500, cor: cor),
    );
    return QuadroTela(
      titulo: 'Painel',
      icone: const Icon(Icons.insert_chart_rounded, color: Colors.white, size: 32),
      preenchido: true,
      child: Column(
        children: [
          const SizedBox(height: 33),
          Text('Painel', style: textoMono(20)),
          const SizedBox(height: 24),
          Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(color: p.destaque, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => PainelAnalise(
                  historico: historico,
                  estilo: estilo,
                  ocupacaoAtual: ocupacaoGeral([
                    for (final n in controller.niveis) [for (final v in n) v.ocupada],
                  ]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 35),
            child: SizedBox(
              width: double.infinity,
              child: Material(
                color: Cores.azulBotao,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: Text('Voltar', style: textoMono(12, peso: FontWeight.w700, cor: Colors.white))),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
