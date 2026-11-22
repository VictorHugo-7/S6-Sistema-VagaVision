import 'package:flutter/foundation.dart';

import 'api.dart';
import 'carros_usuario.dart';
import 'meu_carro.dart';

/// Um registro de estacionamento (coleção `parkings` do MongoDB).
@immutable
class Estacionamento {
  const Estacionamento({
    required this.id,
    required this.carroId,
    required this.vaga,
    required this.entradaEm,
    this.saidaEm,
  });

  final String id;
  final String carroId;
  final String vaga;
  final DateTime entradaEm;

  /// `null` enquanto o carro ainda está na vaga.
  final DateTime? saidaEm;

  bool get ativo => saidaEm == null;

  Duration get duracao => (saidaEm ?? DateTime.now()).difference(entradaEm);

  static Estacionamento? doJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final carroId = json['carroId'];
    final vaga = json['vaga'];
    final entrada = _data(json['entradaEm']);
    if (id is! String || carroId is! String || vaga is! String || entrada == null) return null;
    return Estacionamento(
      id: id,
      carroId: carroId,
      vaga: vaga,
      entradaEm: entrada,
      saidaEm: _data(json['saidaEm']),
    );
  }

  static DateTime? _data(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
}

/// Registros de estacionamento do usuário: marcar a vaga, dar baixa na saída e
/// listar o histórico. Mantém o [MeuCarro] em sincronia para o mapa destacar a vaga.
class EstacionamentosController extends ChangeNotifier {
  EstacionamentosController({required this.meuCarro, Api? api}) : _api = api ?? Api();

  final MeuCarro meuCarro;
  final Api _api;

  List<Estacionamento> _registros = const [];
  bool _carregando = false;
  String? _erro;

  /// Todos os registros conhecidos, do mais recente para o mais antigo.
  List<Estacionamento> get registros => _registros;

  /// Carros que estão estacionados agora.
  List<Estacionamento> get ativos => [for (final r in _registros) if (r.ativo) r];

  /// Registros já encerrados (o histórico).
  List<Estacionamento> get historico => [for (final r in _registros) if (!r.ativo) r];

  bool get carregando => _carregando;
  String? get erro => _erro;

  /// Registro ativo de um carro, ou `null`.
  Estacionamento? ativoDoCarro(String carroId) {
    for (final r in _registros) {
      if (r.ativo && r.carroId == carroId) return r;
    }
    return null;
  }

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      final lista = await _api.get('/estacionamentos');
      _registros = [
        if (lista is List)
          for (final item in lista) ?Estacionamento.doJson(item),
      ];
      _sincronizarMeuCarro();
    } on ErroApi catch (e) {
      _erro = e.mensagem;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// O mapa destaca o registro ativo mais recente.
  void _sincronizarMeuCarro() {
    final atual = ativos.isEmpty ? null : ativos.first;
    if (atual == null) {
      meuCarro.limpar();
    } else {
      meuCarro.marcar(atual.vaga, agora: atual.entradaEm, carroId: atual.carroId, registroId: atual.id);
    }
  }

  /// Marca que [carro] parou na vaga [vaga]. Devolve `null` se deu certo, ou a
  /// mensagem de erro (ex.: o carro já está marcado em outra vaga).
  Future<String?> marcar({required CarroUsuario carro, required String vaga}) async {
    try {
      final json = await _api.post('/estacionamentos', {'carroId': carro.id, 'vaga': vaga});
      if (Estacionamento.doJson(json) case final r?) {
        _registros = [r, ..._registros];
        _sincronizarMeuCarro();
        notifyListeners();
      }
      return null;
    } on ErroApi catch (e) {
      return e.mensagem;
    }
  }

  /// Registra a saída. Devolve `null` se deu certo, ou a mensagem de erro.
  Future<String?> registrarSaida(String registroId) async {
    try {
      final json = await _api.patch('/estacionamentos/$registroId/saida');
      if (Estacionamento.doJson(json) case final atualizado?) {
        _registros = [for (final r in _registros) r.id == registroId ? atualizado : r];
        _sincronizarMeuCarro();
        notifyListeners();
      }
      return null;
    } on ErroApi catch (e) {
      return e.mensagem;
    }
  }
}
