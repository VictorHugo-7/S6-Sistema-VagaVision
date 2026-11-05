import 'package:flutter/material.dart';

import 'cena_login.dart';
import 'garagem_controller.dart';
import 'historico.dart';
import 'painel_analise.dart';
import 'theme.dart';
import 'widgets.dart';

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
      livre: CoresCena.livre,
      medio: Cores.alertaSimples,
      ocupada: CoresCena.ocupada,
      fonte: (t, {peso, cor}) => mono(t, peso: peso ?? FontWeight.w500, cor: cor),
    );
    return PaginaFolha(
      child: FolhaBranca(
        titulo: 'Painel',
        subtitulo: 'Ocupação agora, picos e previsão de lotação',
        icone: Icons.insert_chart_rounded,
        rodape: BotaoContorno(texto: 'Voltar', altura: 48, icone: Icons.arrow_back_rounded, onTap: onVoltar),
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
