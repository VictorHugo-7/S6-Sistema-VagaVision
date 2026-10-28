import 'package:flutter/material.dart';

import 'alertas_page.dart';
import 'app_state.dart';
import 'avisos_page.dart';
import 'garagem_controller.dart';
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
];

const _abaAvisos = 2;
const _abaPainel = 3;

/// Ícone da aba; na aba "Avisos" mostra a bolinha vermelha com a quantidade de não lidas.
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

/// Estrutura do app logado. A navegação se adapta ao espaço:
/// celular em pé → barra inferior; celular deitado → trilho compacto; web/tablet → menu lateral.
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
  });

  final AppState app;
  final GaragemController garagem;
  final TemaController tema;
  final NotificacoesController notif;
  final MeuCarro meuCarro;
  final HistoricoOcupacao historico;
  final LocalizacaoCampus campus;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _aba = 0; // 0 = Mapa, 1 = Alertas, 2 = Avisos, 3 = Painel
  String? _blocoEditando;

  void _trocarAba(int i) {
    if (i == _abaAvisos) widget.campus.verificar(); // atualiza a localização ao abrir os avisos
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
              Expanded(child: SafeArea(child: _conteudo(navegacaoLateral: true))),
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
            // círculo do item atual: fica numa camada própria para ser tocável por inteiro
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
                        padding: const EdgeInsets.only(top: 2, bottom: 12),
                        child: Text(
                          _itens[i].$2,
                          style: mono(i == aba ? 17 : 12,
                              peso: i == aba ? FontWeight.w700 : FontWeight.w500,
                              cor: i == aba ? context.paleta.texto : context.paleta.textoSuave),
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

/// Navegação compacta (só ícones) para celular deitado, onde a altura é escassa.
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
      color: context.paleta.lateral,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            for (var i = 0; i < _itens.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Semantics(
                  button: true,
                  selected: i == aba,
                  label: _itens[i].$2,
                  excludeSemantics: true,
                  child: Material(
                    color: i == aba ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onAba(i),
                      child: SizedBox(
                        height: 62,
                        width: double.infinity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _IconeAba(indice: i, notif: notif, tamanho: 24, cor: i == aba ? Cores.azul : Colors.white70),
                            const SizedBox(height: 2),
                            Text(
                              _itens[i].$2,
                              style: mono(11, peso: FontWeight.w700, cor: i == aba ? Cores.azul : Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            BotaoTema(tema: tema, sobreFundoEscuro: true),
            Tooltip(
              message: 'Sair',
              child: IconButton(
                onPressed: onSair,
                iconSize: 24,
                constraints: const BoxConstraints(minWidth: alvoToque, minHeight: alvoToque),
                icon: const Icon(Icons.logout_rounded, color: Colors.white, semanticLabel: 'Sair'),
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
    return Container(
      width: 240,
      color: context.paleta.lateral,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LogoVaga(largura: 40, fundo: context.paleta.lateral),
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
              const SizedBox(height: 32),
              for (var i = 0; i < _itens.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    button: true,
                    selected: i == aba,
                    child: Material(
                      color: i == aba ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onAba(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                          child: Row(
                            children: [
                              _IconeAba(indice: i, notif: notif, tamanho: 22, cor: i == aba ? Cores.azul : Colors.white70),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _itens[i].$2,
                                  style: mono(15, peso: FontWeight.w700, cor: i == aba ? Cores.azul : Colors.white70),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              Align(alignment: Alignment.centerLeft, child: BotaoTema(tema: tema, sobreFundoEscuro: true)),
              const SizedBox(height: 4),
              Text(app.usuario ?? '', style: mono(12, cor: Colors.white70), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: app.sair,
                style: TextButton.styleFrom(minimumSize: const Size(alvoToque, alvoToque)),
                icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
                label: Text('Sair', style: mono(14, peso: FontWeight.w700, cor: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
