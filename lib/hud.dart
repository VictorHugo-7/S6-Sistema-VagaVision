import 'package:flutter/material.dart';

import 'garagem_controller.dart';
import 'quadro_tela.dart';
import 'theme.dart';

/// Interface sobreposta à cena do Mapa: botão "Alertas" + sair e cartão "Vagas Disponíveis Bloco U"
/// no topo, seletores 3D/2D e Nível 1/2 logo abaixo, e os botões de ocupação embaixo.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.controller, required this.onAlertas, this.onSair});

  final GaragemController controller;
  final VoidCallback onAlertas;
  final VoidCallback? onSair;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
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
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BotaoAcao(texto: 'Sortear ocupação', principal: true, onTap: controller.sortear),
                  _BotaoAcao(texto: 'Liberar todas as vagas', onTap: controller.liberar),
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
    return Material(
      color: Cores.branco,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Cores.preto, width: 1.5),
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
                      style: textoMono(12, peso: FontWeight.w700, cor: i == selecionado ? Colors.white : Cores.preto),
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
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: principal ? BorderSide.none : const BorderSide(color: Cores.preto, width: 1.5),
    );
    return Material(
      color: principal ? Cores.azulBotao : Cores.branco,
      shape: forma,
      child: InkWell(
        customBorder: forma,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            texto,
            style: textoMono(12, peso: FontWeight.w700, cor: principal ? Colors.white : Cores.preto),
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
    return Material(
      color: Cores.branco,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Cores.preto, width: 1.5),
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
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: _IconeSair(tamanho: 18),
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
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: Cores.branco,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Cores.preto, width: 1.5),
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
        color: Cores.branco,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Cores.preto, width: 1.2),
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
          Center(child: Text(texto, style: textoMono(14))),
        ],
      ),
    );
  }
}

/// Ícone de sair do Figma: caixa aberta com uma seta para a esquerda.
class _IconeSair extends StatelessWidget {
  const _IconeSair({required this.tamanho});

  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(tamanho, tamanho), painter: _SairPainter());
  }
}

class _SairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 26);
    canvas.translate(0, 1);
    final traco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Cores.fundo;
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
  bool shouldRepaint(covariant CustomPainter old) => false;
}
