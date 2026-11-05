import 'package:flutter/material.dart';

import 'alertas_page.dart';
import 'app_state.dart';
import 'avisos_page.dart';
import 'carros_controller.dart';
import 'cena_login.dart';
import 'garagem_controller.dart';
import 'garagem_custom_page.dart';
import 'logo.dart';
import 'historico.dart';
import 'localizacao.dart';
import 'mapa_page.dart';
import 'meu_carro.dart';
import 'painel_page.dart';
import 'notificacoes.dart';
import 'tema_controller.dart';
import 'theme.dart';
import 'widgets.dart';

const _itens = [
  (Icons.location_on, 'Mapa'),
  (Icons.priority_high_rounded, 'Alertas'),
  (Icons.notifications_rounded, 'Avisos'),
  (Icons.insert_chart_rounded, 'Painel'),
  (Icons.directions_car_rounded, 'Garagem'),
];

const _abaAvisos = 2;
const _abaPainel = 3;
const _abaGaragem = 4;

class _IconeAba extends StatelessWidget {
  const _IconeAba({required this.indice, required this.notif, required this.cor, required this.tamanho});

  final int indice;
  final NotificacoesController notif;
  final Color cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final icone = Icon(_itens[indice].$1, size: tamanho, color: cor);
    if (indice != _abaAvisos) return icone;
    return ListenableBuilder(
      listenable: notif,
      builder: (context, _) {
        final n = notif.naoLidas;
        if (n == 0) return icone;
        return Badge(
          label: Text(n > 9 ? '9+' : '$n', style: mono(10, peso: FontWeight.w700, cor: Colors.white)),
          backgroundColor: Cores.ocupada,
          child: icone,
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.app,
    required this.garagem,
    required this.tema,
    required this.notif,
    required this.meuCarro,
    required this.historico,
    required this.campus,
    required this.carros,
  });

  final AppState app;
  final GaragemController garagem;
  final TemaController tema;
  final NotificacoesController notif;
  final MeuCarro meuCarro;
  final HistoricoOcupacao historico;
  final LocalizacaoCampus campus;
  final CarrosController carros;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _aba = 0;
  String? _blocoEditando;

  void _trocarAba(int i) {
    if (i == _abaAvisos) widget.campus.verificar();
    setState(() {
      _aba = i;
      _blocoEditando = null;
    });
  }

  Widget _conteudo({required bool navegacaoLateral, double reservaInferior = 8}) {
    if (_aba == 0) {
      return MapaPage(
        app: widget.app,
        garagem: widget.garagem,
        meuCarro: widget.meuCarro,
        carros: widget.carros,
        tema: widget.tema,
        mostrarSair: !navegacaoLateral,
        reservaInferior: reservaInferior,
      );
    }
    if (_aba == _abaAvisos) return AvisosPage(
        notif: widget.notif,
        campus: widget.campus,
        meuCarro: widget.meuCarro,
        onVoltar: () => _trocarAba(0),
      );
    if (_aba == _abaGaragem) return GaragemCustomPage(carros: widget.carros);
    if (_aba == _abaPainel) {
      return PainelPage(historico: widget.historico, garagem: widget.garagem, onVoltar: () => _trocarAba(0));
    }
    final bloco = _blocoEditando;
    if (bloco != null) {
      return AlertaBlocoPage(
        key: ValueKey(bloco),
        app: widget.app,
        bloco: bloco,
        onVoltar: () => setState(() => _blocoEditando = null),
      );
    }
    return AlertasListaPage(
      app: widget.app,
      onEditar: (b) => setState(() => _blocoEditando = b),
      onVoltar: () => _trocarAba(0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final largo = c.maxWidth >= 900;
      final paisagemCompacta = !largo && c.maxWidth > c.maxHeight && c.maxHeight < 520;

      if (largo || paisagemCompacta) {
        return Scaffold(
          backgroundColor: context.paleta.fundo,
          body: Row(
            children: [
              if (largo)
                _MenuLateral(app: widget.app, tema: widget.tema, notif: widget.notif, aba: _aba, onAba: _trocarAba)
              else
                _Trilho(tema: widget.tema, notif: widget.notif, aba: _aba, onAba: _trocarAba, onSair: widget.app.sair),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Theme.of(context).brightness == Brightness.dark ? const FundoCena() : const SizedBox.shrink(),
                    SafeArea(child: _conteudo(navegacaoLateral: true)),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      final inset = MediaQuery.paddingOf(context).bottom;
      final altura = 78 + inset;
      return Scaffold(
        backgroundColor: context.paleta.fundo,
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SafeArea(
                    bottom: false,
                    child: _conteudo(navegacaoLateral: false, reservaInferior: 26),
                  ),
                ),
                _BarraInferior(altura: altura, aba: _aba, notif: widget.notif, onAba: _trocarAba),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: altura - 31,
              height: 62,
              child: Row(
                children: [
                  for (var i = 0; i < _itens.length; i++)
                    Expanded(
                      child: i == _aba
                          ? Center(
                              child: Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  color: context.paleta.fundo,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: context.paleta.fundo, width: 6),
                                ),
                                child: Icon(_itens[i].$1, color: Colors.white, size: 32),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({required this.altura, required this.aba, required this.notif, required this.onAba});

  final double altura;
  final int aba;
  final NotificacoesController notif;
  final ValueChanged<int> onAba;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: altura,
      color: context.paleta.superficie,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          for (var i = 0; i < _itens.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == aba,
                label: _itens[i].$2,
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onAba(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (i != aba) _IconeAba(indice: i, notif: notif, cor: context.paleta.textoSuave, tamanho: 26),
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 12, left: 2, right: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _itens[i].$2,
                            maxLines: 1,
                            style: mono(i == aba ? 17 : 12,
                                peso: i == aba ? FontWeight.w700 : FontWeight.w500,
                                cor: i == aba ? context.paleta.texto : context.paleta.textoSuave),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.indice,
    required this.selecionado,
    required this.notif,
    required this.onTap,
    this.compacto = false,
  });

  final int indice;
  final bool selecionado;
  final NotificacoesController notif;
  final VoidCallback onTap;

  final bool compacto;

  static const _corSelecionada = Color(0xFF8FB4FF);

  @override
  Widget build(BuildContext context) {
    final corIcone = selecionado ? _corSelecionada : Colors.white60;
    final corTexto = selecionado ? Colors.white : Colors.white70;
    final rotulo = _itens[indice].$2;
    final Widget conteudo;
    if (compacto) {
      conteudo = SizedBox(
        height: 62,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconeAba(indice: indice, notif: notif, tamanho: 24, cor: corIcone),
            const SizedBox(height: 2),
            Text(rotulo, style: mono(11, peso: FontWeight.w700, cor: corTexto)),
          ],
        ),
      );
    } else {
      conteudo = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: selecionado ? _corSelecionada : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            _IconeAba(indice: indice, notif: notif, tamanho: 22, cor: corIcone),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                rotulo,
                style: mono(14, peso: selecionado ? FontWeight.w700 : FontWeight.w600, cor: corTexto),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      selected: selecionado,
      label: compacto ? rotulo : null,
      excludeSemantics: compacto,
      child: Material(
        color: selecionado ? Cores.azulBotao.withValues(alpha: 0.24) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: conteudo,
        ),
      ),
    );
  }
}

BoxDecoration _fundoMenu(BuildContext context) => BoxDecoration(
      color: context.paleta.lateral,
      border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
    );

class _Trilho extends StatelessWidget {
  const _Trilho({required this.tema, required this.notif, required this.aba, required this.onAba, required this.onSair});

  final TemaController tema;
  final NotificacoesController notif;
  final int aba;
  final ValueChanged<int> onAba;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      decoration: _fundoMenu(context),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < _itens.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                        child: _ItemMenu(
                          indice: i,
                          selecionado: i == aba,
                          notif: notif,
                          compacto: true,
                          onTap: () => onAba(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            BotaoTema(tema: tema, sobreFundoEscuro: true),
            Tooltip(
              message: 'Sair',
              child: IconButton(
                onPressed: onSair,
                iconSize: 24,
                constraints: const BoxConstraints(minWidth: alvoToque, minHeight: alvoToque),
                icon: const Icon(Icons.logout_rounded, color: Colors.white70, semanticLabel: 'Sair'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MenuLateral extends StatelessWidget {
  const _MenuLateral({required this.app, required this.tema, required this.notif, required this.aba, required this.onAba});

  final AppState app;
  final TemaController tema;
  final NotificacoesController notif;
  final int aba;
  final ValueChanged<int> onAba;

  @override
  Widget build(BuildContext context) {
    final nome = (app.usuario ?? '').trim();
    final inicial = nome.isEmpty ? '?' : nome.substring(0, 1).toUpperCase();
    return Container(
      width: 248,
      decoration: _fundoMenu(context),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    LogoVaga(largura: 36, fundo: context.paleta.lateral),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'VagaVision',
                        style: mono(18, peso: FontWeight.w700, cor: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 10),
                child: Text('MENU', style: mono(10, peso: FontWeight.w700, cor: Colors.white38)),
              ),
              for (var i = 0; i < _itens.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _ItemMenu(indice: i, selecionado: i == aba, notif: notif, onTap: () => onAba(i)),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF3B82F6), Cores.azulBotao],
                            ),
                          ),
                          child: Text(inicial, style: mono(15, peso: FontWeight.w700, cor: Colors.white)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nome.isEmpty ? 'Visitante' : nome,
                                style: mono(13, peso: FontWeight.w700, cor: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text('Conectado', style: mono(10, cor: Colors.white54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        BotaoTema(tema: tema, sobreFundoEscuro: true),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: app.sair,
                              child: SizedBox(
                                height: alvoToque,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text('Sair', style: mono(14, peso: FontWeight.w700, cor: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
