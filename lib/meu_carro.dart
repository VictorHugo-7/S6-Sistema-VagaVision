import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onde o usuário estacionou ("Onde estacionei?"). Fica salvo no aparelho, então continua
/// lá mesmo fechando o app.
class MeuCarro extends ChangeNotifier {
  static const _chave = 'meu_carro_v1';

  int? _nivel; // 0 = Nível 1
  String? _codigo;
  DateTime? _desde;

  /// `true` quando o usuário marcou uma vaga.
  bool get estacionado => _nivel != null && _codigo != null;

  /// Nível da vaga (0 = Nível 1).
  int? get nivel => _nivel;

  /// Código da vaga, por exemplo "A3".
  String? get codigo => _codigo;

  /// Quando o usuário marcou a vaga.
  DateTime? get desde => _desde;

  /// A vaga [codigo] do [nivel] é a do usuário?
  bool eMinha(int nivel, String codigo) => estacionado && _nivel == nivel && _codigo == codigo;

  void marcar(int nivel, String codigo, {DateTime? agora}) {
    _nivel = nivel;
    _codigo = codigo;
    _desde = agora ?? DateTime.now();
    notifyListeners();
    _salvar();
  }

  void limpar() {
    if (!estacionado) return;
    _nivel = null;
    _codigo = null;
    _desde = null;
    notifyListeners();
    _salvar();
  }

  /// "A3 · Nível 1".
  String get rotulo => estacionado ? '$_codigo · Nível ${_nivel! + 1}' : '';

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
        _nivel = m['nivel'] as int?;
        _codigo = m['codigo'] as String?;
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
          jsonEncode({'nivel': _nivel, 'codigo': _codigo, 'desde': _desde?.millisecondsSinceEpoch}),
        );
      }
    } catch (_) {}
  }
}
