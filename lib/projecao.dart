import 'dart:math' as math;
import 'dart:ui';

/// Vetor 3D imutável mínimo (evita depender de pacotes externos).
class V3 {
  const V3(this.x, this.y, this.z);

  final double x, y, z;

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double k) => V3(x * k, y * k, z * k);

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(dot(this));

  V3 normalizado() {
    final l = length;
    return V3(x / l, y / l, z / l);
  }
}

class Raio {
  const Raio(this.origem, this.direcao);

  final V3 origem, direcao;
}

/// Câmera perspectiva ou ortográfica que projeta pontos do mundo em pixels.
class Camara {
  Camara._({
    required this.olho,
    required this.frente,
    required this.direita,
    required this.cima,
    required this.tela,
    required this.ortografica,
    required this.tanMeioFov,
    required this.meiaAltura,
  });

  factory Camara.perspectiva({
    required V3 olho,
    required V3 alvo,
    required Size tela,
    double fovGraus = 42,
  }) {
    final base = _base(olho, alvo, const V3(0, 1, 0));
    return Camara._(
      olho: olho,
      frente: base.$1,
      direita: base.$2,
      cima: base.$3,
      tela: tela,
      ortografica: false,
      tanMeioFov: math.tan(fovGraus * math.pi / 360),
      meiaAltura: 0,
    );
  }

  factory Camara.ortografica({
    required V3 olho,
    required V3 alvo,
    required V3 cima,
    required Size tela,
    required double meiaAltura,
  }) {
    final base = _base(olho, alvo, cima);
    return Camara._(
      olho: olho,
      frente: base.$1,
      direita: base.$2,
      cima: base.$3,
      tela: tela,
      ortografica: true,
      tanMeioFov: 0,
      meiaAltura: meiaAltura,
    );
  }

  static const _perto = 0.1;

  final V3 olho, frente, direita, cima;
  final Size tela;
  final bool ortografica;
  final double tanMeioFov, meiaAltura;

  double get _aspecto => tela.width / tela.height;
  double get _meiaLargura => meiaAltura * _aspecto;

  static (V3, V3, V3) _base(V3 olho, V3 alvo, V3 cimaRef) {
    final f = (alvo - olho).normalizado();
    final r = f.cross(cimaRef).normalizado();
    final u = r.cross(f);
    return (f, r, u);
  }

  double distancia(V3 p) => (p - olho).length;

  V3 _paraVista(V3 p) {
    final v = p - olho;
    return V3(v.dot(direita), v.dot(cima), v.dot(frente));
  }

  Offset _projetarVista(V3 v) {
    final double nx, ny;
    if (ortografica) {
      nx = v.x / _meiaLargura;
      ny = v.y / meiaAltura;
    } else {
      final s = v.z * tanMeioFov;
      nx = v.x / (s * _aspecto);
      ny = v.y / s;
    }
    return Offset((nx * 0.5 + 0.5) * tela.width, (1 - (ny * 0.5 + 0.5)) * tela.height);
  }

  /// Projeta um ponto; `null` se estiver atrás da câmera.
  Offset? ponto(V3 p) {
    final v = _paraVista(p);
    if (!ortografica && v.z < _perto) return null;
    return _projetarVista(v);
  }

  /// Projeta um polígono recortando-o contra o plano próximo da câmera.
  List<Offset>? poligono(List<V3> pontos) {
    var v = pontos.map(_paraVista).toList();
    if (!ortografica) v = _recortarPerto(v);
    if (v.length < 3) return null;
    return v.map(_projetarVista).toList();
  }

  List<V3> _recortarPerto(List<V3> v) {
    final saida = <V3>[];
    for (var i = 0; i < v.length; i++) {
      final a = v[i];
      final b = v[(i + 1) % v.length];
      final aDentro = a.z >= _perto;
      final bDentro = b.z >= _perto;
      if (aDentro) saida.add(a);
      if (aDentro != bDentro) {
        final t = (_perto - a.z) / (b.z - a.z);
        saida.add(V3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, _perto));
      }
    }
    return saida;
  }

  /// Raio que sai da câmera passando pelo pixel [p].
  Raio raio(Offset p) {
    final nx = p.dx / tela.width * 2 - 1;
    final ny = -(p.dy / tela.height) * 2 + 1;
    if (ortografica) {
      final origem = olho + direita * (nx * _meiaLargura) + cima * (ny * meiaAltura);
      return Raio(origem, frente);
    }
    final dir = frente + direita * (nx * tanMeioFov * _aspecto) + cima * (ny * tanMeioFov);
    return Raio(olho, dir.normalizado());
  }
}
