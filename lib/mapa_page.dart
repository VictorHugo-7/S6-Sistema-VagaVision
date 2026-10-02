import 'package:flutter/material.dart';

import 'app_state.dart';
import 'garagem_controller.dart';
import 'garagem_scene.dart';
import 'theme.dart';

class MapaPage extends StatelessWidget {
  const MapaPage({
    super.key,
    required this.app,
    required this.garagem,
    required this.mostrarSair,
    this.reservaInferior = 8,
  });

  final AppState app;
  final GaragemController garagem;
  final bool mostrarSair;

  /// Folga abaixo dos controles (o círculo da navegação invade a moldura no celular).
  final double reservaInferior;

  @override
  Widget build(BuildContext context) {
    final bloco = app.blocoPrincipal;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(32),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(29),
            child: ListenableBuilder(
              listenable: Listenable.merge([app, garagem]),
              builder: (context, _) {
                final stats = garagem.stats;
                final alerta = app.nivelAtual(bloco, stats.livres);
                final cena = GaragemScene(controller: garagem);
                final estado = _FaixaEstado(alerta: alerta, livres: stats.livres, vaga: garagem.selecionada);
                final controles = _Controles(garagem: garagem);
                final cartao = _CartaoVagas(bloco: bloco, stats: stats);

                return LayoutBuilder(builder: (context, c) {
                  final lateral = c.maxWidth > c.maxHeight * 1.2 && c.maxHeight < 560;
                  if (lateral) {
                    // celular deitado: painel à esquerda, mapa ocupa toda a altura
                    return Row(
                      children: [
                        SizedBox(
                          width: 236,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (mostrarSair) ...[_BotaoSair(onTap: app.sair), const SizedBox(height: 10)],
                                cartao,
                                const SizedBox(height: 10),
                                estado,
                                const SizedBox(height: 10),
                                _Controles(garagem: garagem, alinhamento: WrapAlignment.start),
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: cena),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (mostrarSair) _BotaoSair(onTap: app.sair),
                            const Spacer(),
                            cartao,
                          ],
                        ),
                      ),
                      Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 0), child: estado),
                      Expanded(child: cena),
                      Padding(
                        padding: EdgeInsets.fromLTRB(14, 6, 14, reservaInferior),
                        child: controles,
                      ),
                    ],
                  );
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BotaoSair extends StatelessWidget {
  const _BotaoSair({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sair',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: const SizedBox(
            width: alvoToque,
            height: alvoToque,
            child: Icon(Icons.logout_rounded, color: Cores.azul, size: 22, semanticLabel: 'Sair'),
          ),
        ),
      ),
    );
  }
}

class _CartaoVagas extends StatelessWidget {
  const _CartaoVagas({required this.bloco, required this.stats});

  final String bloco;
  final Estatisticas stats;

  @override
  Widget build(BuildContext context) {
    final fracao = stats.total == 0 ? 0.0 : stats.livres / stats.total;
    return Semantics(
      label: 'Vagas disponíveis no $bloco: ${stats.livres} de ${stats.total}',
      excludeSemantics: true,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vagas Disponíveis\n$bloco', style: mono(14, peso: FontWeight.w700)),
            const SizedBox(height: 10),
            Container(
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Cores.texto),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fracao,
                        heightFactor: 1,
                        child: const ColoredBox(color: Cores.barra),
                      ),
                    ),
                    Text('${stats.livres}/${stats.total}', style: mono(13, peso: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faixa de altura fixa (o mapa não "pula"): alerta em vigor, vaga tocada ou uma dica.
class _FaixaEstado extends StatelessWidget {
  const _FaixaEstado({required this.alerta, required this.livres, required this.vaga});

  final NivelAlerta? alerta;
  final int livres;
  final Vaga? vaga;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (alerta != null) {
      final (cor, textoCor, rotulo) = switch (alerta!) {
        NivelAlerta.simples => (Cores.alertaSimples, Cores.texto, 'Alerta simples'),
        NivelAlerta.medio => (Cores.alertaMedio, Cores.texto, 'Alerta médio'),
        NivelAlerta.severo => (Cores.ocupada, Colors.white, 'Alerta severo'),
      };
      chips.add(_Chip(
        cor: cor,
        child: Text('$rotulo · ${livres == 1 ? '1 livre' : '$livres livres'}',
            style: mono(12, peso: FontWeight.w700, cor: textoCor)),
      ));
    }
    final v = vaga;
    if (v != null) {
      chips.add(_Chip(
        cor: Colors.white,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: v.ocupada ? Cores.ocupada : Cores.livre, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              v.ocupada ? '${v.code} · ocupada há ${v.minutosOcupada} min' : '${v.code} · livre',
              style: mono(12, peso: FontWeight.w600),
            ),
          ],
        ),
      ));
    }

    return SizedBox(
      height: 36,
      child: chips.isEmpty
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text('Toque em uma vaga para ver os detalhes', style: mono(11, cor: Colors.white70)),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Center(child: chips[i]),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.cor, required this.child});

  final Color cor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
      decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }
}

class _Controles extends StatelessWidget {
  const _Controles({required this.garagem, this.alinhamento = WrapAlignment.center});

  final GaragemController garagem;
  final WrapAlignment alinhamento;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alinhamento,
      spacing: 8,
      runSpacing: 8,
      children: [
        _Segmentos(
          rotulos: const ['2D', '3D'],
          selecionado: garagem.modo == Modo.d2 ? 0 : 1,
          onSel: (i) => garagem.setModo(i == 0 ? Modo.d2 : Modo.d3),
        ),
        _Segmentos(
          rotulos: const ['Nível 1', 'Nível 2'],
          selecionado: garagem.nivel,
          onSel: garagem.setNivel,
        ),
        _Pilula(children: [
          _IconeAcao(icone: Icons.shuffle_rounded, dica: 'Sortear ocupação', onTap: garagem.sortear),
          _IconeAcao(icone: Icons.cleaning_services_rounded, dica: 'Liberar todas as vagas', onTap: garagem.liberar),
        ]),
      ],
    );
  }
}

class _Pilula extends StatelessWidget {
  const _Pilula({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _Segmentos extends StatelessWidget {
  const _Segmentos({required this.rotulos, required this.selecionado, required this.onSel});

  final List<String> rotulos;
  final int selecionado;
  final ValueChanged<int> onSel;

  @override
  Widget build(BuildContext context) {
    return _Pilula(
      children: [
        for (var i = 0; i < rotulos.length; i++)
          Semantics(
            button: true,
            selected: i == selecionado,
            child: Material(
              color: i == selecionado ? Cores.azulBotao : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => onSel(i),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: alvoToque - 6, minWidth: 44),
                  child: Center(
                    widthFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        rotulos[i],
                        style: mono(12, peso: FontWeight.w700, cor: i == selecionado ? Colors.white : Cores.cinzaTexto),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _IconeAcao extends StatelessWidget {
  const _IconeAcao({required this.icone, required this.dica, required this.onTap});

  final IconData icone;
  final String dica;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: dica,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: SizedBox(
          width: alvoToque - 4,
          height: alvoToque - 6,
          child: Icon(icone, size: 20, color: Cores.azul, semanticLabel: dica),
        ),
      ),
    );
  }
}
