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
  });

  final int id;
  final String code;
  final double x, z, giro;
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
    for (var n = 0; n < niveis.length; n++) {
      for (final vaga in niveis[n]) {
        _definirOcupacao(vaga, _padraoInicial[(vaga.id + n * 3) % _padraoInicial.length]);
      }
    }
  }

  // Ocupação inicial igual à do Figma (true = ocupada): fileira A, depois fileira B. Dá 5/10 livres.
  // O nível 2 usa o mesmo padrão deslocado, também com 5/10 livres.
  static const _padraoInicial = [false, true, false, true, true, false, false, true, true, false];

  static const _phiMin = 0.14;
  static const _phiMax = 1.15;
  static const _fovGraus = 42.0;
  static const _thetaPadrao = 0.0;
  static const _phiPadrao = math.pi * 0.2; // câmera mais de cima, parecida com o Figma

  final _rng = math.Random();
  final List<List<Vaga>> niveis = [];

  Modo _modo = Modo.d3;
  int _nivel = 0;
  Vaga? _selecionada;

  // câmera (começa afastada e "voa" até a posição padrão)
  double _raioPadrao = 34; // distância que enquadra o pátio inteiro (calculada em ajustarTela)
  bool _telaAjustada = false;
  Size _ultimaTela = Size.zero;
  double _raio = 52, _raioAlvo = 34;
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
    const fileiras = [
      ('A', -(ConfigPatio.aisle / 2 + ConfigPatio.vagaD / 2), math.pi),
      ('B', ConfigPatio.aisle / 2 + ConfigPatio.vagaD / 2, 0.0),
    ];
    for (final (chave, z, giro) in fileiras) {
      for (var c = 0; c < ConfigPatio.cols; c++) {
        vagas.add(Vaga(
          id: vagas.length,
          code: '$chave${c + 1}',
          x: (c - (ConfigPatio.cols - 1) / 2) * ConfigPatio.passo,
          z: z,
          giro: giro,
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
    final ajusteLargura = (ConfigPatio.larguraPatio / 2 + 1) / aspecto;
    final ajusteAltura = ConfigPatio.profundidadePatio / 2 + 2;
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
    final olho = V3(
      alvo.x + _raio * math.sin(_phi) * math.sin(_theta),
      alvo.y + _raio * math.cos(_phi),
      alvo.z + _raio * math.sin(_phi) * math.cos(_theta),
    );
    return Camara.perspectiva(olho: olho, alvo: alvo, tela: tela, fovGraus: _fovGraus);
  }

  /// Enquadra o pátio inteiro na tela; chamado quando o tamanho da cena muda.
  void ajustarTela(Size tela) {
    if (tela.width <= 0 || tela.height <= 0 || tela == _ultimaTela) return;
    _ultimaTela = tela;
    final aspecto = tela.width / tela.height;
    final tanMeio = math.tan(_fovGraus * math.pi / 360);
    final meiaLargura = ConfigPatio.larguraPatio / 2 + 1.5;
    final meiaProf = ConfigPatio.profundidadePatio / 2 + 1.5;
    final porLargura = meiaLargura / (tanMeio * aspecto) + meiaProf * math.sin(_phiPadrao);
    final porAltura = meiaProf * math.cos(_phiPadrao) / tanMeio + meiaProf * math.sin(_phiPadrao);
    _raioPadrao = math.max(porLargura, porAltura).clamp(20.0, 120.0);
    _raioAlvo = _raioPadrao;
    if (!_telaAjustada) {
      _telaAjustada = true;
      _raio = _raioPadrao * 1.4; // começa afastada e "voa" até a posição padrão
    }
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
      _alvoX -= dx * porPixel;
      _alvoZ -= dy * porPixel;
    }
  }

  /// [fator] > 1 aproxima, < 1 afasta (pinça ou roda do mouse).
  void zoom(double fator) {
    if (_modo == Modo.d3) {
      _raioAlvo = (_raioAlvo / fator).clamp(_raioPadrao * 0.45, _raioPadrao * 1.5);
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
      if ((hx - v.x).abs() <= ConfigPatio.vagaW / 2 && (hz - v.z).abs() <= ConfigPatio.vagaD / 2) {
        _definirOcupacao(v, !v.ocupada);
        _selecionada = v;
        notifyListeners();
        return;
      }
    }
  }
}
