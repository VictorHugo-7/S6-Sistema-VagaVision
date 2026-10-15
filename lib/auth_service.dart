import 'package:flutter/foundation.dart';

/// Erro com mensagem já pronta para mostrar ao usuário.
class ErroLogin implements Exception {
  ErroLogin(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Login com usuário e senha.
///
/// Provisório: enquanto o banco de dados não está conectado, existe só o
/// usuário padrão abaixo (`consoleadm` / `123456`). Quando o banco entrar, o
/// único ponto a trocar é [_buscar] — o resto do app não muda.
class AuthService {
  AuthService._();

  /// Usuário padrão embutido (vale só até o banco de dados ser conectado).
  static const usuarioPadrao = 'consoleadm';
  static const senhaPadrao = '123456';
  static const nomePadrao = 'Console Admin';

  static String? _nomeLogado;

  /// Nome do usuário da sessão atual, ou `null` se ninguém entrou.
  static String? get nomeLogado => _nomeLogado;

  /// Valida usuário e senha e devolve o nome para mostrar no app.
  /// Lança [ErroLogin] com a mensagem a exibir quando as credenciais não batem.
  static Future<String> entrar(String usuario, String senha) async {
    final login = usuario.trim();
    if (login.isEmpty || senha.isEmpty) {
      throw ErroLogin('Preencha usuário e senha.');
    }
    final nome = await _buscar(login, senha);
    if (nome == null) throw ErroLogin('Usuário ou senha incorretos.');
    _nomeLogado = nome;
    return nome;
  }

  static void sair() => _nomeLogado = null;

  /// Confere as credenciais e devolve o nome do usuário, ou `null` se não
  /// existe/senha errada.
  ///
  /// TODO(banco): substituir por uma consulta à tabela de usuários (com a senha
  /// guardada como hash) quando o banco de dados estiver conectado.
  static Future<String?> _buscar(String login, String senha) async {
    // pequena espera só para a tela mostrar o "carregando" como vai ser com o banco
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (login.toLowerCase() != usuarioPadrao || senha != senhaPadrao) {
      debugPrint('Login recusado para "$login" (usuário padrão: $usuarioPadrao).');
      return null;
    }
    return nomePadrao;
  }
}
