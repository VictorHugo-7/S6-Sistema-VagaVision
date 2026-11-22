import 'package:flutter/foundation.dart';

import 'api.dart';
import 'placa.dart';

/// Um carro cadastrado pelo usuário (coleção `cars` do MongoDB).
@immutable
class CarroUsuario {
  const CarroUsuario({
    required this.id,
    required this.placa,
    required this.modelo,
    required this.cor,
    this.apelido,
  });

  final String id;
  final String placa;
  final String modelo;
  final String cor;
  final String? apelido;

  /// Como o carro aparece nas listas: o apelido, se tiver, senão o modelo.
  String get nome => (apelido?.isNotEmpty ?? false) ? apelido! : modelo;

  String get placaFormatada => formatarPlaca(placa);

  static CarroUsuario? doJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final placa = json['placa'];
    if (id is! String || placa is! String) return null;
    return CarroUsuario(
      id: id,
      placa: placa,
      modelo: json['modelo'] as String? ?? '',
      cor: json['cor'] as String? ?? '',
      apelido: json['apelido'] as String?,
    );
  }
}

/// Cadastro, listagem, edição e remoção dos carros do usuário, via API.
class CarrosUsuarioController extends ChangeNotifier {
  CarrosUsuarioController({Api? api}) : _api = api ?? Api();

  final Api _api;

  List<CarroUsuario> _itens = const [];
  bool _carregando = false;
  String? _erro;

  List<CarroUsuario> get itens => _itens;
  bool get carregando => _carregando;

  /// Mensagem do último erro, para a tela mostrar. `null` quando está tudo bem.
  String? get erro => _erro;

  bool get vazio => _itens.isEmpty && !_carregando && _erro == null;

  CarroUsuario? porId(String? id) {
    if (id == null) return null;
    for (final c in _itens) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      final lista = await _api.get('/carros');
      _itens = [
        if (lista is List)
          for (final item in lista) ?CarroUsuario.doJson(item),
      ];
    } on ErroApi catch (e) {
      _erro = e.mensagem;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Cadastra um carro. Devolve `null` se deu certo, ou a mensagem de erro.
  Future<String?> adicionar({
    required String placa,
    required String modelo,
    required String cor,
    String? apelido,
  }) async {
    final problema = erroPlaca(placa);
    if (problema != null) return problema;
    if (modelo.trim().isEmpty) return 'Informe o modelo.';
    if (cor.trim().isEmpty) return 'Informe a cor.';
    try {
      final json = await _api.post('/carros', {
        'placa': normalizarPlaca(placa),
        'modelo': modelo.trim(),
        'cor': cor.trim(),
        'apelido': apelido?.trim().isEmpty ?? true ? null : apelido!.trim(),
      });
      if (CarroUsuario.doJson(json) case final c?) {
        _itens = [..._itens, c];
        notifyListeners();
      }
      return null;
    } on ErroApi catch (e) {
      return e.mensagem;
    }
  }

  /// Edita um carro. Devolve `null` se deu certo, ou a mensagem de erro.
  Future<String?> editar(
    String id, {
    String? placa,
    String? modelo,
    String? cor,
    String? apelido,
  }) async {
    if (placa != null) {
      final problema = erroPlaca(placa);
      if (problema != null) return problema;
    }
    try {
      final json = await _api.patch('/carros/$id', {
        if (placa != null) 'placa': normalizarPlaca(placa),
        if (modelo != null) 'modelo': modelo.trim(),
        if (cor != null) 'cor': cor.trim(),
        if (apelido != null) 'apelido': apelido.trim().isEmpty ? null : apelido.trim(),
      });
      if (CarroUsuario.doJson(json) case final novo?) {
        _itens = [for (final c in _itens) c.id == id ? novo : c];
        notifyListeners();
      }
      return null;
    } on ErroApi catch (e) {
      return e.mensagem;
    }
  }

  /// Remove um carro. Devolve `null` se deu certo, ou a mensagem de erro
  /// (o backend recusa se o carro estiver marcado numa vaga).
  Future<String?> remover(String id) async {
    try {
      await _api.delete('/carros/$id');
      _itens = [for (final c in _itens) if (c.id != id) c];
      notifyListeners();
      return null;
    } on ErroApi catch (e) {
      return e.mensagem;
    }
  }
}
