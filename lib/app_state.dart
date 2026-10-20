import 'package:flutter/foundation.dart';

enum NivelAlerta { simples, medio, severo }

class ConfigAlerta {
  bool ativo = true;

  /// Quantidade de vagas livres a partir da qual o alerta dispara.
  int? simples, medio, severo;

  int? limite(NivelAlerta n) => switch (n) {
        NivelAlerta.simples => simples,
        NivelAlerta.medio => medio,
        NivelAlerta.severo => severo,
      };

  void definir(NivelAlerta n, int? valor) {
    switch (n) {
      case NivelAlerta.simples:
        simples = valor;
      case NivelAlerta.medio:
        medio = valor;
      case NivelAlerta.severo:
        severo = valor;
    }
  }
}

/// Sessão do usuário e configuração de alertas por bloco (em memória).
class AppState extends ChangeNotifier {
  /// [aoSair] encerra a sessão no serviço de login (Firebase). Sem ele (modo sem login),
  /// "sair" só limpa o usuário local.
  AppState({this.aoSair});

  final Future<void> Function()? aoSair;
  String? _usuario;
  final blocos = <String, ConfigAlerta>{'Bloco U': ConfigAlerta()};

  String? get usuario => _usuario;
  bool get logado => _usuario != null;
  String get blocoPrincipal => blocos.keys.first;

  /// Define (ou limpa, com `null`) o usuário da sessão. Usado pelo login e pelo
  /// listener do Firebase.
  void definirUsuario(String? nome) {
    if (_usuario == nome) return;
    _usuario = nome;
    notifyListeners();
  }

  void entrar(String nome) => definirUsuario(nome);

  void sair() {
    final f = aoSair;
    if (f != null) {
      f(); // o Firebase avisa a mudança pelo stream (definirUsuario(null))
    } else {
      definirUsuario(null);
    }
  }

  void alternarAlerta(String bloco) {
    final c = blocos[bloco]!;
    c.ativo = !c.ativo;
    notifyListeners();
  }

  void salvarLimite(String bloco, NivelAlerta nivel, int? valor) {
    blocos[bloco]!.definir(nivel, valor);
    notifyListeners();
  }

  /// Nível de alerta em vigor para [livres] vagas, ou `null` se nenhum dispara.
  NivelAlerta? nivelAtual(String bloco, int livres) {
    final c = blocos[bloco]!;
    if (!c.ativo) return null;
    for (final n in [NivelAlerta.severo, NivelAlerta.medio, NivelAlerta.simples]) {
      final limite = c.limite(n);
      if (limite != null && livres <= limite) return n;
    }
    return null;
  }
}
