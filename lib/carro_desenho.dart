import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'carro_personalizado.dart';
import 'projecao.dart';
import 'theme.dart';

class MedidasCarro {
  const MedidasCarro({
    required this.largura,
    required this.comprimento,
    required this.raio,
    required this.yBase,
    required this.yTopo,
    required this.cabBaixo,
    required this.cabCima,
    required this.yCabine,
    required this.roda,
    required this.rodaX,
    required this.rodaZ,
  });

  final double largura, comprimento, raio;

  final double yBase, yTopo;

  final (double, double, double) cabBaixo, cabCima;
  final double yCabine;

  final V3 roda;
  final double rodaX, rodaZ;

  static const hatch = MedidasCarro(
    largura: 1.75,
    comprimento: 3.4,
    raio: 0.45,
    yBase: 0.22,
    yTopo: 0.76,
    cabBaixo: (1.5, 1.95, 0.15),
    cabCima: (1.25, 1.5, 0.22),
    yCabine: 1.2,
    roda: V3(0.3, 0.58, 0.6),
    rodaX: 0.88,
    rodaZ: 1.05,
  );

  static const seda = MedidasCarro(
    largura: 1.8,
    comprimento: 3.8,
    raio: 0.42,
    yBase: 0.22,
    yTopo: 0.76,
    cabBaixo: (1.5, 1.95, -0.15),
    cabCima: (1.22, 1.4, -0.1),
    yCabine: 1.18,
    roda: V3(0.3, 0.6, 0.62),
    rodaX: 0.9,
    rodaZ: 1.2,
  );

  static const suv = MedidasCarro(
    largura: 1.9,
    comprimento: 3.9,
    raio: 0.45,
    yBase: 0.3,
    yTopo: 0.95,
    cabBaixo: (1.72, 2.6, 0.15),
    cabCima: (1.55, 2.25, 0.2),
    yCabine: 1.5,
    roda: V3(0.34, 0.74, 0.74),
    rodaX: 0.95,
    rodaZ: 1.25,
  );

  static const picape = MedidasCarro(
    largura: 1.9,
    comprimento: 4.3,
    raio: 0.4,
    yBase: 0.3,
    yTopo: 0.9,
    cabBaixo: (1.72, 1.7, -0.75),
    cabCima: (1.5, 1.35, -0.7),
    yCabine: 1.45,
    roda: V3(0.34, 0.72, 0.72),
    rodaX: 0.95,
    rodaZ: 1.35,
  );

  static MedidasCarro de(ModeloCarro m) => switch (m) {
        ModeloCarro.hatch => hatch,
        ModeloCarro.seda => seda,
        ModeloCarro.suv => suv,
        ModeloCarro.picape => picape,
      };
}

const _corPneu = Color(0xFF0E0F11);
const _corVidro = Color(0xFF1B1E22);
const _corParabrisa = Color(0xFF3A4A63);
const _corTeto = Color(0xFF2A3346);
const _corRack = Color(0xFF1E2532);
const _corLanterna = Color(0xFFFF5050);
const _corPlacaFaixa = Color(0xFF1E40AF);

final V3 _luz = const V3(24, 32, 14).normalizado();

List<(double, double)> contornoArredondado(double largura, double comprimento, double raio,
    {double dz = 0, int passos = 4}) {
  final hx = largura / 2 - raio, hz = comprimento / 2 - raio;
  final cantos = [(hx, hz, 0.0), (-hx, hz, math.pi / 2), (-hx, -hz, math.pi), (hx, -hz, math.pi * 1.5)];
  return [
    for (final (cx, cz, a0) in cantos)
      for (var i = 0; i <= passos; i++)
        (
          cx + raio * math.cos(a0 + math.pi / 2 * i / passos),
          dz + cz + raio * math.sin(a0 + math.pi / 2 * i / passos),
        ),
  ];
}

V3 _girar(V3 l, double a) {
  final cs = math.cos(a), sn = math.sin(a);
  return V3(l.x * cs + l.z * sn, l.y, -l.x * sn + l.z * cs);
}

Color _escalar(Color c, double k) => Color.from(
      alpha: c.a,
      red: (c.r * k).clamp(0.0, 1.0),
      green: (c.g * k).clamp(0.0, 1.0),
      blue: (c.b * k).clamp(0.0, 1.0),
    );

Color _sombrear(Color cor, double luz, Acabamento acabamento, {bool topo = false}) {
  switch (acabamento) {
    case Acabamento.brilho:
      final c = _escalar(cor, 0.45 + 0.65 * luz);
      return topo ? Color.lerp(c, Colors.white, 0.08)! : c;
    case Acabamento.metalico:
      final c = _escalar(cor, 0.32 + 0.9 * luz);
      return topo ? Color.lerp(c, Colors.white, 0.2)! : c;
    case Acabamento.fosco:
      final cinza = 0.3 * cor.r + 0.59 * cor.g + 0.11 * cor.b;
      final apagada = Color.from(
        alpha: cor.a,
        red: cor.r * 0.75 + cinza * 0.25,
        green: cor.g * 0.75 + cinza * 0.25,
        blue: cor.b * 0.75 + cinza * 0.25,
      );
      return _escalar(apagada, 0.62 + 0.36 * luz);
  }
}

const _faces = <(V3, List<V3>)>[
  (V3(1, 0, 0), [V3(1, -1, -1), V3(1, -1, 1), V3(1, 1, 1), V3(1, 1, -1)]),
  (V3(-1, 0, 0), [V3(-1, -1, 1), V3(-1, -1, -1), V3(-1, 1, -1), V3(-1, 1, 1)]),
  (V3(0, 1, 0), [V3(-1, 1, -1), V3(1, 1, -1), V3(1, 1, 1), V3(-1, 1, 1)]),
  (V3(0, 0, 1), [V3(-1, -1, 1), V3(1, -1, 1), V3(1, 1, 1), V3(-1, 1, 1)]),
  (V3(0, 0, -1), [V3(1, -1, -1), V3(-1, -1, -1), V3(-1, 1, -1), V3(1, 1, -1)]),
];

class _Pincel3d {
  _Pincel3d(this.c, this.cam, this.base, this.giro);

  final Canvas c;
  final Camara cam;
  final V3 base;
  final double giro;

  V3 mundo(V3 local) => base + _girar(local, giro);

  void poligono(List<V3> local, Color cor) {
    final pts = cam.poligono(local.map(mundo).toList());
    if (pts == null) return;
    c.drawPath(Path()..addPolygon(pts, true), Paint()..color = cor);
  }

  bool voltado(V3 normalLocal, V3 pontoLocal) {
    final n = _girar(normalLocal, giro);
    final paraOlho = cam.ortografica ? cam.frente * -1 : cam.olho - mundo(pontoLocal);
    return n.dot(paraOlho) > 0;
  }

  void face(List<V3> local, V3 normalLocal, Color Function(double luz) cor) {
    if (!voltado(normalLocal, local.first)) return;
    poligono(local, cor(math.max(0.0, _girar(normalLocal, giro).dot(_luz))));
  }

  void disco(double cx, double cz, double raio, double y, Color cor) {
    face([
      for (var i = 0; i < 24; i++) V3(cx + raio * math.cos(i * math.pi / 12), y, cz + raio * math.sin(i * math.pi / 12)),
    ], const V3(0, 1, 0), (_) => cor);
  }

  void caixa(V3 centro, V3 tam, Color cor) {
    for (final (normal, cantos) in _faces) {
      face(
        [for (final p in cantos) centro + V3(p.x * tam.x / 2, p.y * tam.y / 2, p.z * tam.z / 2)],
        normal,
        (l) => _escalar(cor, 0.45 + 0.65 * l),
      );
    }
  }

  void solido({
    required List<(double, double)> baixo,
    required double yBaixo,
    required List<(double, double)> cima,
    required double yCima,
    required Color Function(double luz, V3 normal) corLado,
    required Color Function(double luz) corTopo,
  }) {
    var mx = 0.0, mz = 0.0;
    for (final (x, z) in baixo) {
      mx += x;
      mz += z;
    }
    final meio = V3(mx / baixo.length, (yBaixo + yCima) / 2, mz / baixo.length);
    final n = baixo.length;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final a = V3(baixo[i].$1, yBaixo, baixo[i].$2);
      final b = V3(baixo[j].$1, yBaixo, baixo[j].$2);
      final c2 = V3(cima[j].$1, yCima, cima[j].$2);
      final d = V3(cima[i].$1, yCima, cima[i].$2);
      var normal = (b - a).cross(d - a).normalizado();
      if (normal.dot((a + b + c2 + d) * 0.25 - meio) < 0) normal = normal * -1;
      final nFace = normal;
      face([a, b, c2, d], nFace, (l) => corLado(l, nFace));
    }
    face([for (final (x, z) in cima) V3(x, yCima, z)], const V3(0, 1, 0), corTopo);
  }

  void noTopo(List<(double, double)> pontos, double y, Color cor) {
    face([for (final (x, z) in pontos) V3(x, y, z)], const V3(0, 1, 0), (l) => _escalar(cor, 0.55 + 0.5 * l));
  }

  void faixaNoTopo(double x0, double x1, double z0, double z1, double y, Color cor) {
    face([V3(x0, y, z0), V3(x1, y, z0), V3(x1, y, z1), V3(x0, y, z1)], const V3(0, 1, 0),
        (l) => _escalar(cor, 0.55 + 0.5 * l));
  }
}

MedidasCarro _medidasDo(CarroPersonalizado carro) {
  final m = MedidasCarro.de(carro.modelo);
  final (dy, k) = switch (carro.suspensao) {
    Suspensao.rebaixada => (-0.07, 0.95),
    Suspensao.padrao => (0.0, 1.0),
    Suspensao.elevada => (0.16, 1.18),
  };
  if (carro.suspensao == Suspensao.padrao) return m;
  return MedidasCarro(
    largura: m.largura,
    comprimento: m.comprimento,
    raio: m.raio,
    yBase: m.yBase + dy,
    yTopo: m.yTopo + dy,
    cabBaixo: m.cabBaixo,
    cabCima: m.cabCima,
    yCabine: m.yCabine + dy,
    roda: m.roda * k,
    rodaX: m.rodaX,
    rodaZ: m.rodaZ,
  );
}

(Color, Color) _coresVidro(Vidros v) => switch (v) {
      Vidros.claro => (const Color(0xFF3B4A5E), const Color(0xFF6B84A8)),
      Vidros.fume => (_corVidro, _corParabrisa),
      Vidros.preto => (const Color(0xFF08090B), const Color(0xFF161A20)),
    };

const _corImpulsao = Color(0xFF2B2F36);
const _corCromo = Color(0xFF9CA3AF);

List<List<(double, double)>> _formasAdesivo(Adesivo a, double meia, double zF, double zB) {
  final l = zB - zF;
  switch (a) {
    case Adesivo.nenhum:
      return const [];
    case Adesivo.chamas:
      final formas = <List<(double, double)>>[];
      for (final (k, tam) in const [(-1.0, 0.7), (0.0, 0.95), (1.0, 0.7)]) {
        final x = k * meia * 0.6, h = l * tam;
        formas.add([
          (x - 0.16, zF),
          (x + 0.16, zF),
          (x + 0.07, zF + h * 0.55),
          (x + 0.12, zF + h * 0.45),
          (x, zF + h),
          (x - 0.12, zF + h * 0.45),
          (x - 0.07, zF + h * 0.55),
        ]);
      }
      return formas;
    case Adesivo.xadrez:
      const q = 0.16;
      final colunas = (2 * meia / q).floor();
      final x0 = -colunas * q / 2;
      return [
        for (var linha = 0; linha < 2; linha++)
          for (var col = 0; col < colunas; col++)
            if ((linha + col).isEven)
              [
                (x0 + col * q, zF + linha * q),
                (x0 + (col + 1) * q, zF + linha * q),
                (x0 + (col + 1) * q, zF + (linha + 1) * q),
                (x0 + col * q, zF + (linha + 1) * q),
              ],
      ];
    case Adesivo.raio:
      return [
        [
          (0.15 * meia, zF),
          (-0.3 * meia, zF + 0.55 * l),
          (0.02 * meia, zF + 0.55 * l),
          (-0.15 * meia, zF + l),
          (0.32 * meia, zF + 0.42 * l),
          (0.0, zF + 0.42 * l),
        ],
      ];
  }
}

List<List<(double, double)>> _adesivoDo(CarroPersonalizado carro, MedidasCarro m) => _formasAdesivo(
      carro.adesivo,
      m.largura / 2 - 0.2,
      -m.comprimento / 2 + 0.1,
      m.cabBaixo.$3 - m.cabBaixo.$2 / 2 - 0.06,
    );

double _zCapo(MedidasCarro m) => (-m.comprimento / 2 + (m.cabBaixo.$3 - m.cabBaixo.$2 / 2)) / 2;

void desenharChaoCarro3d(Canvas c, Camara cam, V3 base, double giro, CarroPersonalizado carro) {
  final m = _medidasDo(carro);
  final p = _Pincel3d(c, cam, base, giro);
  List<V3> chao(double folga, double y) => [
        for (final (x, z) in contornoArredondado(m.largura + folga, m.comprimento + folga, m.raio + folga / 2))
          V3(x, y, z),
      ];
  if (carro.farolAceso) {
    final z0 = -m.comprimento / 2;
    for (final (alcance, abertura, alfa) in const [(4.6, 1.7, 0.12), (3.2, 1.2, 0.16)]) {
      p.poligono([
        V3(-0.65, 0.01, z0),
        V3(0.65, 0.01, z0),
        V3(abertura, 0.01, z0 - alcance),
        V3(-abertura, 0.01, z0 - alcance),
      ], carro.corFarol.withValues(alpha: alfa));
    }
  }
  if (carro.neon) {
    p.poligono(chao(1.2, 0.011), carro.corNeon.withValues(alpha: 0.16));
    p.poligono(chao(0.6, 0.012), carro.corNeon.withValues(alpha: 0.3));
  }
  p.poligono(chao(0.3, 0.014), Colors.black.withValues(alpha: 0.35));
}

void desenharCarro3d(Canvas c, Camara cam, V3 base, double giro, CarroPersonalizado carro) {
  final m = _medidasDo(carro);
  final p = _Pincel3d(c, cam, base, giro);
  final (lb, cb, dzb) = m.cabBaixo;
  final (lc, cc, dzc) = m.cabCima;
  final picape = carro.modelo == ModeloCarro.picape;
  final alturaCorpo = m.yTopo - m.yBase;

  void numero(double cz, double y, double raioDisco) {
    p.disco(0, cz, raioDisco, y, Colors.white);
    final centro = cam.ponto(p.mundo(V3(0, y, cz)));
    final borda = cam.ponto(p.mundo(V3(raioDisco, y, cz)));
    if (centro == null || borda == null) return;
    final raio = (borda - centro).distance;
    if (raio <= 3) return;
    final tp = TextPainter(
      text: TextSpan(text: '${carro.numero}', style: mono(raio * 1.05, peso: FontWeight.w700, cor: const Color(0xFF111111))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, centro - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  final rodas = <(double, V3, double)>[];
  for (final sx in const [-1.0, 1.0]) {
    for (final sz in const [-1.0, 1.0]) {
      final centro = V3(sx * m.rodaX, m.roda.y / 2, sz * m.rodaZ);
      rodas.add((cam.distancia(p.mundo(centro)), centro, sx));
    }
  }
  rodas.sort((a, b) => b.$1.compareTo(a.$1));
  for (final (_, centro, sx) in rodas) {
    p.caixa(centro, m.roda, _corPneu);
    final x = centro.x + sx * (m.roda.x / 2 + 0.005);
    final h = m.roda.y * 0.3, w = m.roda.z * 0.3;
    p.face([
      V3(x, centro.y - h, centro.z - w),
      V3(x, centro.y - h, centro.z + w),
      V3(x, centro.y + h, centro.z + w),
      V3(x, centro.y + h, centro.z - w),
    ], V3(sx, 0, 0), (l) => _escalar(carro.corRodas, 0.55 + 0.55 * l));
  }

  final antes = <void Function()>[], depois = <void Function()>[];
  void preso(V3 normal, V3 ponto, void Function() desenhar) => (p.voltado(normal, ponto) ? depois : antes).add(desenhar);

  if (carro.kitEsportivo) {
    final corSaia = Color.lerp(carro.cor, Colors.black, 0.4)!;
    preso(const V3(0, 0, -1), V3(0, m.yBase, -m.comprimento / 2), () {
      p.caixa(V3(0, m.yBase + 0.03, -m.comprimento / 2 - 0.04), V3(m.largura - 0.3, 0.07, 0.22), carro.corDetalhes);
    });
    for (final sx in const [-1.0, 1.0]) {
      preso(V3(sx, 0, 0), V3(sx * m.largura / 2, m.yBase, 0), () {
        p.caixa(V3(sx * (m.largura / 2 + 0.03), m.yBase + 0.06, 0), V3(0.07, 0.12, m.comprimento * 0.4), corSaia);
      });
    }
  }
  void estepe(V3 centro) {
    p.caixa(centro, const V3(0.56, 0.56, 0.2), _corPneu);
    final z = centro.z + 0.105;
    p.face([
      V3(0.11, centro.y - 0.11, z),
      V3(-0.11, centro.y - 0.11, z),
      V3(-0.11, centro.y + 0.11, z),
      V3(0.11, centro.y + 0.11, z),
    ], const V3(0, 0, 1), (l) => _escalar(carro.corRodas, 0.55 + 0.55 * l));
  }

  if (carro.impulsao) {
    final z = -m.comprimento / 2 - 0.14;
    preso(const V3(0, 0, -1), V3(0, m.yBase, -m.comprimento / 2), () {
      for (final sx in const [-1.0, 1.0]) {
        p.caixa(V3(sx * m.largura * 0.3, m.yBase + alturaCorpo * 0.45, z), V3(0.06, alturaCorpo * 0.95, 0.06), _corImpulsao);
      }
      for (final y in [m.yBase + 0.12, m.yBase + alturaCorpo * 0.8]) {
        p.caixa(V3(0, y, z), V3(m.largura * 0.72, 0.06, 0.06), _corImpulsao);
      }
    });
  }
  if (carro.escapamento) {
    preso(const V3(0, 0, 1), V3(0, m.yBase, m.comprimento / 2), () {
      for (final sx in const [-1.0, 1.0]) {
        p.caixa(V3(sx * 0.38, m.yBase + 0.06, m.comprimento / 2 + 0.06), const V3(0.1, 0.1, 0.16), _corCromo);
        final z = m.comprimento / 2 + 0.142;
        p.face([
          V3(sx * 0.38 + 0.03, m.yBase + 0.03, z),
          V3(sx * 0.38 - 0.03, m.yBase + 0.03, z),
          V3(sx * 0.38 - 0.03, m.yBase + 0.09, z),
          V3(sx * 0.38 + 0.03, m.yBase + 0.09, z),
        ], const V3(0, 0, 1), (_) => const Color(0xFF111111));
      }
    });
  }

  final zTrasEstepe = m.comprimento / 2 + 0.1;
  if (carro.estepe && !picape) {
    preso(const V3(0, 0, 1), V3(0, m.yTopo, m.comprimento / 2), () => estepe(V3(0, m.yTopo - 0.05, zTrasEstepe)));
  }

  for (final d in antes) {
    d();
  }

  final corpo = contornoArredondado(m.largura, m.comprimento, m.raio);
  p.solido(
    baixo: corpo,
    yBaixo: m.yBase,
    cima: corpo,
    yCima: m.yTopo,
    corLado: (l, _) => _sombrear(carro.cor, l, carro.acabamento),
    corTopo: (l) => _sombrear(carro.cor, l, carro.acabamento, topo: true),
  );

  final yTopo = m.yTopo + 0.004;
  if (carro.faixas) {
    final z = m.comprimento / 2 - m.raio * 0.6;
    for (final x in const [-0.17, 0.17]) {
      p.faixaNoTopo(x - 0.07, x + 0.07, -z, z, yTopo, carro.corDetalhes);
    }
  }

  for (final forma in _adesivoDo(carro, m)) {
    p.noTopo(forma, yTopo + 0.002, carro.corDetalhes);
  }
  if (carro.temNumero && !carro.entradaAr) numero(_zCapo(m), yTopo + 0.003, 0.27);

  if (picape) {
    final x = m.largura / 2 - 0.13;
    p.faixaNoTopo(-x, x, dzb + cb / 2 + 0.12, m.comprimento / 2 - 0.15, yTopo + 0.001,
        Color.lerp(carro.cor, Colors.black, 0.55)!);
  }

  final zFrente = -m.comprimento / 2 - 0.01, zTras = m.comprimento / 2 + 0.01;
  final reto = m.largura / 2 - m.raio;
  final altura = alturaCorpo;
  final y0 = m.yBase + altura * 0.45, y1 = m.yBase + altura * 0.78;
  final corFarol = carro.farolAceso ? Color.lerp(carro.corFarol, Colors.white, 0.35)! : carro.corFarol;
  for (final s in const [-1.0, 1.0]) {
    final xa = s * reto * 0.35, xb = s * reto * 0.95;
    p.face([V3(xa, y0, zFrente), V3(xb, y0, zFrente), V3(xb, y1, zFrente), V3(xa, y1, zFrente)],
        const V3(0, 0, -1), (_) => corFarol);
    p.face([V3(xb, y0, zTras), V3(xa, y0, zTras), V3(xa, y1, zTras), V3(xb, y1, zTras)], const V3(0, 0, 1),
        (_) => _corLanterna);
  }
  if (carro.placa.isNotEmpty) {
    final ya = m.yBase + altura * 0.1, yb = m.yBase + altura * 0.38;
    final yFaixa = yb - (yb - ya) * 0.28;
    final z = zTras + 0.002;
    p.face([V3(0.25, ya, z), V3(-0.25, ya, z), V3(-0.25, yb, z), V3(0.25, yb, z)], const V3(0, 0, 1),
        (_) => Colors.white);
    p.face([V3(0.25, yFaixa, z + 0.002), V3(-0.25, yFaixa, z + 0.002), V3(-0.25, yb, z + 0.002), V3(0.25, yb, z + 0.002)],
        const V3(0, 0, 1), (_) => _corPlacaFaixa);
  }

  for (final d in depois) {
    d();
  }

  final (vidroLado, vidroFrente) = _coresVidro(carro.vidros);
  void cabine() {
    p.solido(
      baixo: contornoArredondado(lb, cb, math.min(0.35, lb / 2 - 0.01), dz: dzb),
      yBaixo: m.yTopo,
      cima: contornoArredondado(lc, cc, math.min(0.3, lc / 2 - 0.01), dz: dzc),
      yCima: m.yCabine,
      corLado: (l, n) => _escalar(n.z < -0.55 ? vidroFrente : vidroLado, 0.45 + 0.65 * l),
      corTopo: (l) => carro.tetoBicolor
          ? _sombrear(carro.corTeto, l, carro.acabamento, topo: true)
          : _escalar(_corTeto, 0.45 + 0.65 * l),
    );
    final yTeto = m.yCabine + 0.004;
    if (carro.faixas) {
      final z0 = dzc - cc / 2 + 0.15, z1 = dzc + cc / 2 - 0.15;
      for (final x in const [-0.17, 0.17]) {
        p.faixaNoTopo(x - 0.07, x + 0.07, z0, z1, yTeto, carro.corDetalhes);
      }
    }
    if (carro.rack) {
      final y = m.yCabine + 0.05;
      for (final sx in const [-1.0, 1.0]) {
        p.caixa(V3(sx * lc / 2, y - 0.02, dzc), V3(0.05, 0.05, cc * 0.8), _corRack);
      }
      for (final dz in [dzc - cc * 0.28, dzc + cc * 0.28]) {
        p.caixa(V3(0, y, dz), V3(lc + 0.12, 0.05, 0.07), _corRack);
      }
      switch (carro.carga) {
        case CargaRack.malas:
          p.caixa(V3(-lc * 0.22, y + 0.14, dzc), V3(lc * 0.38, 0.22, cc * 0.34), const Color(0xFF6B4F2E));
          p.caixa(V3(lc * 0.22, y + 0.12, dzc + 0.05), V3(lc * 0.36, 0.18, cc * 0.3), const Color(0xFF3F4A5A));
        case CargaRack.prancha:
          p.caixa(V3(0, y + 0.07, dzc), V3(0.44, 0.05, cc + 1.0), carro.corDetalhes);
        case CargaRack.nenhuma:
          break;
      }
    }
    final yLuz = m.yCabine + (carro.rack ? 0.1 : 0.0);
    switch (carro.luzTeto) {
      case LuzTeto.taxi:
        p.caixa(V3(0, yLuz + 0.09, dzc), const V3(0.52, 0.18, 0.24), const Color(0xFFF2B33D));
      case LuzTeto.led:
        p.caixa(V3(0, yLuz + 0.04, dzc - cc * 0.38), V3(lc * 0.9, 0.07, 0.14), Color.lerp(carro.corNeon, Colors.white, 0.3)!);
      case LuzTeto.nenhuma:
        break;
    }
    if (carro.antena) {
      p.caixa(V3(lc * 0.32, m.yCabine + 0.22, dzc + cc * 0.3), const V3(0.025, 0.44, 0.025), const Color(0xFF111111));
    }
    if (carro.temNumero && carro.entradaAr) numero(dzc, yTeto + 0.003, math.min(0.27, lc * 0.3));
  }

  void entradaAr() {
    final z = _zCapo(m) + 0.05;
    p.caixa(V3(0, m.yTopo + 0.04, z), const V3(0.46, 0.08, 0.36), Color.lerp(carro.cor, Colors.black, 0.3)!);
    p.face([
      V3(0.17, m.yTopo + 0.015, z - 0.182),
      V3(-0.17, m.yTopo + 0.015, z - 0.182),
      V3(-0.17, m.yTopo + 0.07, z - 0.182),
      V3(0.17, m.yTopo + 0.07, z - 0.182),
    ], const V3(0, 0, -1), (_) => const Color(0xFF0B0D10));
  }

  void aerofolio() {
    final z = m.comprimento / 2 - 0.32;
    for (final sx in const [-1.0, 1.0]) {
      p.caixa(V3(sx * (m.largura / 2 - 0.3), m.yTopo + 0.11, z), const V3(0.06, 0.22, 0.06), _corRack);
    }
    p.caixa(V3(0, m.yTopo + 0.245, z), V3(m.largura - 0.08, 0.05, 0.38), carro.corDetalhes);
  }

  final cima = <(double, void Function())>[
    (cam.distancia(p.mundo(V3(0, m.yCabine, dzb))), cabine),
    if (carro.aerofolio) (cam.distancia(p.mundo(V3(0, m.yTopo + 0.25, m.comprimento / 2 - 0.32))), aerofolio),
    if (carro.entradaAr) (cam.distancia(p.mundo(V3(0, m.yTopo + 0.04, _zCapo(m) + 0.05))), entradaAr),
    if (carro.estepe && picape)
      (
        cam.distancia(p.mundo(V3(0, m.yTopo + 0.3, dzb + cb / 2 + 0.3))),
        () => estepe(V3(0, m.yTopo + 0.29, dzb + cb / 2 + 0.25)),
      ),
  ];
  cima.sort((a, b) => b.$1.compareTo(a.$1));
  for (final (_, desenhar) in cima) {
    desenhar();
  }
}

void desenharCarro2d(Canvas c, Offset centro, double angulo, CarroPersonalizado carro, double porMetro) {
  final m = _medidasDo(carro);
  final comp = m.comprimento, larg = m.largura;
  final picape = carro.modelo == ModeloCarro.picape;
  RRect caixa(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  c.save();
  c.translate(centro.dx, centro.dy);
  c.rotate(angulo);
  c.scale(porMetro);

  if (carro.farolAceso) {
    final cone = Path()
      ..moveTo(comp / 2, -0.65)
      ..lineTo(comp / 2 + 3.2, -1.4)
      ..lineTo(comp / 2 + 3.2, 1.4)
      ..lineTo(comp / 2, 0.65)
      ..close();
    c.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(colors: [carro.corFarol.withValues(alpha: 0.32), carro.corFarol.withValues(alpha: 0)])
            .createShader(Rect.fromLTWH(comp / 2, -1.4, 3.2, 2.8)),
    );
  }
  if (carro.neon) {
    c.drawRRect(caixa(-comp / 2 - 0.5, -larg / 2 - 0.5, comp + 1, larg + 1, m.raio + 0.5),
        Paint()..color = carro.corNeon.withValues(alpha: 0.14));
    c.drawRRect(caixa(-comp / 2 - 0.25, -larg / 2 - 0.25, comp + 0.5, larg + 0.5, m.raio + 0.25),
        Paint()..color = carro.corNeon.withValues(alpha: 0.28));
  }
  c.drawRRect(caixa(-comp / 2 + 0.1, -larg / 2 + 0.15, comp + 0.1, larg + 0.1, m.raio),
      Paint()..color = Colors.black.withValues(alpha: 0.45));

  final pneu = Paint()..color = _corPneu;
  for (final lado in const [-1.0, 1.0]) {
    for (final eixo in const [-1.0, 1.0]) {
      c.drawRRect(caixa(eixo * m.rodaZ - m.roda.z * 0.45, lado * (larg / 2 + 0.03) - 0.1, m.roda.z * 0.9, 0.2, 0.06), pneu);
    }
  }

  if (carro.kitEsportivo) {
    final saia = Paint()..color = Color.lerp(carro.cor, Colors.black, 0.4)!;
    for (final lado in const [-1.0, 1.0]) {
      c.drawRRect(caixa(-comp * 0.2, lado * (larg / 2 + 0.03) - 0.05, comp * 0.4, 0.1, 0.04), saia);
    }
    c.drawRRect(caixa(comp / 2 - 0.08, -(larg - 0.3) / 2, 0.16, larg - 0.3, 0.06), Paint()..color = carro.corDetalhes);
  }
  if (carro.estepe && !picape) {
    c.drawRRect(caixa(-comp / 2 - 0.2, -0.28, 0.24, 0.56, 0.08), pneu);
  }

  final corpo = caixa(-comp / 2, -larg / 2, comp, larg, m.raio);
  final pintura = Paint();
  switch (carro.acabamento) {
    case Acabamento.brilho:
      pintura.color = carro.cor;
    case Acabamento.metalico:
      pintura.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_escalar(carro.cor, 0.72), Color.lerp(carro.cor, Colors.white, 0.3)!, _escalar(carro.cor, 0.72)],
      ).createShader(corpo.outerRect);
    case Acabamento.fosco:
      pintura.color = _sombrear(carro.cor, 0.55, Acabamento.fosco);
  }
  c.drawRRect(corpo, pintura);
  if (carro.acabamento == Acabamento.brilho) {
    c.drawRRect(caixa(-comp / 2 + 0.4, -larg * 0.12, comp - 0.8, larg * 0.24, 0.1),
        Paint()..color = Colors.white.withValues(alpha: 0.10));
  }

  final detalhe = Paint()..color = carro.corDetalhes;
  if (carro.faixas) {
    for (final y in const [-0.17, 0.17]) {
      c.drawRect(Rect.fromLTWH(-comp / 2 + 0.2, y - 0.07, comp - 0.4, 0.14), detalhe);
    }
  }

  final (lb, cb, dzb) = m.cabBaixo;
  final (lc, cc, dzc) = m.cabCima;

  for (final forma in _adesivoDo(carro, m)) {
    c.drawPath(Path()..addPolygon([for (final (x, z) in forma) Offset(-z, x)], true), detalhe);
  }
  void numero(double x, double raio) {
    c.drawCircle(Offset(x, 0), raio, Paint()..color = Colors.white);
    final tp = TextPainter(
      text: TextSpan(text: '${carro.numero}', style: mono(raio * 1.1, peso: FontWeight.w700, cor: const Color(0xFF111111))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(x - tp.width / 2, -tp.height / 2));
    tp.dispose();
  }

  if (carro.temNumero && !carro.entradaAr) numero(-_zCapo(m), 0.27);
  if (carro.entradaAr) {
    final x = -(_zCapo(m) + 0.05);
    c.drawRRect(caixa(x - 0.18, -0.23, 0.36, 0.46, 0.06), Paint()..color = Color.lerp(carro.cor, Colors.black, 0.3)!);
    c.drawRect(Rect.fromLTWH(x + 0.12, -0.17, 0.05, 0.34), Paint()..color = const Color(0xFF0B0D10));
  }
  if (carro.impulsao) {
    c.drawRRect(caixa(comp / 2 + 0.08, -larg * 0.36, 0.1, larg * 0.72, 0.03), Paint()..color = _corImpulsao);
  }
  if (carro.escapamento) {
    for (final lado in const [-1.0, 1.0]) {
      c.drawRRect(caixa(-comp / 2 - 0.14, lado * 0.38 - 0.05, 0.14, 0.1, 0.03), Paint()..color = _corCromo);
    }
  }

  if (picape) {
    final z0 = dzb + cb / 2 + 0.12, z1 = comp / 2 - 0.15;
    c.drawRRect(caixa(-z1, -(larg / 2 - 0.13), z1 - z0, larg - 0.26, 0.08),
        Paint()..color = Color.lerp(carro.cor, Colors.black, 0.55)!);
    if (carro.estepe) {
      c.drawCircle(Offset(-(z0 + 0.4), 0), 0.3, pneu);
      c.drawCircle(Offset(-(z0 + 0.4), 0), 0.12, Paint()..color = carro.corRodas);
    }
  }

  final (vidroLado, vidroFrente) = _coresVidro(carro.vidros);
  c.drawRRect(caixa(-dzb - cb / 2, -lb / 2, cb, lb, 0.3), Paint()..color = vidroLado.withValues(alpha: 0.92));
  final frenteBase = -dzb + cb / 2, frenteTopo = -dzc + cc / 2;
  if (frenteBase > frenteTopo) {
    c.drawRRect(caixa(frenteTopo, -lb / 2 + 0.12, frenteBase - frenteTopo, lb - 0.24, 0.12),
        Paint()..color = vidroFrente);
  }
  c.drawRRect(caixa(-dzc - cc / 2, -lc / 2, cc, lc, 0.25),
      Paint()..color = carro.tetoBicolor ? carro.corTeto : _corTeto);
  if (carro.faixas) {
    for (final y in const [-0.17, 0.17]) {
      c.drawRect(Rect.fromLTWH(-dzc - cc / 2 + 0.15, y - 0.07, cc - 0.3, 0.14), detalhe);
    }
  }
  if (carro.rack) {
    final rack = Paint()..color = const Color(0xFF8B95A5);
    for (final dz in [dzc - cc * 0.28, dzc + cc * 0.28]) {
      c.drawRect(Rect.fromLTWH(-dz - 0.035, -lc / 2 - 0.06, 0.07, lc + 0.12), rack);
    }
    switch (carro.carga) {
      case CargaRack.malas:
        c.drawRRect(caixa(-dzc - cc * 0.17, -lc * 0.41, cc * 0.34, lc * 0.38, 0.05), Paint()..color = const Color(0xFF6B4F2E));
        c.drawRRect(caixa(-dzc - 0.05 - cc * 0.15, lc * 0.04, cc * 0.3, lc * 0.36, 0.05), Paint()..color = const Color(0xFF3F4A5A));
      case CargaRack.prancha:
        c.drawRRect(caixa(-dzc - (cc + 1.0) / 2, -0.22, cc + 1.0, 0.44, 0.22), detalhe);
      case CargaRack.nenhuma:
        break;
    }
  }
  switch (carro.luzTeto) {
    case LuzTeto.taxi:
      c.drawRRect(caixa(-dzc - 0.12, -0.26, 0.24, 0.52, 0.05), Paint()..color = const Color(0xFFF2B33D));
    case LuzTeto.led:
      c.drawRRect(caixa(-(dzc - cc * 0.38) - 0.07, -lc * 0.45, 0.14, lc * 0.9, 0.04),
          Paint()..color = Color.lerp(carro.corNeon, Colors.white, 0.3)!);
    case LuzTeto.nenhuma:
      break;
  }
  if (carro.antena) {
    c.drawCircle(Offset(-(dzc + cc * 0.3), lc * 0.32), 0.04, Paint()..color = const Color(0xFF111111));
  }
  if (carro.temNumero && carro.entradaAr) numero(-dzc, math.min(0.27, lc * 0.3));
  if (carro.aerofolio) {
    final x = -(comp / 2 - 0.32);
    c.drawRRect(caixa(x - 0.19, -larg / 2 + 0.04, 0.38, larg - 0.08, 0.06), detalhe);
  }

  final reto = larg / 2 - m.raio;
  final corFarol = carro.farolAceso ? Color.lerp(carro.corFarol, Colors.white, 0.35)! : carro.corFarol;
  for (final s in const [-1.0, 1.0]) {
    final y = s * reto * 0.65;
    c.drawRRect(caixa(comp / 2 - 0.14, y - reto * 0.3, 0.12, reto * 0.6, 0.04), Paint()..color = corFarol);
    c.drawRRect(caixa(-comp / 2 + 0.02, y - reto * 0.3, 0.1, reto * 0.6, 0.04), Paint()..color = _corLanterna);
  }
  c.restore();
}
