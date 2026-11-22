import 'package:flutter/material.dart';

import '../carros_usuario.dart';
import '../estacionamentos.dart';
import '../garagem_controller.dart';
import '../meu_carro.dart';
import '../onde_parei_widgets.dart';
import 'quadro_tela.dart';
import 'theme.dart';

/// Tela "Onde parei?" (versão celular): os carros do usuário, a vaga de cada um
/// agora e um histórico simples. Os dados vêm da API (MongoDB).
class OndePareiPagina extends StatefulWidget {
  const OndePareiPagina({
    super.key,
    required this.controller,
    required this.meuCarro,
    required this.carros,
    required this.estacionamentos,
  });

  final GaragemController controller;
  final MeuCarro meuCarro;
  final CarrosUsuarioController carros;
  final EstacionamentosController estacionamentos;

  @override
  State<OndePareiPagina> createState() => _OndePareiPaginaState();
}

class _OndePareiPaginaState extends State<OndePareiPagina> {
  @override
  void initState() {
    super.initState();
    widget.carros.carregar();
    widget.estacionamentos.carregar();
  }

  Future<void> _novoCarro() async {
    final dados = await mostrarFormularioCarro(context);
    if (dados == null || !mounted) return;
    final problema = await widget.carros.adicionar(
      placa: dados.placa,
      modelo: dados.modelo,
      cor: dados.cor,
      apelido: dados.apelido,
    );
    if (problema != null && mounted) mostrarErro(context, problema);
  }

  Future<void> _editarCarro(CarroUsuario carro) async {
    final dados = await mostrarFormularioCarro(context, inicial: carro);
    if (dados == null || !mounted) return;
    final problema = await widget.carros.editar(
      carro.id,
      placa: dados.placa,
      modelo: dados.modelo,
      cor: dados.cor,
      apelido: dados.apelido ?? '',
    );
    if (problema != null && mounted) mostrarErro(context, problema);
  }

  Future<void> _removerCarro(CarroUsuario carro) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Remover ${carro.nome}?'),
        content: const Text('O carro e o histórico dele saem da sua lista.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    final problema = await widget.carros.remover(carro.id);
    if (problema != null && mounted) mostrarErro(context, problema);
  }

  Future<void> _marcarVaga(CarroUsuario carro) async {
    final vaga = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Em qual vaga você parou?'),
        content: SizedBox(
          width: 320,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in widget.controller.vagas)
                ActionChip(label: Text(v.code), onPressed: () => Navigator.of(d).pop(v.code)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancelar'))],
      ),
    );
    if (vaga == null || !mounted) return;
    final problema = await widget.estacionamentos.marcar(carro: carro, vaga: vaga);
    if (problema != null && mounted) mostrarErro(context, problema);
  }

  Future<void> _darBaixa(Estacionamento registro) async {
    final problema = await widget.estacionamentos.registrarSaida(registro.id);
    if (problema != null && mounted) mostrarErro(context, problema);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return QuadroTela(
      titulo: 'Onde parei?',
      preenchido: true,
      icone: const Icon(Icons.pin_drop_rounded, size: 20, color: Colors.white),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('Onde parei?', style: textoMono(20, cor: p.texto)),
          const SizedBox(height: 4),
          Text('Seus carros, a vaga de cada um e o histórico', style: textoMono(11, cor: p.textoSuave)),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: Listenable.merge([widget.carros, widget.estacionamentos, widget.meuCarro]),
            builder: (context, _) => CorpoOndeParei(
              carros: widget.carros,
              estacionamentos: widget.estacionamentos,
              fonte: textoMono,
              onNovoCarro: _novoCarro,
              onEditarCarro: _editarCarro,
              onRemoverCarro: _removerCarro,
              onMarcarVaga: _marcarVaga,
              onDarBaixa: _darBaixa,
            ),
          ),
        ],
      ),
    );
  }
}
