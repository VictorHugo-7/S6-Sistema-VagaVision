import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ocupação prevista/medida para uma hora do dia.
class PontoHora {
  const PontoHora(this.hora, this.ocupacao);

  /// 0 a 23.
  final int hora;

  /// 0.0 (vazio) a 1.0 (lotado).
  final double ocupacao;
}

/// Guarda a ocupação média do estacionamento por dia da semana e hora, e calcula a previsão.
///
/// Cada leitura (fração de vagas ocupadas) entra na "caixinha" do dia da semana + hora em que foi
/// feita. A média de cada caixinha é misturada com uma curva típica de campus ([_curvaBase]), que
/// pesa pouco: com poucas leituras a previsão segue a curva; com o tempo ela passa a seguir os
/// dados reais deste aparelho.
class HistoricoOcupacao extends ChangeNotifier {
  HistoricoOcupacao({this.intervaloMinimo = const Duration(seconds: 20)});

  static const _chave = 'historico_ocupacao_v1';

  /// Peso da curva típica, em "leituras" (quanto maior, mais devagar os dados reais assumem).
  static const pesoBase = 3.0;

  /// A partir de quantas leituras a previsão é considerada baseada em dados reais.
  static const leiturasConfiaveis = 40;

  /// Limite de leituras por caixinha; acima disso as antigas perdem peso (dados recentes valem mais).
  static const _limiteCaixinha = 60.0;

  /// Tempo mínimo entre duas leituras (o sorteio/toque gera várias mudanças seguidas).
  final Duration intervaloMinimo;

  // chave "dia-hora" (dia 1 = segunda ... 7 = domingo) -> [soma das ocupações, nº de leituras]
  final _caixas = <String, List<double>>{};
  DateTime? _ultima;
  double? _ultimaOcupacao;
  bool _carregado = false;

  bool get carregado => _carregado;

  /// Quantas leituras reais já foram registradas.
  int get leituras => _caixas.values.fold(0, (s, c) => s + c[1].round());

  /// `true` quando já há leituras suficientes para a previsão ser baseada em dados reais.
  bool get confiavel => leituras >= leiturasConfiaveis;

  /// Última ocupação registrada (0 a 1), ou `null` se ainda não houve leitura.
  double? get ultimaOcupacao => _ultimaOcupacao;

  static String _k(int dia, int hora) => '$dia-$hora';

  /// Curva típica de um campus: pico de manhã (aulas), vale no almoço, pico no início da noite.
  /// Fins de semana ficam bem mais vazios.
  static double curvaBase(int diaSemana, int hora) {
    const util = [
      0.04, 0.03, 0.03, 0.03, 0.04, 0.08, 0.20, 0.50, //  0h-7h
      0.78, 0.86, 0.84, 0.74, 0.62, 0.70, 0.80, 0.82, //  8h-15h
      0.76, 0.70, 0.82, 0.90, 0.84, 0.60, 0.28, 0.10, // 16h-23h
    ];
    final v = util[hora.clamp(0, 23)];
    if (diaSemana == DateTime.saturday) return v * 0.45;
    if (diaSemana == DateTime.sunday) return v * 0.15;
    return v;
  }

  /// Ocupação esperada (0 a 1) para [diaSemana] (1 = segunda ... 7 = domingo) e [hora].
  double ocupacaoEsperada(int diaSemana, int hora) {
    final base = curvaBase(diaSemana, hora);
    final c = _caixas[_k(diaSemana, hora)];
    if (c == null || c[1] <= 0) return base;
    return ((c[0] + base * pesoBase) / (c[1] + pesoBase)).clamp(0.0, 1.0);
  }

  /// As 24 horas de um dia da semana.
  List<PontoHora> dia(int diaSemana) => [
        for (var h = 0; h < 24; h++) PontoHora(h, ocupacaoEsperada(diaSemana, h)),
      ];

  /// Média do dia inteiro, só entre 6h e 22h (quando o campus funciona).
  double mediaDoDia(int diaSemana) {
    var soma = 0.0;
    for (var h = 6; h <= 22; h++) {
      soma += ocupacaoEsperada(diaSemana, h);
    }
    return soma / 17;
  }

  /// Hora de maior ocupação do dia (entre 6h e 22h).
  PontoHora picoDoDia(int diaSemana) {
    var melhor = PontoHora(6, ocupacaoEsperada(diaSemana, 6));
    for (var h = 7; h <= 22; h++) {
      final o = ocupacaoEsperada(diaSemana, h);
      if (o > melhor.ocupacao) melhor = PontoHora(h, o);
    }
    return melhor;
  }

  /// Hora de menor ocupação do dia (entre 6h e 22h): o melhor momento para chegar.
  PontoHora melhorHoraDoDia(int diaSemana) {
    var melhor = PontoHora(6, ocupacaoEsperada(diaSemana, 6));
    for (var h = 7; h <= 22; h++) {
      final o = ocupacaoEsperada(diaSemana, h);
      if (o < melhor.ocupacao) melhor = PontoHora(h, o);
    }
    return melhor;
  }

  /// Previsão das próximas [horas] horas, começando na hora cheia seguinte a [agora].
  List<PontoHora> previsao(DateTime agora, {int horas = 6}) {
    final lista = <PontoHora>[];
    var t = DateTime(agora.year, agora.month, agora.day, agora.hour).add(const Duration(hours: 1));
    for (var i = 0; i < horas; i++) {
      lista.add(PontoHora(t.hour, ocupacaoEsperada(t.weekday, t.hour)));
      t = t.add(const Duration(hours: 1));
    }
    return lista;
  }

  /// Primeira hora das próximas [horas] em que a ocupação passa de [limite], ou `null`.
  PontoHora? proximaLotacao(DateTime agora, {double limite = 0.85, int horas = 12}) {
    for (final p in previsao(agora, horas: horas)) {
      if (p.ocupacao >= limite) return p;
    }
    return null;
  }

  /// Registra uma leitura: [ocupacao] é a fração de vagas ocupadas (0 a 1).
  /// Leituras muito próximas uma da outra (menos de [intervaloMinimo]) são ignoradas.
  /// Devolve `true` se a leitura foi guardada.
  bool registrar(double ocupacao, {DateTime? agora}) {
    final t = agora ?? DateTime.now();
    final valor = ocupacao.clamp(0.0, 1.0).toDouble();
    _ultimaOcupacao = valor;
    final ultima = _ultima;
    if (ultima != null && t.difference(ultima).abs() < intervaloMinimo) return false;
    _ultima = t;
    final c = _caixas.putIfAbsent(_k(t.weekday, t.hour), () => [0.0, 0.0]);
    c[0] += valor;
    c[1] += 1;
    if (c[1] > _limiteCaixinha) {
      // dados antigos perdem peso: mantém a média e reduz a contagem
      final media = c[0] / c[1];
      c[1] = _limiteCaixinha * 0.8;
      c[0] = media * c[1];
    }
    notifyListeners();
    _salvar();
    return true;
  }

  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_chave);
      if (texto != null) {
        final mapa = jsonDecode(texto) as Map<String, dynamic>;
        for (final e in mapa.entries) {
          final v = (e.value as List).map((x) => (x as num).toDouble()).toList();
          if (v.length != 2) continue;
          final atual = _caixas[e.key]; // já pode haver leituras desta sessão: soma, não sobrescreve
          if (atual == null) {
            _caixas[e.key] = v;
          } else {
            atual[0] += v[0];
            atual[1] += v[1];
          }
        }
      }
    } catch (_) {
      // sem armazenamento disponível: segue só com a curva típica
    }
    _carregado = true;
    notifyListeners();
  }

  Future<void> _salvar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, jsonEncode(_caixas));
    } catch (_) {}
  }

  /// Apaga o histórico guardado (volta para a curva típica).
  Future<void> apagar() async {
    _caixas.clear();
    _ultima = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chave);
    } catch (_) {}
  }
}

/// Texto curto de uma hora: "8h", "14h".
String horaTexto(int hora) => '${hora}h';

/// Porcentagem inteira: 0.734 → "73%".
String pctTexto(double ocupacao) => '${(ocupacao * 100).round()}%';

/// Fração de vagas ocupadas (0 a 1) somando todos os níveis; [niveis] é uma lista de níveis,
/// cada um com a ocupação (`true` = ocupada) de suas vagas.
double ocupacaoGeral(Iterable<Iterable<bool>> niveis) {
  var ocupadas = 0, total = 0;
  for (final nivel in niveis) {
    for (final ocupada in nivel) {
      total++;
      if (ocupada) ocupadas++;
    }
  }
  return total == 0 ? 0 : ocupadas / total;
}
