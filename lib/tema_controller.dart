import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo claro/escuro do app (compartilhado pela versão web e pela mobile).
/// Começa seguindo o tema do aparelho; depois que o usuário toca no botão, a escolha é lembrada.
class TemaController extends ChangeNotifier {
  static const _chave = 'tema_escuro';

  ThemeMode _modo = ThemeMode.system;
  ThemeMode get modo => _modo;

  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final escuro = prefs.getBool(_chave);
      if (escuro != null) {
        _modo = escuro ? ThemeMode.dark : ThemeMode.light;
        notifyListeners();
      }
    } catch (_) {
      // sem armazenamento (testes, navegador bloqueando): segue o tema do aparelho
    }
  }

  Future<void> definirEscuro(bool escuro) async {
    _modo = escuro ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chave, escuro);
    } catch (_) {}
  }

  /// Inverte o tema que está na tela agora (use `Theme.of(context).brightness`).
  Future<void> alternar(Brightness atual) => definirEscuro(atual == Brightness.light);
}
