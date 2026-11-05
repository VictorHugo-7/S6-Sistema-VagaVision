import 'package:flutter/material.dart';

import 'app_state.dart';
import 'cena_login.dart';
import 'theme.dart';
import 'widgets.dart';

class AlertasListaPage extends StatelessWidget {
  const AlertasListaPage({super.key, required this.app, required this.onEditar, required this.onVoltar});

  final AppState app;
  final ValueChanged<String> onEditar;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    return PaginaFolha(
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) => FolhaBranca(
          titulo: 'Ativar alertas',
          subtitulo: 'Escolha os blocos que podem te avisar quando as vagas estiverem acabando.',
          icone: Icons.notifications_active_rounded,
          rodape: BotaoContorno(texto: 'Voltar', altura: 48, icone: Icons.arrow_back_rounded, onTap: onVoltar),
          filhos: [
            for (final entrada in app.blocos.entries)
              _LinhaBloco(
                nome: entrada.key,
                ativo: entrada.value.ativo,
                onEditar: () => onEditar(entrada.key),
                onAlternar: () => app.alternarAlerta(entrada.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinhaBloco extends StatelessWidget {
  const _LinhaBloco({required this.nome, required this.ativo, required this.onEditar, required this.onAlternar});

  final String nome;
  final bool ativo;
  final VoidCallback onEditar, onAlternar;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.campo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (escuro ? Colors.white : Colors.black).withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          IconeBolha(icone: Icons.local_parking_rounded, cor: ativo ? CoresCena.livre : p.textoSuave),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: mono(16, peso: FontWeight.w700), overflow: TextOverflow.ellipsis),
                Text(
                  ativo ? 'Alertas ligados' : 'Alertas desligados',
                  style: mono(11, cor: p.textoSuave),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Configurar alertas do $nome',
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: p.textoSuave.withValues(alpha: 0.35)),
              ),
              child: InkWell(
                onTap: onEditar,
                child: SizedBox(
                  width: alvoToque,
                  height: alvoToque,
                  child: Icon(Icons.tune_rounded, size: 20, color: p.texto, semanticLabel: 'Configurar'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            toggled: ativo,
            label: 'Alertas do $nome',
            child: Material(
              color: ativo ? Cores.ativo : p.textoSuave.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: onAlternar,
                child: SizedBox(
                  width: 92,
                  height: alvoToque,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: ativo ? Colors.white : p.textoSuave,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ativo ? 'Ativo' : 'Inativo',
                        style: mono(12, peso: FontWeight.w700, cor: ativo ? Colors.white : p.texto),
                      ),
                    ],
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

class AlertaBlocoPage extends StatefulWidget {
  const AlertaBlocoPage({super.key, required this.app, required this.bloco, required this.onVoltar});

  final AppState app;
  final String bloco;
  final VoidCallback onVoltar;

  @override
  State<AlertaBlocoPage> createState() => _AlertaBlocoPageState();
}

class _AlertaBlocoPageState extends State<AlertaBlocoPage> {
  late final Map<NivelAlerta, TextEditingController> _campos = {
    for (final n in NivelAlerta.values)
      n: TextEditingController(text: widget.app.blocos[widget.bloco]!.limite(n)?.toString() ?? ''),
  };

  static const _rotulos = {
    NivelAlerta.simples: 'Alerta Simples',
    NivelAlerta.medio: 'Alerta Médio',
    NivelAlerta.severo: 'Alerta Severo',
  };

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _salvar(NivelAlerta nivel) {
    final texto = _campos[nivel]!.text.trim();
    final valor = int.tryParse(texto);
    if (texto.isNotEmpty && (valor == null || valor < 0)) {
      _aviso('Digite apenas números inteiros.');
      return;
    }
    widget.app.salvarLimite(widget.bloco, nivel, valor);
    _aviso(valor == null ? '${_rotulos[nivel]} removido.' : '${_rotulos[nivel]} salvo.');
  }

  void _aviso(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: mono(13)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  static const _descricoes = {
    NivelAlerta.simples: 'Primeiro aviso: as vagas começam a acabar.',
    NivelAlerta.medio: 'O bloco está quase cheio.',
    NivelAlerta.severo: 'Última chance: restam pouquíssimas vagas.',
  };

  static const _cores = {
    NivelAlerta.simples: Cores.alertaSimples,
    NivelAlerta.medio: Cores.alertaMedio,
    NivelAlerta.severo: Cores.ocupada,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final borda = (escuro ? Colors.white : Colors.black).withValues(alpha: 0.08);
    return PaginaFolha(
      child: FolhaBranca(
        titulo: widget.bloco,
        subtitulo: 'Limites dos alertas deste bloco',
        icone: Icons.notifications_active_rounded,
        rodape: BotaoContorno(texto: 'Voltar', altura: 48, icone: Icons.arrow_back_rounded, onTap: widget.onVoltar),
        filhos: [
          for (final n in NivelAlerta.values)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borda),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: _cores[n], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_rotulos[n]!, style: mono(16, peso: FontWeight.w700))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_descricoes[n]!, style: mono(11, cor: p.textoSuave)),
                  const SizedBox(height: 10),
                  Container(
                    height: 50,
                    padding: const EdgeInsets.fromLTRB(12, 0, 5, 0),
                    decoration: BoxDecoration(
                      color: p.campo,
                      border: Border.all(color: p.textoSuave.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.directions_car_outlined, size: 18, color: p.textoSuave),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _campos[n],
                            keyboardType: TextInputType.number,
                            style: mono(14),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'Alertar com quantas vagas livres',
                              hintStyle: mono(13, cor: p.textoSuave),
                            ),
                            onSubmitted: (_) => _salvar(n),
                          ),
                        ),
                        BotaoAzul(texto: 'Salvar', pequeno: true, altura: 38, onTap: () => _salvar(n)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: p.textoSuave),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Os alertas disparam quando o número de vagas livres do bloco chega ao valor informado.',
                  style: mono(12, cor: p.textoSuave),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
