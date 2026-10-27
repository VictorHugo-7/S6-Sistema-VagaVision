import 'package:flutter/material.dart';

import '../localizacao.dart';
import '../meu_carro.dart';
import '../notificacoes.dart';
import 'quadro_tela.dart';
import 'theme.dart';

/// Tela "Avisos": histórico das notificações (vaga liberada, bloco lotado...).
class AvisosPagina extends StatelessWidget {
  const AvisosPagina({super.key, required this.notif, required this.campus, required this.meuCarro});

  final NotificacoesController notif;
  final LocalizacaoCampus campus;
  final MeuCarro meuCarro;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return QuadroTela(
      titulo: 'Avisos',
      icone: const Icon(Icons.notifications_rounded, color: Colors.white, size: 32),
      preenchido: true,
      child: Column(
        children: [
          const SizedBox(height: 33),
          Text('Avisos', style: textoMono(20)),
          const SizedBox(height: 24),
          Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(color: p.destaque, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: Listenable.merge([notif, campus, meuCarro]),
            builder: (context, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
                decoration: BoxDecoration(color: p.campo, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Cores.ativo, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Avisar quando uma vaga for desocupada',
                          style: textoMono(12, peso: FontWeight.w700)),
                    ),
                    Switch(
                      value: notif.avisarVagaLivre,
                      activeThumbColor: Colors.white,
                      activeTrackColor: Cores.ativo,
                      onChanged: notif.definirAvisarVagaLivre,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _InterruptorFaculdade(notif: notif),
              const SizedBox(height: 6),
              _StatusAvisos(notif: notif, campus: campus, meuCarro: meuCarro),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListenableBuilder(
              listenable: notif,
              builder: (context, _) {
                final itens = notif.itens;
                if (itens.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Center(
                      child: Text(
                        'Nenhum aviso por enquanto.\nQuando uma vaga for desocupada, o aviso aparece aqui.',
                        textAlign: TextAlign.center,
                        style: textoMono(12, peso: FontWeight.w500, cor: p.textoSuave),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: itens.length,
                  itemBuilder: (context, i) => _LinhaAviso(aviso: itens[i]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: _Botao(texto: 'Marcar como lidos', onTap: notif.marcarTodasLidas)),
                    const SizedBox(width: 8),
                    Expanded(child: _Botao(texto: 'Limpar', onTap: notif.limpar)),
                  ],
                ),
                const SizedBox(height: 8),
                _Botao(texto: 'Voltar', onTap: () => Navigator.of(context).maybePop()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Botao extends StatelessWidget {
  const _Botao({required this.texto, required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 35,
      child: Material(
        color: Cores.azulBotao,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Center(
            child: Text(texto, style: textoMono(12, cor: Colors.white), overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

Color _cor(TipoNotificacao t) => switch (t) {
      TipoNotificacao.info => Cores.azulBotao,
      TipoNotificacao.livre => Cores.ativo,
      TipoNotificacao.aviso => const Color(0xFFF08A24),
      TipoNotificacao.critico => Cores.ocupada,
    };

IconData _icone(TipoNotificacao t) => switch (t) {
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Semantics(
        label: '${aviso.titulo}. ${aviso.mensagem}. ${quandoTexto(aviso.quando)}${aviso.lida ? '' : '. Não lido'}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.campo,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: aviso.lida ? Colors.transparent : _cor(aviso.tipo), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icone(aviso.tipo), color: _cor(aviso.tipo), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(aviso.titulo, style: textoMono(13, peso: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(aviso.mensagem, style: textoMono(11, peso: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(quandoTexto(aviso.quando), style: textoMono(10, peso: FontWeight.w500, cor: p.textoSuave)),
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

/// Chave "Só avisar quando eu estiver na faculdade".
class _InterruptorFaculdade extends StatelessWidget {
  const _InterruptorFaculdade({required this.notif});

  final NotificacoesController notif;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
      decoration: BoxDecoration(color: p.campo, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, color: Cores.ativo, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Só avisar quando eu estiver na faculdade', style: textoMono(12, peso: FontWeight.w700)),
          ),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              statusDosAvisos(carro: meuCarro, campus: campus, somenteNaFaculdade: notif.somenteNaFaculdade),
              style: textoMono(11, peso: FontWeight.w500, cor: p.textoSuave),
            ),
            if (precisaLocalizacao) ...[
              const SizedBox(height: 8),
              Material(
                color: Cores.azulBotao,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => campus.verificar(pedirPermissao: true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text('Ativar localização', style: textoMono(12, peso: FontWeight.w700, cor: Colors.white)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
