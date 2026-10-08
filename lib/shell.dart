import 'package:flutter/material.dart';

import 'alertas_page.dart';
import 'app_state.dart';
import 'garagem_controller.dart';
import 'logo.dart';
import 'mapa_page.dart';
import 'theme.dart';

const _itens = [
  (Icons.location_on, 'Mapa'),
  (Icons.priority_high_rounded, 'Alertas'),
];

/// Estrutura do app logado. A navegação se adapta ao espaço:
/// celular em pé → barra inferior; celular deitado → trilho compacto; web/tablet → menu lateral.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.app, required this.garagem});

  final AppState app;
  final GaragemController garagem;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _aba = 0; // 0 = Mapa, 1 = Alertas
  String? _blocoEditando;

  void _trocarAba(int i) => setState(() {
        _aba = i;
        _blocoEditando = null;
      });

  Widget _conteudo({required bool navegacaoLateral, double reservaInferior = 8}) {
    if (_aba == 0) {
      return MapaPage(
        app: widget.app,
        garagem: widget.garagem,
        mostrarSair: !navegacaoLateral,
        reservaInferior: reservaInferior,
      );
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
          backgroundColor: Cores.azul,
          body: Row(
            children: [
              if (largo)
                _MenuLateral(app: widget.app, aba: _aba, onAba: _trocarAba)
              else
                _Trilho(aba: _aba, onAba: _trocarAba, onSair: widget.app.sair),
              Expanded(child: SafeArea(child: _conteudo(navegacaoLateral: true))),
            ],
          ),
        );
      }

      final inset = MediaQuery.paddingOf(context).bottom;
      final altura = 78 + inset;
      return Scaffold(
        backgroundColor: Cores.azul,
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
                _BarraInferior(altura: altura, aba: _aba, onAba: _trocarAba),
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
                                  color: Cores.azul,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Cores.azul, width: 6),
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
  const _BarraInferior({required this.altura, required this.aba, required this.onAba});

  final double altura;
  final int aba;
  final ValueChanged<int> onAba;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: altura,
      color: Colors.white,
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
                      if (i != aba) Icon(_itens[i].$1, color: Cores.cinzaTexto, size: 26),
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 12),
                        child: Text(
                          _itens[i].$2,
                          style: mono(i == aba ? 17 : 12,
                              peso: i == aba ? FontWeight.w700 : FontWeight.w500,
                              cor: i == aba ? Cores.texto : Cores.cinzaTexto),
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
  const _Trilho({required this.aba, required this.onAba, required this.onSair});

  final int aba;
  final ValueChanged<int> onAba;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      color: Cores.azulLateral,
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
                            Icon(_itens[i].$1, size: 24, color: i == aba ? Cores.azul : Colors.white70),
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
  const _MenuLateral({required this.app, required this.aba, required this.onAba});

  final AppState app;
  final int aba;
  final ValueChanged<int> onAba;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: Cores.azulLateral,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LogoVaga(largura: 40, fundo: Cores.azulLateral),
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
                              Icon(_itens[i].$1, size: 22, color: i == aba ? Cores.azul : Colors.white70),
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
