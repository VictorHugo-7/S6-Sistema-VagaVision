import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Erro da API com mensagem já pronta para mostrar ao usuário.
class ErroApi implements Exception {
  ErroApi(this.mensagem, {this.status, this.codigo});

  final String mensagem;
  final int? status;

  /// Código curto do backend (`placa_duplicada`, `carro_ja_estacionado`...), quando houver.
  final String? codigo;

  bool get naoAutenticado => status == 401;

  @override
  String toString() => mensagem;
}

/// Cliente da API do VagaVision (pasta `backend/`).
class Api {
  Api({http.Client? cliente, String? base})
      : _cliente = cliente ?? http.Client(),
        base = (base ?? _baseDefine).replaceAll(RegExp(r'/+$'), '');

  static const _baseDefine = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000/api');

  /// Endereço configurado (útil para mensagens de erro e para a tela de diagnóstico).
  final String base;
  final http.Client _cliente;

  static const _timeout = Duration(seconds: 12);

  Future<String?> _token() async {
    if (!AuthService.pronto) return null;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    try {
      return await u.getIdToken();
    } catch (e) {
      debugPrint('Não foi possível obter o id_token: $e');
      return null;
    }
  }

  Future<dynamic> _enviar(String metodo, String caminho, {Object? corpo}) async {
    final token = await _token();
    if (token == null) throw ErroApi('Entre na sua conta para continuar.', status: 401);

    final uri = Uri.parse('$base$caminho');
    final cabecalhos = {
      'Authorization': 'Bearer $token',
      if (corpo != null) 'Content-Type': 'application/json',
    };

    http.Response r;
    try {
      final pedido = http.Request(metodo, uri)..headers.addAll(cabecalhos);
      if (corpo != null) pedido.body = jsonEncode(corpo);
      r = await http.Response.fromStream(await _cliente.send(pedido)).timeout(_timeout);
    } catch (e) {
      throw ErroApi('Não foi possível falar com o servidor ($base). Ele está rodando?');
    }

    if (r.statusCode == 204 || r.body.isEmpty) return null;

    dynamic json;
    try {
      json = jsonDecode(r.body);
    } catch (_) {
      throw ErroApi('Resposta inesperada do servidor (HTTP ${r.statusCode}).', status: r.statusCode);
    }

    if (r.statusCode >= 400) {
      final mensagem = json is Map && json['erro'] is String ? json['erro'] as String : 'Erro HTTP ${r.statusCode}.';
      throw ErroApi(mensagem, status: r.statusCode, codigo: json is Map ? json['codigo'] as String? : null);
    }
    return json;
  }

  Future<dynamic> get(String caminho) => _enviar('GET', caminho);
  Future<dynamic> post(String caminho, Object corpo) => _enviar('POST', caminho, corpo: corpo);
  Future<dynamic> patch(String caminho, [Object corpo = const {}]) => _enviar('PATCH', caminho, corpo: corpo);
  Future<dynamic> delete(String caminho) => _enviar('DELETE', caminho);

  void fechar() => _cliente.close();
}
