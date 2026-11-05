import 'package:flutter/material.dart';

import 'cena_login.dart';
import 'localizacao.dart';
import 'meu_carro.dart';
import 'notificacoes.dart';
import 'theme.dart';
import 'widgets.dart';

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
            subtitulo: 'Vagas liberadas e alertas dos seus blocos',
            icone: Icons.notifications_rounded,
            rodape: Row(
              children: [
                Expanded(child: BotaoAzul(texto: 'Marcar como lidos', altura: 48, onTap: notif.marcarTodasLidas)),
                const SizedBox(width: 10),
                Expanded(child: BotaoContorno(texto: 'Limpar', altura: 48, onTap: notif.limpar)),
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
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(
                    children: [
                      IconeBolha(icone: Icons.notifications_none_rounded, cor: context.paleta.textoSuave, tamanho: 52),
                      const SizedBox(height: 14),
                      Text('Nenhum aviso por enquanto', style: mono(14, peso: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        'Quando uma vaga for desocupada, ou um alerta de Alertas disparar, o aviso aparece aqui.',
                        textAlign: TextAlign.center,
                        style: mono(12, cor: context.paleta.textoSuave),
                      ),
                    ],
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
    final cor = corDoTipo(aviso.tipo);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Semantics(
        label: '${aviso.titulo}. ${aviso.mensagem}. ${quandoTexto(aviso.quando)}${aviso.lida ? '' : '. Não lido'}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.campo,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: aviso.lida ? Colors.transparent : cor.withValues(alpha: 0.6), width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconeBolha(icone: iconeDoTipo(aviso.tipo), cor: cor, tamanho: 38),
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
              if (!aviso.lida)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4, left: 8),
                  decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaChave extends StatelessWidget {
  const _LinhaChave({required this.icone, required this.cor, required this.texto, required this.valor, required this.onChanged});

  final IconData icone;
  final Color cor;
  final String texto;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: p.campo, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          IconeBolha(icone: icone, cor: cor, tamanho: 36),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: mono(13, peso: FontWeight.w700))),
          Switch(
            value: valor,
            activeThumbColor: Colors.white,
            activeTrackColor: Cores.ativo,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _InterruptorVagaLivre extends StatelessWidget {
  const _InterruptorVagaLivre({required this.notif});

  final NotificacoesController notif;

  @override
  Widget build(BuildContext context) {
    return _LinhaChave(
      icone: Icons.check_circle_rounded,
      cor: CoresCena.livre,
      texto: 'Avisar quando uma vaga for desocupada',
      valor: notif.avisarVagaLivre,
      onChanged: notif.definirAvisarVagaLivre,
    );
  }
}

class _InterruptorFaculdade extends StatelessWidget {
  const _InterruptorFaculdade({required this.notif});

  final NotificacoesController notif;

  @override
  Widget build(BuildContext context) {
    return _LinhaChave(
      icone: Icons.location_on_rounded,
      cor: CoresCena.varredura,
      texto: 'Só avisar quando eu estiver na faculdade',
      valor: notif.somenteNaFaculdade,
      onChanged: notif.definirSomenteNaFaculdade,
    );
  }
}

class _StatusAvisos extends StatelessWidget {
  const _StatusAvisos({required this.notif, required this.campus, required this.meuCarro});

  final NotificacoesController notif;
  final LocalizacaoCampus campus;
  final MeuCarro meuCarro;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final precisaLocalizacao = notif.somenteNaFaculdade && !meuCarro.estacionado && precisaAtivarLocalizacao(campus);
    final texto = statusDosAvisos(carro: meuCarro, campus: campus, somenteNaFaculdade: notif.somenteNaFaculdade);
    if (!precisaLocalizacao) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: p.textoSuave),
            const SizedBox(width: 8),
            Expanded(child: Text(texto, style: mono(12, cor: p.textoSuave))),
          ],
        ),
      );
    }
    const atencao = Cores.alertaSimples;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: atencao.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: atencao.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_off_rounded, size: 18, color: atencao),
              const SizedBox(width: 8),
              Expanded(child: Text(texto, style: mono(12, peso: FontWeight.w600, cor: p.texto))),
            ],
          ),
          const SizedBox(height: 10),
          BotaoAzul(
            texto: 'Ativar localização',
            altura: 40,
            pequeno: true,
            onTap: () => campus.verificar(pedirPermissao: true),
          ),
        ],
      ),
    );
  }
}
