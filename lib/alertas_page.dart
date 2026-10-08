import 'package:flutter/material.dart';

import 'app_state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Lista de blocos com o interruptor "Ativar alertas".
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
          rodape: BotaoAzul(texto: 'Voltar', altura: 48, onTap: onVoltar),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(nome, style: mono(20, peso: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Configurar alertas do $nome',
            child: Material(
              color: Cores.cinza,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onEditar,
                child: const SizedBox(
                  width: alvoToque,
                  height: alvoToque,
                  child: Icon(Icons.tune_rounded, size: 20, color: Colors.white, semanticLabel: 'Configurar'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            toggled: ativo,
            label: 'Alertas do $nome',
            child: Material(
              color: ativo ? Cores.ativo : Cores.cinza,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onAlternar,
                child: SizedBox(
                  width: 92,
                  height: alvoToque,
                  child: Center(
                    child: Text(
                      ativo ? 'Ativo' : 'Inativo',
                      style: mono(12, peso: FontWeight.w700, cor: ativo ? Colors.white : Cores.texto),
                    ),
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

/// Limites dos alertas Simples, Médio e Severo de um bloco.
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
        content: Text(msg, style: mono(13, cor: Colors.white)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return PaginaFolha(
      child: FolhaBranca(
        titulo: widget.bloco,
        rodape: BotaoAzul(texto: 'Voltar', altura: 48, onTap: widget.onVoltar),
        filhos: [
          for (final n in NivelAlerta.values) ...[
            Text(_rotulos[n]!, style: mono(20, peso: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
              height: 48,
              padding: const EdgeInsets.fromLTRB(10, 0, 5, 0),
              decoration: BoxDecoration(
                color: Cores.campo,
                border: Border.all(color: Cores.texto),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _campos[n],
                      keyboardType: TextInputType.number,
                      style: mono(14),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Alertar com',
                        hintStyle: mono(14, cor: Cores.cinzaTexto),
                      ),
                      onSubmitted: (_) => _salvar(n),
                    ),
                  ),
                  BotaoAzul(texto: 'Salvar', pequeno: true, altura: 38, onTap: () => _salvar(n)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Os alertas disparam quando o número de vagas livres do bloco chega ao valor informado.',
            style: mono(12, cor: Cores.cinzaTexto),
          ),
        ],
      ),
    );
  }
}
