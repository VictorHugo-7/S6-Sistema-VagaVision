import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Onde o usuário está em relação à faculdade.
enum EstadoLocal {
  /// Ainda não verificou (ou está verificando pela primeira vez).
  desconhecido,
  naFaculdade,
  foraDaFaculdade,

  /// O usuário não liberou a localização.
  semPermissao,

  /// O GPS/localização do aparelho está desligado.
  semServico,

  /// Não foi possível obter a posição (sem sinal, tempo esgotado, plataforma sem suporte...).
  indisponivel,
}

/// Resultado de uma leitura de localização: ou uma posição, ou o motivo de não ter conseguido.
class LeituraLocal {
  const LeituraLocal({this.latitude, this.longitude, this.problema});

  final double? latitude, longitude;
  final EstadoLocal? problema;
}

typedef LeitorLocal = Future<LeituraLocal> Function(bool pedirPermissao);

/// Descobre se o usuário está na faculdade (a até [raioMetros] do ponto do campus).
/// É usado para só mandar avisos de vaga a quem está perto do estacionamento.
class LocalizacaoCampus extends ChangeNotifier {
  LocalizacaoCampus({
    this.latitude = latitudeIMT,
    this.longitude = longitudeIMT,
    this.raioMetros = raioPadraoMetros,
    this.intervalo = const Duration(minutes: 2),
    LeitorLocal? leitor,
  }) : _leitor = leitor ?? lerComGeolocator;

  /// Instituto Mauá de Tecnologia (Praça Mauá, 1 – São Caetano do Sul).
  /// Confira no Google Maps (botão direito no ponto → coordenadas) e ajuste se precisar.
  static const latitudeIMT = -23.647955;
  static const longitudeIMT = -46.574245;

  /// Raio em volta do ponto que conta como "na faculdade" (o campus é grande e o GPS erra
  /// algumas dezenas de metros, principalmente dentro de prédios).
  static const raioPadraoMetros = 600.0;

  final double latitude, longitude, raioMetros;
  final Duration intervalo;
  final LeitorLocal _leitor;

  EstadoLocal _estado = EstadoLocal.desconhecido;
  double? _distancia;
  Timer? _timer;
  bool _iniciado = false, _verificando = false, _descartado = false;

  EstadoLocal get estado => _estado;

  /// Distância até o campus na última leitura, em metros.
  double? get distanciaMetros => _distancia;

  bool get naFaculdade => _estado == EstadoLocal.naFaculdade;

  /// Pede a permissão (uma vez), verifica agora e passa a verificar a cada [intervalo].
  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    _timer = Timer.periodic(intervalo, (_) => verificar());
    await verificar(pedirPermissao: true);
  }

  /// Lê a posição e atualiza o [estado]. Com [pedirPermissao], mostra o pedido ao usuário.
  Future<void> verificar({bool pedirPermissao = false}) async {
    if (_verificando) return;
    _verificando = true;
    try {
      final leitura = await _leitor(pedirPermissao);
      if (_descartado) return;
      final lat = leitura.latitude, lon = leitura.longitude;
      if (lat == null || lon == null) {
        _definir(leitura.problema ?? EstadoLocal.indisponivel, null);
      } else {
        final d = distanciaEntre(lat, lon, latitude, longitude);
        _definir(d <= raioMetros ? EstadoLocal.naFaculdade : EstadoLocal.foraDaFaculdade, d);
      }
    } catch (_) {
      if (!_descartado) _definir(EstadoLocal.indisponivel, null);
    } finally {
      _verificando = false;
    }
  }

  void _definir(EstadoLocal e, double? d) {
    if (e == _estado && d == _distancia) return;
    _estado = e;
    _distancia = d;
    notifyListeners();
  }

  /// Texto curto para a tela de avisos.
  String get texto => switch (_estado) {
        EstadoLocal.desconhecido => 'Verificando sua localização...',
        EstadoLocal.naFaculdade => 'Você está na faculdade.',
        EstadoLocal.foraDaFaculdade => 'Você está fora da faculdade (${_distanciaTexto()} do campus).',
        EstadoLocal.semPermissao => 'Localização não liberada.',
        EstadoLocal.semServico => 'A localização do aparelho está desligada.',
        EstadoLocal.indisponivel => 'Não consegui obter sua localização.',
      };

  String _distanciaTexto() {
    final d = _distancia;
    if (d == null) return '?';
    return d >= 1000 ? '${(d / 1000).toStringAsFixed(1)} km' : '${d.round()} m';
  }

  @override
  void dispose() {
    _descartado = true;
    _timer?.cancel();
    super.dispose();
  }

  /// Distância em metros entre dois pontos (fórmula de haversine).
  static double distanciaEntre(double lat1, double lon1, double lat2, double lon2) {
    const raioTerra = 6371000.0;
    double rad(double g) => g * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
    return 2 * raioTerra * math.asin(math.min(1.0, math.sqrt(a)));
  }

  /// Leitura de verdade, pelo GPS/navegador (pacote geolocator).
  static Future<LeituraLocal> lerComGeolocator(bool pedirPermissao) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LeituraLocal(problema: EstadoLocal.semServico);
      }
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied && pedirPermissao) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied || permissao == LocationPermission.deniedForever) {
        return const LeituraLocal(problema: EstadoLocal.semPermissao);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
      );
      return LeituraLocal(latitude: pos.latitude, longitude: pos.longitude);
    } catch (_) {
      return const LeituraLocal(problema: EstadoLocal.indisponivel);
    }
  }
}
