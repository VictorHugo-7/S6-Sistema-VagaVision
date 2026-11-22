import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onde o usuário estacionou ("Onde parei?"), para o mapa destacar a vaga.
class MeuCarro extends ChangeNotifier {
  static const _chave = 'meu_carro_v2';

  String? _codigo;
  DateTime? _desde;
  String? _carroId;
  String? _registroId;

  /// `true` quando o usuário marcou uma vaga.
  bool get estacionado => _codigo != null;

  /// Código da vaga, por exemplo "A3".
  String? get codigo => _codigo;

  /// Quando o usuário marcou a vaga.
  DateTime? get desde => _desde;

  /// Carro do usuário que está na vaga (`cars._id`), se conhecido.
  String? get carroId => _carroId;

  /// Registro ativo no banco (`parkings._id`), usado para dar baixa na saída.
  String? get registroId => _registroId;

  /// A vaga [codigo] é a do usuário?
  bool eMinha(String codigo) => estacionado && _codigo == codigo;

  void marcar(String codigo, {DateTime? agora, String? carroId, String? registroId}) {
    _codigo = codigo;
    _desde = agora ?? DateTime.now();
    _carroId = carroId;
    _registroId = registroId;
    notifyListeners();
    _salvar();
  }

  void limpar() {
    if (!estacionado) return;
    _codigo = null;
    _desde = null;
    _carroId = null;
    _registroId = null;
    notifyListeners();
    _salvar();
  }

  /// "A3".
  String get rotulo => _codigo ?? '';

  /// "há 25 min", "há 2 h 10 min" (tempo desde que estacionou).
  String tempoTexto([DateTime? agora]) {
    final d = _desde;
    if (d == null) return '';
    final min = (agora ?? DateTime.now()).difference(d).inMinutes;
    if (min < 1) return 'agora há pouco';
    if (min < 60) return 'há $min min';
    final h = min ~/ 60, m = min % 60;
    return m == 0 ? 'há $h h' : 'há $h h $m min';
  }

  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_chave);
      if (texto != null) {
        final m = jsonDecode(texto) as Map<String, dynamic>;
        _codigo = m['codigo'] as String?;
        _carroId = m['carroId'] as String?;
        _registroId = m['registroId'] as String?;
        final ms = m['desde'] as int?;
        _desde = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
        notifyListeners();
      }
    } catch (_) {
      // sem armazenamento: começa sem carro marcado
    }
  }

  Future<void> _salvar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!estacionado) {
        await prefs.remove(_chave);
      } else {
        await prefs.setString(
          _chave,
          jsonEncode({
            'codigo': _codigo,
            'carroId': _carroId,
            'registroId': _registroId,
            'desde': _desde?.millisecondsSinceEpoch,
          }),
        );
      }
    } catch (_) {}
  }
}
