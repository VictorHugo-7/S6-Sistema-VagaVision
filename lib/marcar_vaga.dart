import 'package:flutter/material.dart';

import 'carros_usuario.dart';
import 'estacionamentos.dart';
import 'meu_carro.dart';

/// Fluxo de "Estacionei aqui" / "Já saí", compartilhado pela web e pelo celular.

void _avisar(BuildContext context, String mensagem, {bool erro = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensagem),
      behavior: SnackBarBehavior.floating,
      backgroundColor: erro ? const Color(0xFFB3261E) : null,
    ),
  );
}

/// Pergunta qual carro está na vaga. Devolve `null` se o usuário desistir.
Future<CarroUsuario?> _escolherCarro(BuildContext context, List<CarroUsuario> carros, String vaga) {
  return showDialog<CarroUsuario>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: Text('Qual carro está na vaga $vaga?'),
      content: SizedBox(
        width: 340,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in carros)
              ListTile(
                leading: const Icon(Icons.directions_car_rounded),
                title: Text(c.nome),
                subtitle: Text('${c.placaFormatada} · ${c.modelo} · ${c.cor}'),
                onTap: () => Navigator.of(dialogo).pop(c),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogo).pop(), child: const Text('Cancelar')),
      ],
    ),
  );
}

/// Marca que o usuário parou na vaga [vaga]. Devolve `true` se o registro foi gravado.
Future<bool> marcarVaga(
  BuildContext context, {
  required CarrosUsuarioController carros,
  required EstacionamentosController estacionamentos,
  required String vaga,
  VoidCallback? aoPedirCadastro,
}) async {
  if (carros.itens.isEmpty) {
    // pode ser que a lista só não tenha carregado ainda
    await carros.carregar();
  }
  if (!context.mounted) return false;

  if (carros.erro case final problema?) {
    _avisar(context, problema, erro: true);
    return false;
  }

  if (carros.itens.isEmpty) {
    _avisar(context, 'Cadastre um carro antes de marcar a vaga.');
    aoPedirCadastro?.call();
    return false;
  }

  final carro = carros.itens.length == 1 ? carros.itens.first : await _escolherCarro(context, carros.itens, vaga);
  if (carro == null || !context.mounted) return false;

  final problema = await estacionamentos.marcar(carro: carro, vaga: vaga);
  if (!context.mounted) return false;
  if (problema != null) {
    _avisar(context, problema, erro: true);
    return false;
  }
  _avisar(context, '${carro.nome} marcado na vaga $vaga.');
  return true;
}

/// Registra a saída do carro que está marcado agora. Devolve `true` se deu certo.
Future<bool> registrarSaida(
  BuildContext context, {
  required EstacionamentosController estacionamentos,
  required MeuCarro meuCarro,
}) async {
  final registro = meuCarro.registroId;
  if (registro == null) {
    // sem registro no banco (ex.: marcado offline): limpa só o espelho local
    meuCarro.limpar();
    return true;
  }
  final problema = await estacionamentos.registrarSaida(registro);
  if (!context.mounted) return false;
  if (problema != null) {
    _avisar(context, problema, erro: true);
    return false;
  }
  _avisar(context, 'Saída registrada.');
  return true;
}
