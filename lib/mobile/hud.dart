import 'package:flutter/material.dart';

import '../meu_carro.dart';
import '../notificacoes.dart';
import '../tema_controller.dart';
import 'garagem_controller.dart';
import 'quadro_tela.dart';
import 'theme.dart';

/// Interface sobreposta à cena do Mapa: botão "Alertas" + sair e cartão "Vagas Disponíveis Bloco U"
/// no topo, seletores 3D/2D e Nível 1/2 logo abaixo, e os botões de ocupação embaixo.
class Hud extends StatelessWidget {
  const Hud({
    super.key,
    required this.controller,
    required this.tema,
    required this.notif,
    required this.meuCarro,
    required this.onAlertas,
    required this.onAvisos,
    required this.onPainel,
    this.onSair,
  });

  final GaragemController controller;
  final TemaController tema;
  final NotificacoesController notif;
  final MeuCarro meuCarro;
  final VoidCallback onAlertas;
  final VoidCallback onAvisos;
  final VoidCallback onPainel;
  final VoidCallback? onSair;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, meuCarro]),
      builder: (context, _) => Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PilulaAcoes(onAlertas: onAlertas, onSair: onSair),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topRight,
                          heightFactor: 1,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 202),
                            child: _CartaoVagas(controller: controller),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Segmentos(
                        opcoes: const ['3D', '2D'],
                        selecionado: controller.modo == Modo.d3 ? 0 : 1,
                        onSelecionar: (i) => controller.setModo(i == 0 ? Modo.d3 : Modo.d2),
                      ),
                      _Segmentos(
                        opcoes: const ['Nível 1', 'Nível 2'],
                        selecionado: controller.nivel,
                        onSelecionar: controller.setNivel,
                      ),
                      _PilulaIcones(tema: tema, notif: notif, onAvisos: onAvisos, onPainel: onPainel),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FaixaCarro(controller: controller, meuCarro: meuCarro),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _BotaoAcao(texto: 'Sortear ocupação', principal: true, onTap: controller.sortear),
                      _BotaoAcao(texto: 'Liberar todas as vagas', onTap: controller.liberar),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grupo de opções em pílula branca; a opção escolhida fica azul (mesmo azul do botão Alertas).
class _Segmentos extends StatelessWidget {
  const _Segmentos({required this.opcoes, required this.selecionado, required this.onSelecionar});

  final List<String> opcoes;
  final int selecionado;
  final ValueChanged<int> onSelecionar;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Material(
      color: p.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.borda, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < opcoes.length; i++)
              Material(
                color: i == selecionado ? Cores.azulBotao : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelecionar(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      opcoes[i],
                      style: textoMono(12, peso: FontWeight.w700, cor: i == selecionado ? Colors.white : p.texto),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Botão de ação: azul (principal) ou branco com contorno preto.
class _BotaoAcao extends StatelessWidget {
  const _BotaoAcao({required this.texto, required this.onTap, this.principal = false});

  final String texto;
  final VoidCallback onTap;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: principal ? BorderSide.none : BorderSide(color: p.borda, width: 1.5),
    );
    return Material(
      color: principal ? Cores.azulBotao : p.superficie,
      shape: forma,
      child: InkWell(
        customBorder: forma,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            texto,
            style: textoMono(12, peso: FontWeight.w700, cor: principal ? Colors.white : p.texto),
          ),
        ),
      ),
    );
  }
}

class _PilulaAcoes extends StatelessWidget {
  const _PilulaAcoes({required this.onAlertas, this.onSair});

  final VoidCallback onAlertas;
  final VoidCallback? onSair;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Material(
      color: p.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: p.borda, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Cores.azulBotao,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onAlertas,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text('Alertas', style: textoMono(12, peso: FontWeight.w700, cor: Colors.white)),
                ),
              ),
            ),
            if (onSair != null) ...[
              const SizedBox(width: 2),
              Tooltip(
                message: 'Sair',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSair,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _IconeSair(tamanho: 18, cor: p.destaque),
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

class _CartaoVagas extends StatelessWidget {
  const _CartaoVagas({required this.controller});

  final GaragemController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.stats;
        final fracao = s.total == 0 ? 0.0 : s.livres / s.total;
        final p = context.paleta;
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: p.superficie,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.borda, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('Vagas Disponíveis\nBloco U', style: textoMono(16, altura: 1.3)),
              ),
              const SizedBox(height: 8),
              _Barra(fracao: fracao, texto: '${s.livres}/${s.total}'),
            ],
          ),
        );
      },
    );
  }
}

/// Barra amarela: preenchida na proporção de vagas livres, com "livres/total" no meio.
class _Barra extends StatelessWidget {
  const _Barra({required this.fracao, required this.texto});

  final double fracao;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 29,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white, // trilho branco nos dois modos: o texto escuro fica legível sobre a barra amarela
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: context.paleta.borda, width: 1.2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fracao.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Cores.barra, borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Center(child: Text(texto, style: textoMono(14, cor: Cores.preto))),
        ],
      ),
    );
  }
}

/// Ícone de sair do Figma: caixa aberta com uma seta para a esquerda.
class _IconeSair extends StatelessWidget {
  const _IconeSair({required this.tamanho, required this.cor});

  final double tamanho;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(tamanho, tamanho), painter: _SairPainter(cor));
  }
}

class _SairPainter extends CustomPainter {
  _SairPainter(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 26);
    canvas.translate(0, 1);
    final traco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = cor;
    final caixa = Path()
      ..moveTo(21, 9)
      ..lineTo(21, 5)
      ..quadraticBezierTo(21, 3, 19, 3)
      ..lineTo(5, 3)
      ..quadraticBezierTo(3, 3, 3, 5)
      ..lineTo(3, 19)
      ..quadraticBezierTo(3, 21, 5, 21)
      ..lineTo(19, 21)
      ..quadraticBezierTo(21, 21, 21, 19)
      ..lineTo(21, 15);
    final seta = Path()
      ..moveTo(25, 12)
      ..lineTo(9, 12)
      ..moveTo(13, 8)
      ..lineTo(9, 12)
      ..lineTo(13, 16);
    canvas.drawPath(caixa, traco);
    canvas.drawPath(seta, traco);
  }

  @override
  bool shouldRepaint(covariant _SairPainter old) => old.cor != cor;
}

/// Sino de avisos (com a quantidade de não lidos) e botão de modo escuro, numa pílula só.
class _PilulaIcones extends StatelessWidget {
  const _PilulaIcones({required this.tema, required this.notif, required this.onAvisos, required this.onPainel});

  final TemaController tema;
  final NotificacoesController notif;
  final VoidCallback onAvisos;
  final VoidCallback onPainel;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final brilho = Theme.of(context).brightness;
    final escuro = brilho == Brightness.dark;
    return Material(
      color: p.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.borda, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Painel e previsão',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPainel,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.insert_chart_rounded, size: 20, color: p.destaque, semanticLabel: 'Painel e previsão'),
                ),
              ),
            ),
            Tooltip(
              message: 'Avisos',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAvisos,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ListenableBuilder(
                    listenable: notif,
                    builder: (context, _) {
                      final n = notif.naoLidas;
                      final icone = Icon(Icons.notifications_rounded, size: 20, color: p.destaque, semanticLabel: 'Avisos');
                      if (n == 0) return icone;
                      return Badge(
                        label: Text(n > 9 ? '9+' : '$n', style: textoMono(10, cor: Colors.white)),
                        backgroundColor: Cores.ocupada,
                        child: icone,
                      );
                    },
                  ),
                ),
              ),
            ),
            Tooltip(
              message: escuro ? 'Modo claro' : 'Modo escuro',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => tema.alternar(brilho),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    escuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 20,
                    color: p.destaque,
                    semanticLabel: escuro ? 'Modo claro' : 'Modo escuro',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Onde estacionei?": botão para marcar a vaga tocada como a do carro e cartão com a vaga marcada.
class _FaixaCarro extends StatelessWidget {
  const _FaixaCarro({required this.controller, required this.meuCarro});

  final GaragemController controller;
  final MeuCarro meuCarro;

  void _estacionarAqui() {
    final v = controller.selecionada;
    if (v == null) return;
    final antiga = meuCarro.estacionado ? controller.buscarVaga(meuCarro.nivel!, meuCarro.codigo!) : null;
    if (antiga != null && antiga != v) controller.liberarVaga(antiga);
    controller.ocupar(v);
    meuCarro.marcar(controller.nivel, v.code);
  }

  void _jaSai() {
    final v = meuCarro.estacionado ? controller.buscarVaga(meuCarro.nivel!, meuCarro.codigo!) : null;
    if (v != null) controller.liberarVaga(v); // ainda "estacionado": a própria saída não gera aviso
    meuCarro.limpar();
  }

  @override
  Widget build(BuildContext context) {
    final v = controller.selecionada;
    final itens = <Widget>[];
    if (v != null && !meuCarro.eMinha(controller.nivel, v.code)) {
      itens.add(_BotaoAcao(texto: 'Estacionei na vaga ${v.code}', principal: true, onTap: _estacionarAqui));
    }
    if (meuCarro.estacionado) {
      itens.add(
        Semantics(
          button: true,
          label: 'Mostrar onde estacionei no mapa',
          excludeSemantics: true,
          child: Material(
            color: const Color(0xFFFFD93D),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => controller.irParaVaga(meuCarro.nivel!, meuCarro.codigo!),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car_rounded, size: 16, color: Color(0xFF111111)),
                    const SizedBox(width: 6),
                    Text(
                      'Meu carro: ${meuCarro.rotulo} · ${meuCarro.tempoTexto()}',
                      style: textoMono(11, peso: FontWeight.w700, cor: const Color(0xFF111111)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      itens.add(_BotaoAcao(texto: 'Já saí', onTap: _jaSai));
    }
    if (itens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('Toque em uma vaga e marque "Estacionei"', style: textoMono(10, peso: FontWeight.w500, cor: Colors.white70)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: itens),
    );
  }
}
