import 'package:flutter/material.dart';

import 'garagem_controller.dart';
import 'historico.dart';
import 'painel_analise.dart';
import 'theme.dart';
import 'widgets.dart';

/// Painel de análise + previsão de lotação (versão web/tablet).
class PainelPage extends StatelessWidget {
  const PainelPage({super.key, required this.historico, required this.garagem, required this.onVoltar});

  final HistoricoOcupacao historico;
  final GaragemController garagem;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final estilo = EstiloPainel(
      texto: p.texto,
      suave: p.textoSuave,
      cartao: p.campo,
      destaque: Cores.azulBotao,
      livre: Cores.livre,
      medio: Cores.alertaSimples,
      ocupada: Cores.ocupada,
      fonte: (t, {peso, cor}) => mono(t, peso: peso ?? FontWeight.w500, cor: cor),
    );
    return PaginaFolha(
      child: FolhaBranca(
        titulo: 'Painel',
        rodape: BotaoAzul(texto: 'Voltar', altura: 48, onTap: onVoltar),
        filhos: [
          ListenableBuilder(
            listenable: garagem,
            builder: (context, _) => PainelAnalise(
              historico: historico,
              estilo: estilo,
              ocupacaoAtual: ocupacaoGeral([
                for (final n in garagem.niveis) [for (final v in n) v.ocupada],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
