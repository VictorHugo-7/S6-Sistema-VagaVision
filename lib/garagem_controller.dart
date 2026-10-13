import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'projecao.dart';
import 'theme.dart';

enum Modo { d3, d2 }

class Vaga {
  Vaga({
    required this.id,
    required this.code,
    required this.x,
    required this.z,
    required this.giro,
    required this.corCarro,
  });

  final int id;
  final String code;
  final double x, z, giro;
  final Color corCarro;
  bool ocupada = false;
  int minutosOcupada = 0;
}

class Estatisticas {
  const Estatisticas(this.livres, this.ocupadas);

  final int livres, ocupadas;
  int get total => livres + ocupadas;
  int get pctOcupado => total == 0 ? 0 : (ocupadas / total * 100).round();
}

/// Estado da garagem (vagas, nível, modo) e da câmera orbital / pan 2D.
class GaragemController extends ChangeNotifier {
  GaragemController() {
    for (var n = 0; n < ConfigPatio.numNiveis; n++) {
      niveis.add(_construirNivel());
    }
    for (final nivel in niveis) {
      for (final vaga in nivel) {
        _definirOcupacao(vaga, _rng.nextDouble() < 0.55);
      }
    }
  }

  static const _coresCarro = [
    Color(0xFFCFD3D6),
    Color(0xFF35415C),
    Color(0xFFEEF0EF),
    Color(0xFF4B4F57),
    Color(0xFF6B7159),
    Color(0xFF8A6F4E),
  ];
  static const _phiMin = 0.14;
  static const _phiMax = 1.15;
  // No 3D, o raio é um multiplicador da distância que enquadra o pátio na tela.
  static const _raioPadrao = 1.0;
  static const _raioMin = 0.4;
  static const _raioMax = 1.35;
  static const _tanMeioFov = 0.3839; // tan(21°): campo de visão vertical de 42°
  static const _thetaPadrao = 0.2;
  static const _phiPadrao = math.pi * 0.32;

  final _rng = math.Random();
  final List<List<Vaga>> niveis = [];

  Modo _modo = Modo.d2;
  int _nivel = 0;
  Vaga? _selecionada;

  // câmera (começa afastada e "voa" até a posição padrão)
  double _raio = 1.45, _raioAlvo = _raioPadrao;
  double _theta = 0.9, _thetaAlvo = _thetaPadrao;
  double _phi = 0.55, _phiAlvo = _phiPadrao;
  double _alvoX = 0, _alvoZ = 0;
  double _zoomOrto = 1;

  Modo get modo => _modo;
  int get nivel => _nivel;
  Vaga? get selecionada => _selecionada;
  List<Vaga> get vagas => niveis[_nivel];

  Estatisticas get stats {
    final ocupadas = vagas.where((v) => v.ocupada).length;
    return Estatisticas(vagas.length - ocupadas, ocupadas);
  }

  // ---------- construção ----------
List<Vaga> _construirNivel() {
  final vagas = <Vaga>[];

  // Restaure a fórmula original para alinhar com o arquivo SVG
  const fileiras = [
    ('A', -(ConfigPatio.aisle / 2 + ConfigPatio.spotD / 2), math.pi),
    ('B', ConfigPatio.aisle / 2 + ConfigPatio.spotD / 2, 0.0),
  ];

  for (final (chave, z, giro) in fileiras) {
    for (var c = 0; c < ConfigPatio.cols; c++) {
      vagas.add(Vaga(
        id: vagas.length,
        code: '$chave${c + 1}',
        x: (c - (ConfigPatio.cols - 1) / 2) * ConfigPatio.spotW,
        z: z, // <--- Volta a usar a coordenada Z alinhada
        giro: giro,
        corCarro: _coresCarro[_rng.nextInt(_coresCarro.length)],
      ));
    }
  }
  return vagas;
}

  void _definirOcupacao(Vaga vaga, bool ocupada) {
    vaga.ocupada = ocupada;
    if (ocupada) vaga.minutosOcupada = 1 + _rng.nextInt(118);
  }

  // ---------- ações do HUD ----------

  void setModo(Modo m) {
    if (m == _modo) return;
    _modo = m;
    _alvoX = 0;
    _alvoZ = 0;
    if (m == Modo.d2) {
      _zoomOrto = 1;
    } else {
      _raioAlvo = _raioPadrao;
      _thetaAlvo = _thetaPadrao;
      _phiAlvo = _phiPadrao;
    }
    notifyListeners();
  }

  void setNivel(int n) {
    if (n == _nivel) return;
    _nivel = n;
    _selecionada = null;
    notifyListeners();
  }

  void sortear() {
    for (final v in vagas) {
      _definirOcupacao(v, _rng.nextDouble() < 0.62);
    }
    _selecionada = null;
    notifyListeners();
  }

  void liberar() {
    for (final v in vagas) {
      v.ocupada = false;
    }
    _selecionada = null;
    notifyListeners();
  }

  // ---------- câmera ----------

  double _meiaAlturaOrto(double aspecto) {
    final ajusteLargura = (ConfigPatio.quadroMeiaLargura + 0.8) / aspecto;
    final ajusteAltura = ConfigPatio.quadroMeiaAltura + 0.8;
    return math.max(ajusteLargura, ajusteAltura) / _zoomOrto;
  }

  Camara camara(Size tela) {
    if (_modo == Modo.d2) {
      return Camara.ortografica(
        olho: V3(_alvoX, 40, _alvoZ),
        alvo: V3(_alvoX, 0, _alvoZ),
        cima: const V3(0, 0, -1),
        tela: tela,
        meiaAltura: _meiaAlturaOrto(tela.width / tela.height),
      );
    }
    final alvo = V3(_alvoX, 0, _alvoZ);
    // distância que enquadra o pátio: pela altura (vista inclinada) ou pela largura (telas estreitas)
    final aspecto = tela.width / tela.height;
    final base = math.min(70.0, math.max(30.0, (ConfigPatio.larguraPatio / 2 + 1.2) * 1.18 / (_tanMeioFov * aspecto)));
    final raio = base * _raio;
    final olho = V3(
      alvo.x + raio * math.sin(_phi) * math.sin(_theta),
      alvo.y + raio * math.cos(_phi),
      alvo.z + raio * math.sin(_phi) * math.cos(_theta),
    );
    return Camara.perspectiva(olho: olho, alvo: alvo, tela: tela);
  }

  /// Suaviza a câmera em direção ao alvo; [dt] em segundos.
  void tick(double dt) {
    final k = 1 - math.pow(1 - 0.08, dt * 60).toDouble();
    _raio += (_raioAlvo - _raio) * k;
    _theta += (_thetaAlvo - _theta) * k;
    _phi += (_phiAlvo - _phi) * k;
  }

  /// Arrasto de 1 dedo/mouse: gira em 3D, move a vista em 2D.
  void arrastar(double dx, double dy, Size tela) {
    if (_modo == Modo.d3) {
      _thetaAlvo -= dx * 0.006;
      _phiAlvo = (_phiAlvo - dy * 0.006).clamp(_phiMin, _phiMax);
    } else {
      final porPixel = 2 * _meiaAlturaOrto(tela.width / tela.height) / tela.height;
      // limita o arrasto para o mapa nunca sair totalmente da tela
      _alvoX = (_alvoX - dx * porPixel).clamp(-ConfigPatio.quadroMeiaLargura, ConfigPatio.quadroMeiaLargura);
      _alvoZ = (_alvoZ - dy * porPixel).clamp(-ConfigPatio.quadroMeiaAltura, ConfigPatio.quadroMeiaAltura);
    }
  }

  /// [fator] > 1 aproxima, < 1 afasta (pinça ou roda do mouse).
  void zoom(double fator) {
    if (_modo == Modo.d3) {
      _raioAlvo = (_raioAlvo / fator).clamp(_raioMin, _raioMax);
    } else {
      _zoomOrto = (_zoomOrto * fator).clamp(0.5, 3.2);
    }
  }

  // ---------- seleção ----------

  /// Toque na tela: lança um raio e alterna a vaga atingida no plano do piso.
  void toque(Offset pos, Size tela) {
    final raio = camara(tela).raio(pos);
    if (raio.direcao.y.abs() < 1e-9) return;
    const alturaOverlay = 0.02;
    final t = (alturaOverlay - raio.origem.y) / raio.direcao.y;
    if (t <= 0) return;
    final hx = raio.origem.x + raio.direcao.x * t;
    final hz = raio.origem.z + raio.direcao.z * t;
    for (final v in vagas) {
      if ((hx - v.x).abs() <= (ConfigPatio.spotW - 0.5) / 2 && (hz - v.z).abs() <= (ConfigPatio.spotD - 0.9) / 2) {
        _definirOcupacao(v, !v.ocupada);
        _selecionada = v;
        notifyListeners();
        return;
      }
    }
  }
}