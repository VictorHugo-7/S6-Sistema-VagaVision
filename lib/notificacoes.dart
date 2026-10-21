import 'package:flutter/foundation.dart';

enum TipoNotificacao { info, livre, aviso, critico }

class Notificacao {
  Notificacao({required this.titulo, required this.mensagem, this.tipo = TipoNotificacao.info, DateTime? quando})
      : quando = quando ?? DateTime.now();

  final String titulo, mensagem;
  final TipoNotificacao tipo;
  final DateTime quando;
  bool lida = false;
}

/// Central de notificações do app (em memória). Quem gera os avisos chama [adicionar];
/// o app mostra um banner na hora ([aoChegar]) e guarda o histórico para a tela de avisos.
class NotificacoesController extends ChangeNotifier {
  static const _maximo = 50;

  final _itens = <Notificacao>[];
  List<Notificacao> get itens => List.unmodifiable(_itens);
  int get naoLidas => _itens.where((n) => !n.lida).length;

  /// Chamado a cada notificação nova (o app usa para mostrar o banner).
  void Function(Notificacao)? aoChegar;

  bool _avisarVagaLivre = true;

  /// Liga/desliga os avisos de "vaga desocupada".
  bool get avisarVagaLivre => _avisarVagaLivre;

  void definirAvisarVagaLivre(bool valor) {
    if (valor == _avisarVagaLivre) return;
    _avisarVagaLivre = valor;
    notifyListeners();
  }

  /// Avisa que [codigos] acabaram de ser desocupadas (se esse aviso estiver ligado).
  /// Várias de uma vez (ex.: "Liberar todas") viram uma notificação só.
  void vagasDesocupadas(String bloco, int nivel, List<String> codigos) {
    if (!_avisarVagaLivre || codigos.isEmpty) return;
    if (codigos.length == 1) {
      adicionar('Vaga ${codigos.first} desocupada', '$bloco · Nível $nivel: a vaga ficou livre.',
          tipo: TipoNotificacao.livre);
    } else {
      adicionar('${codigos.length} vagas desocupadas', '$bloco · Nível $nivel: ${codigos.join(', ')}.',
          tipo: TipoNotificacao.livre);
    }
  }

  void adicionar(String titulo, String mensagem, {TipoNotificacao tipo = TipoNotificacao.info}) {
    final n = Notificacao(titulo: titulo, mensagem: mensagem, tipo: tipo);
    _itens.insert(0, n);
    if (_itens.length > _maximo) _itens.removeLast();
    notifyListeners();
    aoChegar?.call(n);
  }

  void marcarTodasLidas() {
    var mudou = false;
    for (final n in _itens) {
      if (!n.lida) {
        n.lida = true;
        mudou = true;
      }
    }
    if (mudou) notifyListeners();
  }

  void limpar() {
    if (_itens.isEmpty) return;
    _itens.clear();
    notifyListeners();
  }
}

/// "agora", "há 5 min", "há 2 h" ou a data.
String quandoTexto(DateTime t, [DateTime? agora]) {
  final d = (agora ?? DateTime.now()).difference(t);
  if (d.inSeconds < 60) return 'agora';
  if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
  if (d.inHours < 24) return 'há ${d.inHours} h';
  return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';
}

/// Descobre quais vagas deixaram de estar ocupadas entre uma leitura e a seguinte.
class RastreadorVagas {
  final _antes = <int, List<bool>>{};

  /// Compara a ocupação atual do [nivel] com a última vista e devolve os códigos das vagas que
  /// passaram de ocupada para livre. A primeira leitura de cada nível só memoriza.
  List<String> desocupadas(int nivel, List<String> codigos, List<bool> ocupadas) {
    final antes = _antes[nivel];
    _antes[nivel] = List<bool>.of(ocupadas);
    if (antes == null || antes.length != ocupadas.length || codigos.length != ocupadas.length) return const [];
    return [
      for (var i = 0; i < ocupadas.length; i++)
        if (antes[i] && !ocupadas[i]) codigos[i],
    ];
  }
}
