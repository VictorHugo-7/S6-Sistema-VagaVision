import 'package:flutter/material.dart';

import 'alertas_controller.dart';
import 'quadro_tela.dart';
import 'theme.dart';

/// Tela "Ativar alertas": uma linha por bloco, com interruptores, e botão Voltar.
class AlertasPagina extends StatelessWidget {
  const AlertasPagina({super.key, required this.controller});

  final AlertasController controller;

  @override
  Widget build(BuildContext context) {
    return QuadroTela(
      titulo: 'Alertas',
      icone: const _IconeAlerta(),
      preenchido: true,
      child: Column(
        children: [
          const SizedBox(height: 33),
          Text('Ativar alertas', style: textoMono(20)),
          const SizedBox(height: 24),
          Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(color: Cores.fundo, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 19),
          Expanded(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                itemCount: controller.itens.length,
                itemBuilder: (context, i) => _Linha(controller: controller, indice: i),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 35),
            child: SizedBox(
              width: double.infinity,
              height: 35,
              child: Material(
                color: Cores.azulBotao,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Center(
                    child: Text('Voltar', style: textoMono(13, cor: Colors.white)),
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

class _Linha extends StatelessWidget {
  const _Linha({required this.controller, required this.indice});

  final AlertasController controller;
  final int indice;

  @override
  Widget build(BuildContext context) {
    final item = controller.itens[indice];
    return SizedBox(
      height: 41,
      child: Row(
        children: [
          Expanded(
            child: Text(item.nome, style: textoMono(20), overflow: TextOverflow.ellipsis),
          ),
          _Interruptor(
            largura: 30,
            ativo: item.secundario,
            rotulo: 'Opção extra de ${item.nome}',
            onTap: () => controller.alternarSecundario(indice),
          ),
          const SizedBox(width: 13),
          _Interruptor(
            largura: 83,
            ativo: item.ativo,
            rotulo: 'Alerta de ${item.nome}',
            onTap: () => controller.alternarAlerta(indice),
          ),
        ],
      ),
    );
  }
}

class _Interruptor extends StatelessWidget {
  const _Interruptor({required this.largura, required this.ativo, required this.rotulo, required this.onTap});

  final double largura;
  final bool ativo;
  final String rotulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: ativo,
      label: rotulo,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: largura,
            height: 30,
            decoration: BoxDecoration(
              color: ativo ? Cores.ativo : Cores.cinza,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}

/// Exclamação branca do ícone redondo da tela Alertas.
class _IconeAlerta extends StatelessWidget {
  const _IconeAlerta();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 25,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
        ),
        const SizedBox(height: 4),
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ],
    );
  }
}
