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

/// Calibração das vagas no mapa 2D (assets/mapa_modelo_construcoes.svg, viewBox 577×457).
///
/// Posição, rotação e escala do bloco de vagas em coordenadas do SVG: o bloco fica
/// "colado" no mapa e não escorrega com zoom ou arraste. Medido direto no SVG: faixa
/// diagonal ao lado do Bloco U, eixo a -131.2°, ~21.9 px de largura.
class VagasSvg {
  /// Centro do bloco de vagas, em fração do SVG (x/largura, y/altura).
  static const centro = Offset(0.45998, 0.46121);

  /// Rotação do bloco de vagas, em graus (alinhada à faixa).
  static const anguloGraus = -131.19;

  /// Unidades do SVG por metro do pátio, como fração da largura do SVG (≈ 1.45 px/m:
  /// as 2 fileiras + canteiro do ConfigPatio ocupam ~20 px dos ~21.9 px da faixa).
  static const escala = 0.002512;
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
  static const _raioMax = 3.5; // afasta o bastante para ver os prédios ao redor
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

  // mapa 2D (coordenadas em unidades do SVG, como um mapa: centro + zoom)
  static const _zoom2dMin = 1.0;
  static const _zoom2dMax = 8.0;
  Size _svg = const Size(577, 457); // viewBox do mapa_modelo_construcoes.svg
  double _zoom2d = 1;
  Offset _centro2d = const Offset(577 / 2, 457 / 2);

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
          z: z,
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
      _zoom2d = 1;
      _centro2d = _svg.center(Offset.zero);
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
      // o mapa acompanha o dedo 1:1, como num app de mapas
      if (tela.isEmpty) return;
      _centro2d = _limitarCentro(_centro2d - Offset(dx, dy) / escala2d(tela));
    }
  }

  /// [fator] > 1 aproxima, < 1 afasta (pinça ou roda do mouse).
  /// No 2D, [foco] (posição na tela) fica parado durante o zoom, como num mapa.
  void zoom(double fator, {Offset? foco, Size? tela}) {
    if (_modo == Modo.d3) {
      _raioAlvo = (_raioAlvo / fator).clamp(_raioMin, _raioMax);
      return;
    }
    final novo = (_zoom2d * fator).clamp(_zoom2dMin, _zoom2dMax);
    if (foco == null || tela == null || tela.isEmpty) {
      _zoom2d = novo;
      return;
    }
    final pontoSvg = telaParaSvg(foco, tela); // ponto do mapa sob o dedo/cursor
    _zoom2d = novo;
    _centro2d = _limitarCentro(pontoSvg - (foco - tela.center(Offset.zero)) / escala2d(tela));
  }

  // ---------- mapa 2D (SVG) ----------

  /// Chamado pela cena quando o SVG termina de carregar.
  void definirTamanhoSvg(Size s) {
    if (s.isEmpty || s == _svg) return;
    _centro2d = Offset(_centro2d.dx / _svg.width * s.width, _centro2d.dy / _svg.height * s.height);
    _svg = s;
  }

  /// Pixels de tela por unidade do SVG (zoom 1 = SVG inteiro cabendo na tela).
  double escala2d(Size tela) =>
      math.min(tela.width / _svg.width, tela.height / _svg.height) * 0.96 * _zoom2d;

  /// Onde o canto (0,0) do SVG fica na tela.
  Offset origem2d(Size tela) => tela.center(Offset.zero) - _centro2d * escala2d(tela);

  Offset telaParaSvg(Offset p, Size tela) => _centro2d + (p - tela.center(Offset.zero)) / escala2d(tela);

  /// Mantém o centro da vista dentro do SVG: o mapa nunca some da tela.
  Offset _limitarCentro(Offset c) => Offset(c.dx.clamp(0.0, _svg.width), c.dy.clamp(0.0, _svg.height));

  /// Centro do bloco de vagas no SVG.
  Offset get centroVagas2d => Offset(VagasSvg.centro.dx * _svg.width, VagasSvg.centro.dy * _svg.height);

  /// Rotação do bloco de vagas (radianos).
  double get angulo2d => VagasSvg.anguloGraus * math.pi / 180;

  /// Unidades do SVG por metro do pátio.
  double get escalaVagas2d => VagasSvg.escala * _svg.width;

  /// Desfaz a mesma transformação usada no desenho e acha a vaga tocada.
  Vaga? _vagaNoSvg(Offset p) {
    final d = (p - centroVagas2d) / escalaVagas2d;
    final cs = math.cos(angulo2d), sn = math.sin(angulo2d);
    final lx = d.dx * cs + d.dy * sn;
    final lz = -d.dx * sn + d.dy * cs;
    for (final v in vagas) {
      if ((lx - v.x).abs() <= ConfigPatio.spotW / 2 && (lz - v.z).abs() <= ConfigPatio.vagaProf2d / 2) return v;
    }
    return null;
  }

  // ---------- seleção ----------

  /// Toque na tela: lança um raio e alterna a vaga atingida no plano do piso.
  void toque(Offset pos, Size tela) {
    if (_modo == Modo.d2) {
      // mesma transformação usada no desenho: o toque cai exatamente na vaga vista
      if (tela.isEmpty) return;
      final v = _vagaNoSvg(telaParaSvg(pos, tela));
      if (v == null) return;
      _definirOcupacao(v, !v.ocupada);
      _selecionada = v;
      notifyListeners();
      return;
    }
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