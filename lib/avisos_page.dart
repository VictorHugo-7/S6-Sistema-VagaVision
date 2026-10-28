import 'package:flutter/material.dart';

import 'localizacao.dart';
import 'meu_carro.dart';
import 'notificacoes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Histórico de avisos (alertas de vagas). Os avisos novos também aparecem como banner na hora.
class AvisosPage extends StatelessWidget {
  const AvisosPage({super.key, required this.notif, required this.campus, required this.meuCarro, required this.onVoltar});

  final NotificacoesController notif;
  final LocalizacaoCampus campus;
  final MeuCarro meuCarro;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    return PaginaFolha(
      child: ListenableBuilder(
        listenable: Listenable.merge([notif, campus, meuCarro]),
        builder: (context, _) {
          final itens = notif.itens;
          return FolhaBranca(
            titulo: 'Avisos',
            rodape: Row(
              children: [
                Expanded(child: BotaoAzul(texto: 'Marcar como lidos', altura: 48, onTap: notif.marcarTodasLidas)),
                const SizedBox(width: 10),
                Expanded(child: BotaoAzul(texto: 'Limpar', altura: 48, onTap: notif.limpar)),
              ],
            ),
            filhos: [
              _InterruptorVagaLivre(notif: notif),
              const SizedBox(height: 8),
              _InterruptorFaculdade(notif: notif),
              const SizedBox(height: 6),
              _StatusAvisos(notif: notif, campus: campus, meuCarro: meuCarro),
              const SizedBox(height: 8),
              if (itens.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'Nenhum aviso por enquanto.\nQuando uma vaga for desocupada, ou um alerta de Alertas disparar, o aviso aparece aqui.',
                    textAlign: TextAlign.center,
                    style: mono(13, cor: context.paleta.textoSuave),
                  ),
                ),
              for (final n in itens) _LinhaAviso(aviso: n),
            ],
          );
        },
      ),
    );
  }
}

Color corDoTipo(TipoNotificacao t) => switch (t) {
      TipoNotificacao.info => Cores.azulBotao,
      TipoNotificacao.livre => Cores.ativo,
      TipoNotificacao.aviso => Cores.alertaMedio,
      TipoNotificacao.critico => Cores.ocupada,
    };

IconData iconeDoTipo(TipoNotificacao t) => switch (t) {
      TipoNotificacao.info => Icons.info_rounded,
      TipoNotificacao.livre => Icons.check_circle_rounded,
      TipoNotificacao.aviso => Icons.warning_amber_rounded,
      TipoNotificacao.critico => Icons.error_rounded,
    };

class _LinhaAviso extends StatelessWidget {
  const _LinhaAviso({required this.aviso});

  final Notificacao aviso;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(
        label: '${aviso.titulo}. ${aviso.mensagem}. ${quandoTexto(aviso.quando)}${aviso.lida ? '' : '. Não lido'}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.campo,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: aviso.lida ? Colors.transparent : corDoTipo(aviso.tipo), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(iconeDoTipo(aviso.tipo), color: corDoTipo(aviso.tipo), size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(aviso.titulo, style: mono(14, peso: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(aviso.mensagem, style: mono(12)),
                    const SizedBox(height: 4),
                    Text(quandoTexto(aviso.quando), style: mono(11, cor: p.textoSuave)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chave "Avisar quando uma vaga for desocupada".
class _InterruptorVagaLivre extends StatelessWidget {
  const _InterruptorVagaLivre({required this.notif});

  final NotificacoesController notif;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(color: p.campo, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Cores.ativo, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text('Avisar quando uma vaga for desocupada', style: mono(13, peso: FontWeight.w700))),
          Switch(
            value: notif.avisarVagaLivre,
            activeThumbColor: Colors.white,
            activeTrackColor: Cores.ativo,
            onChanged: notif.definirAvisarVagaLivre,
          ),
        ],
      ),
    );
  }
}

/// Chave "Só avisar quando eu estiver na faculdade".
class _InterruptorFaculdade extends StatelessWidget {
  const _InterruptorFaculdade({required this.notif});

  final NotificacoesController notif;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(color: p.campo, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, color: Cores.ativo, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text('Só avisar quando eu estiver na faculdade', style: mono(13, peso: FontWeight.w700))),
          Switch(
            value: notif.somenteNaFaculdade,
            activeThumbColor: Colors.white,
            activeTrackColor: Cores.ativo,
            onChanged: notif.definirSomenteNaFaculdade,
          ),
        ],
      ),
    );
  }
}

/// Explica por que os avisos estão (ou não) chegando agora, com botão para ligar a localização.
class _StatusAvisos extends StatelessWidget {
  const _StatusAvisos({required this.notif, required this.campus, required this.meuCarro});

  final NotificacoesController notif;
  final LocalizacaoCampus campus;
  final MeuCarro meuCarro;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final precisaLocalizacao = notif.somenteNaFaculdade && !meuCarro.estacionado && precisaAtivarLocalizacao(campus);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusDosAvisos(carro: meuCarro, campus: campus, somenteNaFaculdade: notif.somenteNaFaculdade),
            style: mono(12, cor: p.textoSuave),
          ),
          if (precisaLocalizacao) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: BotaoAzul(
                texto: 'Ativar localização',
                altura: 40,
                pequeno: true,
                onTap: () => campus.verificar(pedirPermissao: true),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
