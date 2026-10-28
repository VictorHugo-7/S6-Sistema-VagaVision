import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'localizacao.dart';
import 'meu_carro.dart';

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

  /// Devolve o motivo para NÃO avisar agora (carro estacionado, fora da faculdade...) ou `null`
  /// se pode avisar. O app define isso; sem ele, todo aviso é entregue.
  String? Function()? motivoBloqueio;

  bool _avisarVagaLivre = true;
  bool _somenteNaFaculdade = true;

  /// Liga/desliga os avisos de "vaga desocupada".
  bool get avisarVagaLivre => _avisarVagaLivre;

  /// Com `true` (padrão), os avisos só chegam enquanto o usuário está na faculdade.
  bool get somenteNaFaculdade => _somenteNaFaculdade;

  void definirAvisarVagaLivre(bool valor) {
    if (valor == _avisarVagaLivre) return;
    _avisarVagaLivre = valor;
    notifyListeners();
    _salvar();
  }

  void definirSomenteNaFaculdade(bool valor) {
    if (valor == _somenteNaFaculdade) return;
    _somenteNaFaculdade = valor;
    notifyListeners();
    _salvar();
  }

  static const _chaveVagaLivre = 'notif_avisar_vaga_livre';
  static const _chaveFaculdade = 'notif_somente_na_faculdade';

  /// Lê as duas chaves (ligado/desligado) salvas no aparelho.
  Future<void> carregarPreferencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _avisarVagaLivre = prefs.getBool(_chaveVagaLivre) ?? _avisarVagaLivre;
      _somenteNaFaculdade = prefs.getBool(_chaveFaculdade) ?? _somenteNaFaculdade;
      notifyListeners();
    } catch (_) {
      // sem armazenamento: valem os padrões
    }
  }

  Future<void> _salvar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chaveVagaLivre, _avisarVagaLivre);
      await prefs.setBool(_chaveFaculdade, _somenteNaFaculdade);
    } catch (_) {}
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
    // carro já estacionado ou usuário longe da faculdade: não incomoda (nem banner, nem histórico)
    if (motivoBloqueio?.call() != null) return;
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

/// Motivo para NÃO mandar avisos de vaga agora, ou `null` se pode avisar.
///
/// - Carro já estacionado: o usuário não precisa mais de vaga.
/// - Fora da faculdade (ou sem localização), quando [somenteNaFaculdade] está ligado.
String? motivoSemAviso({
  required MeuCarro carro,
  required LocalizacaoCampus campus,
  required bool somenteNaFaculdade,
}) {
  if (carro.estacionado) return 'Carro estacionado';
  if (somenteNaFaculdade && !campus.naFaculdade) {
    return campus.estado == EstadoLocal.foraDaFaculdade ? 'Fora da faculdade' : 'Localização indisponível';
  }
  return null;
}

/// Frase para a tela de avisos explicando por que os avisos estão (ou não) chegando.
String statusDosAvisos({
  required MeuCarro carro,
  required LocalizacaoCampus campus,
  required bool somenteNaFaculdade,
}) {
  if (carro.estacionado) return 'Carro estacionado na vaga ${carro.rotulo}: avisos pausados. Toque em "Já saí" no mapa para voltar a receber.';
  if (!somenteNaFaculdade) return 'Você recebe avisos em qualquer lugar.';
  final motivo = motivoSemAviso(carro: carro, campus: campus, somenteNaFaculdade: true);
  return motivo == null ? '${campus.texto} Avisos ativos.' : '${campus.texto} Avisos pausados.';
}

/// `true` quando faz sentido oferecer o botão "Ativar localização".
bool precisaAtivarLocalizacao(LocalizacaoCampus campus) =>
    campus.estado == EstadoLocal.semPermissao ||
    campus.estado == EstadoLocal.indisponivel ||
    campus.estado == EstadoLocal.semServico;
