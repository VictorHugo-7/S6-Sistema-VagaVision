import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'ocupacao_ao_vivo.dart';
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

/// Onde o bloco de vagas fica no mapa 2D (assets/mapa_modelo_construcoes.svg, viewBox 577×457).
///
/// Valores medidos no próprio SVG: a faixa diagonal ao lado do Bloco U. O tamanho e a posição
/// do bloco são calculados a partir do ConfigPatio, então ele continua cabendo na faixa mesmo
/// se o número de vagas ou as medidas mudarem.
class VagasSvg {
  /// Ponta de cima da faixa (meio da borda), em fração do SVG (x/largura, y/altura).
  static const pontaFaixa = Offset(0.44350, 0.43742);

  /// Direção da faixa, da ponta de cima para baixo, em graus (y da tela para baixo).
  static const direcaoGraus = 48.81;

  /// Largura da faixa como fração da LARGURA do SVG (~21.9 px de 577).
  static const larguraFaixa = 0.0380;

  /// Parte da largura da faixa ocupada pelas 2 fileiras + canteiro (o resto é folga).
  static const ocupacaoLargura = 0.91;

  /// Folga entre a ponta da faixa e a primeira vaga, em fração da largura do SVG.
  static const folgaPonta = 0.0035;
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
  // O zoom é relativo ao "SVG inteiro na tela" (= 1). Os limites e a vista inicial são
  // calculados pelo tamanho do bloco de vagas, então funcionam em qualquer tela.

  /// Ao abrir o 2D, o bloco de vagas ocupa esta fração do menor lado da tela.
  static const _fracaoTelaAoAbrir = 0.35;

  /// Até quanto dá para afastar, em relação à vista inicial (0.35 = ~3x mais longe).
  static const _afastarAte = 0.35;

  /// Até quanto dá para aproximar, em relação à vista inicial (8 = 8x mais perto).
  static const _aproximarAte = 8.0;

  Size _svg = const Size(577, 457); // viewBox do mapa_modelo_construcoes.svg
  double _zoom2d = 1;
  Offset _centro2d = const Offset(577 / 2, 457 / 2);
  bool _enquadrarVagas = true; // abre centralizado nas vagas na próxima vez que souber o tamanho da tela

  /// Rotação do mapa 2D, em radianos (0 = norte do SVG para cima). Positivo = horário.
  double _giro2d = 0;
  bool _voltandoNorte = false; // animação da bússola: gira de volta até 0

  /// Rotação atual do mapa 2D (radianos).
  double get giro2d => _giro2d;

  /// Raio e posição da bússola (canto superior direito da cena), em pixels.
  static const raioBussola = 18.0;
  Offset bussola2d(Size tela) => Offset(tela.width - raioBussola - 12, raioBussola + 12);

  /// A bússola só aparece com o mapa girado.
  bool get mostrarBussola => _modo == Modo.d2 && _giro2d.abs() > 0.01;

  /// Última leitura da câmera de cada nível (pelo índice). Níveis sem câmera seguem simulados.
  final Map<int, LeituraNivel> aoVivo = {};

  Modo get modo => _modo;
  int get nivel => _nivel;
  Vaga? get selecionada => _selecionada;
  List<Vaga> get vagas => niveis[_nivel];

  /// Leitura da câmera do nível exibido, ou `null` se ele não tem câmera.
  LeituraNivel? get leituraAtual => aoVivo[_nivel];

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
      _enquadrarVagas = true; // volta para a vista inicial, centrada nas vagas
      _giro2d = 0;
      _voltandoNorte = false;
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
    if (leituraAtual != null) return; // quem decide é a câmera
    for (final v in vagas) {
      _definirOcupacao(v, _rng.nextDouble() < 0.62);
    }
    _selecionada = null;
    notifyListeners();
  }

  void liberar() {
    if (leituraAtual != null) return;
    for (final v in vagas) {
      v.ocupada = false;
    }
    _selecionada = null;
    notifyListeners();
  }

  /// `true` se a vaga fica num nível com câmera.
  bool _naCamera(Vaga vaga) => aoVivo.keys.any((n) => niveis[n].contains(vaga));

  /// Aplica a ocupação detectada pela câmera (ver `OcupacaoAoVivo`).
  void aplicarLeitura(LeituraNivel leitura) {
    if (leitura.nivel >= niveis.length) return;
    aoVivo[leitura.nivel] = leitura;
    final agora = DateTime.now();
    for (final v in niveis[leitura.nivel]) {
      final l = leitura.vagas[v.code];
      if (l == null) continue;
      v.ocupada = l.ocupada;
      final desde = l.desde;
      if (l.ocupada) v.minutosOcupada = desde == null ? 0 : math.max(0, agora.difference(desde).inMinutes);
    }
    notifyListeners();
  }

  /// Vaga do [nivel] (0 = Nível 1) com o [codigo], ou `null`.
  Vaga? buscarVaga(int nivel, String codigo) {
    if (nivel < 0 || nivel >= niveis.length) return null;
    for (final v in niveis[nivel]) {
      if (v.code == codigo) return v;
    }
    return null;
  }

  /// Marca a vaga como ocupada (o usuário estacionou nela). Em nível com câmera, a
  /// ocupação vem dela e não muda aqui.
  void ocupar(Vaga vaga) {
    if (vaga.ocupada || _naCamera(vaga)) return;
    vaga.ocupada = true;
    vaga.minutosOcupada = 0;
    notifyListeners();
  }

  /// Libera a vaga (o usuário saiu). Em nível com câmera, quem libera é ela.
  void liberarVaga(Vaga vaga) {
    if (!vaga.ocupada || _naCamera(vaga)) return;
    vaga.ocupada = false;
    notifyListeners();
  }

  /// Vai para o [nivel] e seleciona a vaga [codigo] (usado por "Onde estacionei?").
  void irParaVaga(int nivel, String codigo) {
    final v = buscarVaga(nivel, codigo);
    if (v == null) return;
    _nivel = nivel;
    _selecionada = v;
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
    if (_voltandoNorte) {
      // gira de volta para o norte suavemente (o centro da vista não muda)
      _giro2d += (0 - _giro2d) * math.min(1.0, k * 2.5);
      if (_giro2d.abs() < 0.002) {
        _giro2d = 0;
        _voltandoNorte = false;
      }
    }
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
      prepararTela2d(tela);
      // o arrasto é em pixels de tela: desfaz a rotação para mover no sentido certo do mapa
      _centro2d = _limitarCentro(_centro2d - _girarVetor(Offset(dx, dy), -_giro2d) / escala2d(tela));
    }
  }

  /// [fator] > 1 aproxima, < 1 afasta (pinça ou roda do mouse).
  /// No 2D, [foco] (posição na tela) fica parado durante o zoom, como num mapa.
  void zoom(double fator, {Offset? foco, Size? tela}) {
    if (_modo == Modo.d3) {
      _raioAlvo = (_raioAlvo / fator).clamp(_raioMin, _raioMax);
      return;
    }
    if (tela == null || tela.isEmpty) return;
    prepararTela2d(tela);
    final novo = (_zoom2d * fator).clamp(_zoomMin2d(tela), _zoomMax2d(tela));
    if (foco == null) {
      _zoom2d = novo;
      return;
    }
    final pontoSvg = telaParaSvg(foco, tela); // ponto do mapa sob o dedo/cursor
    _zoom2d = novo;
    _centro2d = _limitarCentro(pontoSvg - _girarVetor(foco - tela.center(Offset.zero), -_giro2d) / escala2d(tela));
  }

  /// Gira o mapa 2D em [delta] radianos (positivo = horário) em torno do [foco] na tela:
  /// o ponto sob os dedos/cursor fica parado, como num app de mapas.
  void girar2d(double delta, {required Offset foco, required Size tela}) {
    if (_modo != Modo.d2 || tela.isEmpty || delta == 0) return;
    _voltandoNorte = false;
    final pontoSvg = telaParaSvg(foco, tela);
    _giro2d = _normalizarAngulo(_giro2d + delta);
    _centro2d = _limitarCentro(pontoSvg - _girarVetor(foco - tela.center(Offset.zero), -_giro2d) / escala2d(tela));
  }

  /// Volta o norte para cima (animado). Usado pela bússola.
  void voltarNorte() {
    if (_giro2d == 0) return;
    _voltandoNorte = true;
    notifyListeners();
  }

  static Offset _girarVetor(Offset v, double a) {
    final cs = math.cos(a), sn = math.sin(a);
    return Offset(v.dx * cs - v.dy * sn, v.dx * sn + v.dy * cs);
  }

  static double _normalizarAngulo(double a) {
    while (a > math.pi) {
      a -= 2 * math.pi;
    }
    while (a <= -math.pi) {
      a += 2 * math.pi;
    }
    return a;
  }

  /// Aplica no canvas a transformação "unidades do SVG → tela" (pan, zoom e rotação).
  void transformar2d(Canvas canvas, Size tela) {
    final escala = escala2d(tela); // primeiro: pode aplicar a vista inicial
    final meio = tela.center(Offset.zero);
    canvas.translate(meio.dx, meio.dy);
    canvas.rotate(_giro2d);
    canvas.scale(escala);
    canvas.translate(-_centro2d.dx, -_centro2d.dy);
  }

  // ---------- mapa 2D (SVG) ----------

  /// Chamado pela cena quando o SVG termina de carregar.
  void definirTamanhoSvg(Size s) {
    if (s.isEmpty || s == _svg) return;
    _svg = s;
    _enquadrarVagas = true;
  }

  /// Zoom em que o bloco de vagas ocupa [_fracaoTelaAoAbrir] do menor lado da tela.
  double _zoomVagas2d(Size tela) {
    final base = math.min(tela.width / _svg.width, tela.height / _svg.height) * 0.96;
    final k = escalaVagas2d;
    final comprimento = ConfigPatio.cols * ConfigPatio.spotW * k;
    final largura = (ConfigPatio.aisle + 2 * ConfigPatio.spotD) * k;
    // diagonal do bloco: o bloco está girado, então ela representa bem o espaço que ocupa
    final diagonal = math.sqrt(comprimento * comprimento + largura * largura);
    return _fracaoTelaAoAbrir * math.min(tela.width, tela.height) / (diagonal * base);
  }

  double _zoomMin2d(Size tela) => math.max(1.0, _zoomVagas2d(tela) * _afastarAte);
  double _zoomMax2d(Size tela) => _zoomVagas2d(tela) * _aproximarAte;

  /// Aplica a vista inicial (centrada nas vagas) assim que o tamanho da tela é conhecido.
  /// A cena chama a cada layout; só age ao abrir o 2D ou ao voltar do 3D.
  void prepararTela2d(Size tela) {
    if (!_enquadrarVagas || tela.isEmpty) return;
    _enquadrarVagas = false;
    _zoom2d = _zoomVagas2d(tela);
    _centro2d = _limitarCentro(centroVagas2d);
    debugPrint('Mapa 2D: vista inicial nas vagas (zoom ${_zoom2d.toStringAsFixed(1)}x, tela ${tela.width.round()}x${tela.height.round()})');
  }

  /// Pixels de tela por unidade do SVG (zoom 1 = SVG inteiro cabendo na tela).
  /// Também garante a vista inicial nas vagas: quem desenha sempre passa por aqui,
  /// então o enquadramento acontece mesmo que ninguém chame [prepararTela2d] antes.
  double escala2d(Size tela) {
    prepararTela2d(tela);
    return math.min(tela.width / _svg.width, tela.height / _svg.height) * 0.96 * _zoom2d;
  }

  /// Onde o canto (0,0) do SVG fica na tela.
  /// Ponto do SVG na tela (com pan, zoom e rotação).
  Offset svgParaTela(Offset p, Size tela) {
    final escala = escala2d(tela); // primeiro: pode aplicar a vista inicial e mudar o centro
    return tela.center(Offset.zero) + _girarVetor(p - _centro2d, _giro2d) * escala;
  }

  Offset telaParaSvg(Offset p, Size tela) {
    final escala = escala2d(tela);
    return _centro2d + _girarVetor(p - tela.center(Offset.zero), -_giro2d) / escala;
  }

  /// Mantém o centro da vista dentro do SVG: o mapa nunca some da tela.
  Offset _limitarCentro(Offset c) => Offset(c.dx.clamp(0.0, _svg.width), c.dy.clamp(0.0, _svg.height));

  /// Unidades do SVG por metro do pátio: as 2 fileiras + canteiro preenchem a largura da faixa.
  double get escalaVagas2d =>
      VagasSvg.larguraFaixa * _svg.width * VagasSvg.ocupacaoLargura / (ConfigPatio.aisle + 2 * ConfigPatio.spotD);

  /// Rotação do bloco de vagas (radianos): o eixo X das fileiras segue a faixa.
  double get angulo2d => (VagasSvg.direcaoGraus - 180) * math.pi / 180;

  /// Centro do bloco de vagas no SVG: encostado na ponta de cima da faixa (canto do Bloco U).
  Offset get centroVagas2d {
    final ponta = Offset(VagasSvg.pontaFaixa.dx * _svg.width, VagasSvg.pontaFaixa.dy * _svg.height);
    final a = VagasSvg.direcaoGraus * math.pi / 180;
    final comprimento = ConfigPatio.cols * ConfigPatio.spotW * escalaVagas2d;
    final distancia = VagasSvg.folgaPonta * _svg.width + comprimento / 2;
    return ponta + Offset(math.cos(a), math.sin(a)) * distancia;
  }

  /// Ponto do pátio (x, z em metros) na tela, no modo 2D.
  Offset patioParaTela2d(double x, double z, Size tela) {
    final cs = math.cos(angulo2d), sn = math.sin(angulo2d);
    final svg = centroVagas2d + Offset(x * cs - z * sn, x * sn + z * cs) * escalaVagas2d;
    return svgParaTela(svg, tela);
  }

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
      if (tela.isEmpty) return;
      // toque na bússola: volta o norte para cima
      if (mostrarBussola && (pos - bussola2d(tela)).distance <= raioBussola + 6) {
        voltarNorte();
        return;
      }
      // mesma transformação usada no desenho: o toque cai exatamente na vaga vista
      final v = _vagaNoSvg(telaParaSvg(pos, tela));
      if (v == null) return;
      // com câmera, o toque só seleciona (a ocupação vem do vídeo)
      if (leituraAtual == null) _definirOcupacao(v, !v.ocupada);
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
        // com câmera, o toque só seleciona (a ocupação vem do vídeo)
        if (leituraAtual == null) _definirOcupacao(v, !v.ocupada);
        _selecionada = v;
        notifyListeners();
        return;
      }
    }
  }
}