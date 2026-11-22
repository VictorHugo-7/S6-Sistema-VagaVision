import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'carros_usuario.dart';
import 'estacionamentos.dart';
import 'placa.dart';

/// Peças da tela "Onde parei?" usadas pelas duas interfaces (web e celular).
/// Cada uma passa a própria fonte, por isso [FonteMono].
typedef FonteMono = TextStyle Function(double tamanho, {FontWeight peso, Color? cor});

void mostrarErro(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensagem),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFB3261E),
    ),
  );
}

/// O que o formulário de carro devolve.
@immutable
class DadosCarro {
  const DadosCarro({required this.placa, required this.modelo, required this.cor, this.apelido});

  final String placa, modelo, cor;
  final String? apelido;
}

/// Formulário de cadastro/edição de carro. Devolve `null` se o usuário desistir.
Future<DadosCarro?> mostrarFormularioCarro(BuildContext context, {CarroUsuario? inicial}) {
  final placa = TextEditingController(text: inicial?.placa ?? '');
  final modelo = TextEditingController(text: inicial?.modelo ?? '');
  final cor = TextEditingController(text: inicial?.cor ?? '');
  final apelido = TextEditingController(text: inicial?.apelido ?? '');
  final formulario = GlobalKey<FormState>();

  return showDialog<DadosCarro>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: Text(inicial == null ? 'Novo carro' : 'Editar ${inicial.nome}'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: placa,
                textCapitalization: TextCapitalization.characters,
                // o usuário pode digitar com hífen; a normalização tira
                inputFormatters: [LengthLimitingTextInputFormatter(8)],
                decoration: const InputDecoration(
                  labelText: 'Placa',
                  hintText: 'ABC1D23 ou ABC-1234',
                ),
                validator: erroPlaca,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: modelo,
                decoration: const InputDecoration(labelText: 'Modelo', hintText: 'Gol, Civic, HB20...'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o modelo.' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: cor,
                decoration: const InputDecoration(labelText: 'Cor', hintText: 'Prata, preto...'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Informe a cor.' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: apelido,
                decoration: const InputDecoration(labelText: 'Apelido (opcional)', hintText: 'Carro da facul'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogo).pop(), child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            if (formulario.currentState?.validate() != true) return;
            Navigator.of(dialogo).pop(DadosCarro(
              placa: placa.text,
              modelo: modelo.text,
              cor: cor.text,
              apelido: apelido.text,
            ));
          },
          child: Text(inicial == null ? 'Cadastrar' : 'Salvar'),
        ),
      ],
    ),
  );
}

/// "há 25 min", "há 2 h 10 min".
String duracaoTexto(Duration d) {
  final min = d.inMinutes;
  if (min < 1) return 'agora há pouco';
  if (min < 60) return '$min min';
  final h = min ~/ 60, m = min % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

String _dataTexto(DateTime d) {
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(d.day)}/${dois(d.month)} ${dois(d.hour)}:${dois(d.minute)}';
}

/// Corpo da tela "Onde parei?": lista de carros com a vaga de cada um e o histórico.
class CorpoOndeParei extends StatelessWidget {
  const CorpoOndeParei({
    super.key,
    required this.carros,
    required this.estacionamentos,
    required this.fonte,
    required this.onNovoCarro,
    required this.onEditarCarro,
    required this.onRemoverCarro,
    required this.onMarcarVaga,
    required this.onDarBaixa,
  });

  final CarrosUsuarioController carros;
  final EstacionamentosController estacionamentos;
  final FonteMono fonte;
  final VoidCallback onNovoCarro;
  final void Function(CarroUsuario) onEditarCarro;
  final void Function(CarroUsuario) onRemoverCarro;
  final void Function(CarroUsuario) onMarcarVaga;
  final void Function(Estacionamento) onDarBaixa;

  @override
  Widget build(BuildContext context) {
    final problema = carros.erro ?? estacionamentos.erro;
    final historico = estacionamentos.historico;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (problema != null)
          Card(
            color: const Color(0xFFFDECEA),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Color(0xFFB3261E)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(problema, style: fonte(12, cor: const Color(0xFF7F1D1D)))),
                ],
              ),
            ),
          ),

        Row(
          children: [
            Expanded(child: Text('Meus carros', style: fonte(15, peso: FontWeight.w700))),
            TextButton.icon(
              onPressed: onNovoCarro,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Novo'),
            ),
          ],
        ),

        if (carros.carregando && carros.itens.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (carros.itens.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nenhum carro cadastrado. Toque em "Novo" para cadastrar o primeiro — '
              'é ele que você vai marcar na vaga.',
              style: fonte(12),
            ),
          )
        else
          for (final carro in carros.itens)
            _CartaoCarro(
              carro: carro,
              registro: estacionamentos.ativoDoCarro(carro.id),
              fonte: fonte,
              onEditar: () => onEditarCarro(carro),
              onRemover: () => onRemoverCarro(carro),
              onMarcar: () => onMarcarVaga(carro),
              onDarBaixa: onDarBaixa,
            ),

        const SizedBox(height: 18),
        Text('Histórico', style: fonte(15, peso: FontWeight.w700)),
        const SizedBox(height: 6),
        if (historico.isEmpty)
          Text('Nada ainda. Os registros aparecem aqui depois que você marcar a saída.', style: fonte(12))
        else
          for (final r in historico.take(15))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vaga ${r.vaga} · ${carros.porId(r.carroId)?.nome ?? 'carro removido'}',
                      style: fonte(12, peso: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${_dataTexto(r.entradaEm)} · ${duracaoTexto(r.duracao)}', style: fonte(11)),
                ],
              ),
            ),
      ],
    );
  }
}

class _CartaoCarro extends StatelessWidget {
  const _CartaoCarro({
    required this.carro,
    required this.registro,
    required this.fonte,
    required this.onEditar,
    required this.onRemover,
    required this.onMarcar,
    required this.onDarBaixa,
  });

  final CarroUsuario carro;

  /// Registro ativo do carro, ou `null` se ele não está marcado em nenhuma vaga.
  final Estacionamento? registro;
  final FonteMono fonte;
  final VoidCallback onEditar, onRemover, onMarcar;
  final void Function(Estacionamento) onDarBaixa;

  @override
  Widget build(BuildContext context) {
    final r = registro;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(carro.nome, style: fonte(13, peso: FontWeight.w700), overflow: TextOverflow.ellipsis),
                      Text(
                        '${carro.placaFormatada} · ${carro.modelo} · ${carro.cor}',
                        style: fonte(11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEditar,
                ),
                IconButton(
                  tooltip: 'Remover',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: onRemover,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (r == null)
              Row(
                children: [
                  Expanded(child: Text('Não está marcado em nenhuma vaga.', style: fonte(11))),
                  TextButton(onPressed: onMarcar, child: const Text('Marcar vaga')),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.pin_drop_rounded, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Vaga ${r.vaga} · há ${duracaoTexto(r.duracao)}',
                      style: fonte(12, peso: FontWeight.w700, cor: const Color(0xFF16A34A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(onPressed: () => onDarBaixa(r), child: const Text('Já saí')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
