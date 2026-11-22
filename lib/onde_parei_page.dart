import 'package:flutter/material.dart';

import 'carros_usuario.dart';
import 'estacionamentos.dart';
import 'garagem_controller.dart';
import 'meu_carro.dart';
import 'onde_parei_widgets.dart';
import 'theme.dart';
import 'widgets.dart';

/// Tela "Onde parei?": os carros do usuário, em que vaga cada um está agora e um
/// histórico simples. Os dados vêm da API (coleções `cars` e `parkings` do MongoDB).
class OndePareiPage extends StatefulWidget {
  const OndePareiPage({
    super.key,
    required this.garagem,
    required this.meuCarro,
    required this.carros,
    required this.estacionamentos,
    required this.onVoltar,
  });

  final GaragemController garagem;
  final MeuCarro meuCarro;
  final CarrosUsuarioController carros;
  final EstacionamentosController estacionamentos;
  final VoidCallback onVoltar;

  @override
  State<OndePareiPage> createState() => _OndePareiPageState();
}

class _OndePareiPageState extends State<OndePareiPage> {
  @override
  void initState() {
    super.initState();
    // sempre que a tela abre, recarrega: outro aparelho pode ter mexido
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
    final vaga = await _escolherVaga();
    if (vaga == null || !mounted) return;
    final problema = await widget.estacionamentos.marcar(carro: carro, vaga: vaga);
    if (problema != null && mounted) mostrarErro(context, problema);
  }

  /// Lista as vagas do pátio para o usuário escolher onde parou.
  Future<String?> _escolherVaga() {
    final vagas = widget.garagem.vagas;
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Em qual vaga você parou?'),
        content: SizedBox(
          width: 340,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in vagas)
                ActionChip(
                  label: Text(v.code),
                  onPressed: () => Navigator.of(d).pop(v.code),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancelar'))],
      ),
    );
  }

  Future<void> _darBaixa(Estacionamento registro) async {
    final problema = await widget.estacionamentos.registrarSaida(registro.id);
    if (problema != null && mounted) mostrarErro(context, problema);
  }

  @override
  Widget build(BuildContext context) {
    return PaginaFolha(
      child: FolhaBranca(
        titulo: 'Onde parei?',
        subtitulo: 'Seus carros, a vaga de cada um e o histórico',
        icone: Icons.pin_drop_rounded,
        rodape: BotaoContorno(texto: 'Voltar', altura: 48, icone: Icons.arrow_back_rounded, onTap: widget.onVoltar),
        filhos: [
          ListenableBuilder(
            listenable: Listenable.merge([widget.carros, widget.estacionamentos, widget.meuCarro]),
            builder: (context, _) => CorpoOndeParei(
              carros: widget.carros,
              estacionamentos: widget.estacionamentos,
              fonte: mono,
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
