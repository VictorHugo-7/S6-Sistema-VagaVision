import 'package:flutter/material.dart';

import 'app_state.dart';
import 'carros_controller.dart';
import 'cena_login.dart';
import 'garagem_controller.dart';
import 'garagem_scene.dart';
import 'meu_carro.dart';
import 'ocupacao_ao_vivo.dart';
import 'tema_controller.dart';
import 'theme.dart';
import 'widgets.dart';

class MapaPage extends StatelessWidget {
  const MapaPage({
    super.key,
    required this.app,
    required this.garagem,
    required this.meuCarro,
    required this.carros,
    required this.tema,
    required this.mostrarSair,
    this.reservaInferior = 8,
  });

  final AppState app;
  final GaragemController garagem;
  final MeuCarro meuCarro;
  final CarrosController carros;
  final TemaController tema;
  final bool mostrarSair;

  final double reservaInferior;

  @override
  Widget build(BuildContext context) {
    final bloco = app.blocoPrincipal;
    final p = context.paleta;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: escuro ? p.superficie : p.lateral,
            border: Border.all(color: escuro ? p.moldura : Colors.white.withValues(alpha: 0.14)),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: ListenableBuilder(
              listenable: Listenable.merge([app, garagem, meuCarro, carros]),
              builder: (context, _) {
                final stats = garagem.stats;
                final alerta = app.nivelAtual(bloco, stats.livres);
                final cena = GaragemScene(controller: garagem, meuCarro: meuCarro, carros: carros);
                final estado = _FaixaEstado(
                  alerta: alerta,
                  livres: stats.livres,
                  garagem: garagem,
                  meuCarro: meuCarro,
                  carros: carros,
                );
                final controles = _Controles(garagem: garagem);
                final cartao = _CartaoVagas(bloco: bloco, stats: stats);

                return LayoutBuilder(builder: (context, c) {
                  final lateral = c.maxWidth > c.maxHeight * 1.2 && c.maxHeight < 560;
                  if (lateral) {
                    return Row(
                      children: [
                        SizedBox(
                          width: 236,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (mostrarSair) ...[
                                  Row(children: [
                                    BotaoTema(tema: tema),
                                    const SizedBox(width: 8),
                                    _BotaoSair(onTap: app.sair),
                                  ]),
                                  const SizedBox(height: 10),
                                ],
                                cartao,
                                const SizedBox(height: 10),
                                estado,
                                const SizedBox(height: 10),
                                _Controles(garagem: garagem, alinhamento: WrapAlignment.start),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                            child: ClipRRect(borderRadius: BorderRadius.circular(20), child: cena),
                          ),
                        ),
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
                            if (mostrarSair)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BotaoTema(tema: tema),
                                  const SizedBox(height: 8),
                                  _BotaoSair(onTap: app.sair),
                                ],
                              ),
                            if (c.maxWidth >= 640)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                                  child: _Cabecalho(bloco: bloco, garagem: garagem),
                                ),
                              )
                            else
                              const Spacer(),
                            cartao,
                          ],
                        ),
                      ),
                      Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0), child: estado),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: ClipRRect(borderRadius: BorderRadius.circular(20), child: cena),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(14, 10, 14, reservaInferior),
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

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.bloco, required this.garagem});

  final String bloco;
  final GaragemController garagem;

  @override
  Widget build(BuildContext context) {
    final vista = garagem.modo == Modo.d2 ? 'vista 2D' : 'vista 3D';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(bloco, style: mono(22, peso: FontWeight.w700, cor: Colors.white), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text('Nível ${garagem.nivel + 1} · $vista', style: mono(12, cor: CoresCena.textoSuave)),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Legenda(cor: CoresCena.livre, texto: 'Livre'),
            _Legenda(cor: CoresCena.ocupada, texto: 'Ocupada'),
            _Legenda(cor: Color(0xFFFFD93D), texto: 'Meu carro'),
          ],
        ),
      ],
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.cor, required this.texto});

  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(texto, style: mono(11, peso: FontWeight.w600, cor: CoresCena.texto)),
        ],
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
        color: context.paleta.superficie,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: alvoToque,
            height: alvoToque,
            child: Icon(Icons.logout_rounded, color: context.paleta.destaque, size: 22, semanticLabel: 'Sair'),
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
    final p = context.paleta;
    final fracao = stats.total == 0 ? 0.0 : stats.livres / stats.total;
    final cor = fracao > 0.5 ? CoresCena.livre : (fracao > 0.2 ? Cores.alertaSimples : CoresCena.ocupada);
    return Semantics(
      label: 'Vagas disponíveis no $bloco: ${stats.livres} de ${stats.total}',
      excludeSemantics: true,
      child: Container(
        width: 200,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: p.campo,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.local_parking_rounded, size: 16, color: p.destaque),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Vagas disponíveis',
                    style: mono(11, peso: FontWeight.w600, cor: p.textoSuave),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${stats.livres}', style: mono(28, peso: FontWeight.w700, cor: p.texto)),
                  TextSpan(text: ' / ${stats.total}', style: mono(14, peso: FontWeight.w600, cor: p.textoSuave)),
                ]),
              ),
            ),
            Text(bloco, style: mono(11, cor: p.textoSuave), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: p.textoSuave.withValues(alpha: 0.18))),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fracao,
                        heightFactor: 1,
                        child: ColoredBox(color: cor),
                      ),
                    ),
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

class _FaixaEstado extends StatelessWidget {
  const _FaixaEstado({
    required this.alerta,
    required this.livres,
    required this.garagem,
    required this.meuCarro,
    required this.carros,
  });

  final NivelAlerta? alerta;
  final int livres;
  final GaragemController garagem;
  final MeuCarro meuCarro;
  final CarrosController carros;

  void _estacionarAqui() {
    final v = garagem.selecionada;
    if (v == null) return;
    final antiga = meuCarro.estacionado ? garagem.buscarVaga(meuCarro.nivel!, meuCarro.codigo!) : null;
    if (antiga != null && antiga != v) garagem.liberarVaga(antiga);
    garagem.ocupar(v);
    meuCarro.marcar(garagem.nivel, v.code);
  }

  void _jaSai() {
    final v = meuCarro.estacionado ? garagem.buscarVaga(meuCarro.nivel!, meuCarro.codigo!) : null;
    if (v != null) garagem.liberarVaga(v);
    meuCarro.limpar();
  }

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
    final v = garagem.selecionada;
    if (v != null) {
      chips.add(_Chip(
        cor: context.paleta.superficie,
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
      final personalizado = v.ocupada ? carros.carroNaVaga(garagem.nivel, v.code) : null;
      if (personalizado != null) {
        chips.add(_Chip(
          cor: context.paleta.superficie,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car_rounded, size: 16, color: personalizado.carro.cor),
              const SizedBox(width: 6),
              Text(
                personalizado.meu ? personalizado.carro.nome : '${personalizado.carro.nome} · de ${personalizado.dono}',
                style: mono(12, peso: FontWeight.w700),
              ),
            ],
          ),
        ));
      }
      if (!meuCarro.eMinha(garagem.nivel, v.code)) {
        chips.add(_ChipBotao(
          cor: Cores.azulBotao,
          dica: 'Marcar a vaga ${v.code} como a do meu carro',
          onTap: _estacionarAqui,
          child: Text('Estacionei aqui', style: mono(12, peso: FontWeight.w700, cor: Colors.white)),
        ));
      }
    }
    if (meuCarro.estacionado) {
      chips.add(_ChipBotao(
        cor: const Color(0xFFFFD93D),
        dica: 'Mostrar onde estacionei no mapa',
        onTap: () => garagem.irParaVaga(meuCarro.nivel!, meuCarro.codigo!),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_rounded, size: 16, color: Cores.texto),
            const SizedBox(width: 6),
            Text('Meu carro: ${meuCarro.rotulo} · ${meuCarro.tempoTexto()}',
                style: mono(12, peso: FontWeight.w700, cor: Cores.texto)),
          ],
        ),
      ));
      chips.add(_ChipBotao(
        cor: context.paleta.superficie,
        dica: 'Já saí: liberar a vaga do meu carro',
        onTap: _jaSai,
        child: Text('Já saí', style: mono(12, peso: FontWeight.w700)),
      ));
    }

    return SizedBox(
      height: 36,
      child: chips.isEmpty
          ? Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Toque em uma vaga para ver os detalhes',
                      style: mono(11, cor: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
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

class _ChipBotao extends StatelessWidget {
  const _ChipBotao({required this.cor, required this.child, required this.onTap, required this.dica});

  final Color cor;
  final Widget child;
  final VoidCallback onTap;
  final String dica;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: dica,
      excludeSemantics: true,
      child: Material(
        color: cor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
            child: child,
          ),
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
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
        if (garagem.leituraAtual case final leitura?)
          SeloCamera(leitura: leitura, estilo: mono(12, peso: FontWeight.w700), fundo: context.paleta.superficie)
        else
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
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: escuro ? context.paleta.campo : context.paleta.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (escuro ? Colors.white : Colors.black).withValues(alpha: 0.08)),
      ),
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
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: i == selecionado
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color.lerp(Cores.azulBotao, Colors.white, 0.14)!, Cores.azulBotao],
                        )
                      : null,
                ),
                child: InkWell(
                onTap: () => onSel(i),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: alvoToque - 6, minWidth: 44),
                  child: Center(
                    widthFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        rotulos[i],
                        style: mono(12, peso: FontWeight.w700, cor: i == selecionado ? Colors.white : context.paleta.textoSuave),
                      ),
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
          child: Icon(icone, size: 20, color: context.paleta.destaque, semanticLabel: dica),
        ),
      ),
    );
  }
}
