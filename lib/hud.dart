import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'garagem_controller.dart';
import 'theme.dart';

TextStyle _oswald(double size, {FontWeight peso = FontWeight.w500, Color cor = Cores.texto}) =>
    GoogleFonts.oswald(fontSize: size, fontWeight: peso, color: cor);

TextStyle _inter(double size, {FontWeight peso = FontWeight.w400, Color cor = Cores.textoFraco, double? altura}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: peso, color: cor, height: altura);

BoxDecoration _caixaPainel(double raio) => BoxDecoration(
      color: Cores.painel,
      borderRadius: BorderRadius.circular(raio),
      border: Border.all(color: Cores.borda),
    );

class Hud extends StatelessWidget {
  const Hud({super.key, required this.controller});

  final GaragemController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final stats = controller.stats;
        final vaga = controller.selecionada;
        return SafeArea(
          child: Stack(
            children: [
              Positioned(top: 12, left: 18, right: 18, child: _topbar()),
              Positioned(left: 18, top: 112, child: _painelStatus(stats)),
              Positioned(left: 18, bottom: 24, child: _legenda()),
              if (vaga != null) Positioned(right: 18, bottom: 24, child: _painelVaga(vaga)),
            ],
          ),
        );
      },
    );
  }

  Widget _topbar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(
                style: _oswald(18, peso: FontWeight.w700),
                children: [
                  const TextSpan(text: 'GARAGEM '),
                  TextSpan(text: 'CENTRAL', style: _oswald(18, peso: FontWeight.w700, cor: Cores.amarelo)),
                ],
              )),
              const SizedBox(height: 3),
              Text('Monitoramento de vagas · simulação em tempo real', style: _inter(10.5, altura: 14 / 10.5)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _GrupoBotoes(children: [
              _BotaoToggle(ativo: controller.modo == Modo.d3, texto: '3D', onTap: () => controller.setModo(Modo.d3)),
              _BotaoToggle(ativo: controller.modo == Modo.d2, texto: '2D', onTap: () => controller.setModo(Modo.d2)),
            ]),
            const SizedBox(height: 8),
            _GrupoBotoes(children: [
              _BotaoToggle(ativo: controller.nivel == 0, texto: 'Nível 1', onTap: () => controller.setNivel(0)),
              _BotaoToggle(ativo: controller.nivel == 1, texto: 'Nível 2', onTap: () => controller.setNivel(1)),
            ]),
          ],
        ),
      ],
    );
  }

  Widget _painelStatus(Estatisticas s) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: _caixaPainel(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _numero('${s.livres}', 'vagas livres', Cores.livre)),
              const SizedBox(width: 10),
              Expanded(child: _numero('${s.ocupadas}', 'ocupadas', Cores.ocupada)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Container(
              height: 8,
              color: Cores.livreDim,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: s.pctOcupado / 100,
                child: Container(color: Cores.ocupada),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${s.pctOcupado}% ocupado', style: _inter(10.5)),
              Text('${s.total} vagas', style: _inter(10.5)),
            ],
          ),
          const SizedBox(height: 6),
          _Botao(texto: 'Sortear ocupação', principal: true, onTap: controller.sortear),
          _Botao(texto: 'Liberar todas as vagas', onTap: controller.liberar),
        ],
      ),
    );
  }

  Widget _numero(String valor, String rotulo, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(valor, style: _oswald(26, peso: FontWeight.w600, cor: cor)),
        const SizedBox(height: 2),
        Text(rotulo, style: _inter(10.5)),
      ],
    );
  }

  Widget _legenda() {
    Widget item(Color cor, String texto) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 6),
            Text(texto, style: _inter(10.5)),
          ],
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
      decoration: _caixaPainel(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [item(Cores.livre, 'Livre'), const SizedBox(width: 14), item(Cores.ocupada, 'Ocupada')],
      ),
    );
  }

  Widget _painelVaga(Vaga v) {
    final cor = v.ocupada ? Cores.ocupada : Cores.livre;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(15),
      decoration: _caixaPainel(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(v.code, style: _oswald(20, peso: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 9),
            decoration: BoxDecoration(color: cor.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
            child: Text(v.ocupada ? 'Ocupada' : 'Livre', style: _inter(11.5, peso: FontWeight.w600, cor: cor)),
          ),
          const SizedBox(height: 8),
          Text(
            v.ocupada ? 'Veículo estacionado há ${v.minutosOcupada} min.' : 'Vaga disponível para uso imediato.',
            style: _inter(11.5, altura: 16 / 11.5),
          ),
        ],
      ),
    );
  }
}

class _GrupoBotoes extends StatelessWidget {
  const _GrupoBotoes({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: _caixaPainel(10),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _BotaoToggle extends StatelessWidget {
  const _BotaoToggle({required this.ativo, required this.texto, required this.onTap});

  final bool ativo;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ativo ? Cores.amarelo : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 13),
          child: Text(texto, style: _oswald(12.5, cor: ativo ? Cores.textoSobreAmarelo : Cores.textoFraco)),
        ),
      ),
    );
  }
}

class _Botao extends StatelessWidget {
  const _Botao({required this.texto, required this.onTap, this.principal = false});

  final String texto;
  final VoidCallback onTap;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: principal ? Cores.amarelo : const Color.fromRGBO(255, 255, 255, 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: principal ? BorderSide.none : const BorderSide(color: Cores.borda),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Text(
              texto,
              style: _inter(12, peso: FontWeight.w600, cor: principal ? Cores.textoSobreAmarelo : Cores.texto),
            ),
          ),
        ),
      ),
    );
  }
}
