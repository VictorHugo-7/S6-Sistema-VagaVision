import 'package:flutter/material.dart';

enum ModeloCarro { hatch, seda, suv, picape }

enum Acabamento { brilho, metalico, fosco }

enum Vidros { claro, fume, preto }

enum Suspensao { rebaixada, padrao, elevada }

enum CargaRack { nenhuma, malas, prancha }

enum Adesivo { nenhum, chamas, xadrez, raio }

enum LuzTeto { nenhuma, taxi, led }

String nomeDoModelo(ModeloCarro m) => switch (m) {
      ModeloCarro.hatch => 'Hatch',
      ModeloCarro.seda => 'Sedã',
      ModeloCarro.suv => 'SUV',
      ModeloCarro.picape => 'Picape',
    };

String nomeDoAcabamento(Acabamento a) => switch (a) {
      Acabamento.brilho => 'Brilho',
      Acabamento.metalico => 'Metálico',
      Acabamento.fosco => 'Fosco',
    };

String nomeDosVidros(Vidros v) => switch (v) {
      Vidros.claro => 'Claro',
      Vidros.fume => 'Fumê',
      Vidros.preto => 'Preto',
    };

String nomeDaSuspensao(Suspensao s) => switch (s) {
      Suspensao.rebaixada => 'Rebaixada',
      Suspensao.padrao => 'Padrão',
      Suspensao.elevada => 'Elevada',
    };

String nomeDaCarga(CargaRack c) => switch (c) {
      CargaRack.nenhuma => 'Nada',
      CargaRack.malas => 'Malas',
      CargaRack.prancha => 'Prancha',
    };

String nomeDoAdesivo(Adesivo a) => switch (a) {
      Adesivo.nenhum => 'Nenhum',
      Adesivo.chamas => 'Chamas',
      Adesivo.xadrez => 'Xadrez',
      Adesivo.raio => 'Raio',
    };

String nomeDaLuzTeto(LuzTeto l) => switch (l) {
      LuzTeto.nenhuma => 'Nada',
      LuzTeto.taxi => 'Táxi',
      LuzTeto.led => 'LED',
    };

const _coresComNome = <(String, int)>[
  ('Preto', 0xFF000000),
  ('Grafite', 0xFF2F3437),
  ('Cinza-chumbo', 0xFF4B5563),
  ('Cinza', 0xFF9CA3AF),
  ('Prata', 0xFFC0C7D1),
  ('Branco', 0xFFFFFFFF),
  ('Branco-gelo', 0xFFE8ECF3),
  ('Bege', 0xFFE8D9B5),
  ('Areia', 0xFFD6BE8A),
  ('Marrom', 0xFF6B4F2E),
  ('Chocolate', 0xFF4A2C1D),
  ('Vinho', 0xFF6D1A2B),
  ('Bordô', 0xFF800020),
  ('Vermelho', 0xFFD62828),
  ('Vermelho-coral', 0xFFF26B5B),
  ('Salmão', 0xFFFA8072),
  ('Rosa-choque', 0xFFEC4899),
  ('Rosa-claro', 0xFFF9A8D4),
  ('Magenta', 0xFFD946EF),
  ('Roxo', 0xFF7E22CE),
  ('Violeta', 0xFF8B5CF6),
  ('Lilás', 0xFFC4B5FD),
  ('Azul-marinho', 0xFF1E3A5F),
  ('Azul-royal', 0xFF124BBD),
  ('Azul', 0xFF2563EB),
  ('Azul-celeste', 0xFF5AA9FF),
  ('Azul-bebê', 0xFFBAE6FD),
  ('Azul xenon', 0xFF8FC8FF),
  ('Turquesa', 0xFF22D3EE),
  ('Ciano', 0xFF06B6D4),
  ('Verde-água', 0xFF2DD4BF),
  ('Verde-menta', 0xFF86EFAC),
  ('Verde-limão', 0xFFA3E635),
  ('Verde', 0xFF22C55E),
  ('Verde-neon', 0xFF4ADE80),
  ('Verde-oliva', 0xFF6B7A2E),
  ('Verde-militar', 0xFF4B5320),
  ('Verde-floresta', 0xFF14532D),
  ('Amarelo', 0xFFFACC15),
  ('Amarelo-ouro', 0xFFF2B33D),
  ('Amarelo-claro', 0xFFFFF4C8),
  ('Dourado', 0xFFD4AF37),
  ('Mostarda', 0xFFC9A227),
  ('Laranja', 0xFFF97316),
  ('Laranja-queimado', 0xFFC2410C),
  ('Pêssego', 0xFFFDBA74),
  ('Cobre', 0xFFB87333),
  ('Bronze', 0xFFCD7F32),
];

String nomeDaCor(Color cor) {
  final r = cor.r * 255, g = cor.g * 255, b = cor.b * 255;
  var melhor = _coresComNome.first.$1;
  var menor = double.infinity;
  for (final (nome, valor) in _coresComNome) {
    final c = Color(valor);
    final r2 = c.r * 255, g2 = c.g * 255, b2 = c.b * 255;
    final rm = (r + r2) / 2;
    final dr = r - r2, dg = g - g2, db = b - b2;
    final d = (2 + rm / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rm) / 256) * db * db;
    if (d < menor) {
      menor = d;
      melhor = nome;
    }
  }
  return melhor;
}

String hexDaCor(Color cor) => '#${(cor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class CarroPersonalizado {
  const CarroPersonalizado({
    this.modelo = ModeloCarro.seda,
    this.cor = const Color(0xFFF26B5B),
    this.acabamento = Acabamento.brilho,
    this.tetoBicolor = false,
    this.corTeto = const Color(0xFF1F2937),
    this.corDetalhes = const Color(0xFFFFFFFF),
    this.faixas = false,
    this.temNumero = false,
    this.numero = 7,
    this.adesivo = Adesivo.nenhum,
    this.corRodas = const Color(0xFFB8C1CC),
    this.estepe = false,
    this.suspensao = Suspensao.padrao,
    this.aerofolio = false,
    this.kitEsportivo = false,
    this.rack = false,
    this.carga = CargaRack.nenhuma,
    this.entradaAr = false,
    this.impulsao = false,
    this.escapamento = false,
    this.antena = false,
    this.luzTeto = LuzTeto.nenhuma,
    this.neon = false,
    this.corNeon = const Color(0xFF8FB4FF),
    this.vidros = Vidros.fume,
    this.corFarol = const Color(0xFFFFF4C8),
    this.farolAceso = false,
    this.placa = 'VGV1A23',
    this.apelido = '',
  });

  const CarroPersonalizado.padrao(Color cor) : this(cor: cor, placa: '');

  final ModeloCarro modelo;
  final Color cor;
  final Acabamento acabamento;

  final bool tetoBicolor;
  final Color corTeto;

  final Color corDetalhes;
  final bool faixas;

  final bool temNumero;
  final int numero;

  final Adesivo adesivo;

  final Color corRodas;

  final bool estepe;
  final Suspensao suspensao;
  final bool aerofolio;

  final bool kitEsportivo;
  final bool rack;

  final CargaRack carga;

  final bool entradaAr;

  final bool impulsao;

  final bool escapamento;
  final bool antena;

  final LuzTeto luzTeto;
  final bool neon;
  final Color corNeon;
  final Vidros vidros;
  final Color corFarol;

  final bool farolAceso;

  final String placa;

  final String apelido;

  static const tamanhoPlaca = 7;
  static const tamanhoApelido = 20;

  static const coresPintura = [
    Color(0xFFF26B5B),
    Color(0xFFE8ECF3),
    Color(0xFF1F2937),
    Color(0xFF5AA9FF),
    Color(0xFF124BBD),
    Color(0xFF4ADE80),
    Color(0xFF14532D),
    Color(0xFFF2B33D),
    Color(0xFFFB923C),
    Color(0xFFA855F7),
    Color(0xFFEC4899),
    Color(0xFF94A3B8),
  ];

  static const coresDetalhes = [
    Color(0xFFFFFFFF),
    Color(0xFF111111),
    Color(0xFFF2545B),
    Color(0xFFF2B33D),
    Color(0xFF4ADE80),
    Color(0xFF5AA9FF),
  ];

  static const coresRodas = [
    Color(0xFFB8C1CC),
    Color(0xFF2B2F36),
    Color(0xFFD4AF37),
    Color(0xFFF2545B),
    Color(0xFF5AA9FF),
    Color(0xFFFFFFFF),
  ];

  static const coresNeon = [
    Color(0xFF8FB4FF),
    Color(0xFF4ADE80),
    Color(0xFFF2545B),
    Color(0xFFA855F7),
    Color(0xFFF2B33D),
    Color(0xFF22D3EE),
  ];

  static const coresFarol = [
    Color(0xFFFFF4C8),
    Color(0xFFF1F5FF),
    Color(0xFFFFD34D),
    Color(0xFF8FC8FF),
  ];

  static String limparPlaca(String texto) {
    final s = texto.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    return s.length > tamanhoPlaca ? s.substring(0, tamanhoPlaca) : s;
  }

  static String limparApelido(String texto) {
    final s = texto.trim();
    return s.length > tamanhoApelido ? s.substring(0, tamanhoApelido) : s;
  }

  String get nome => apelido.isEmpty ? nomeDoModelo(modelo) : apelido;

  CarroPersonalizado copyWith({
    ModeloCarro? modelo,
    Color? cor,
    Acabamento? acabamento,
    bool? tetoBicolor,
    Color? corTeto,
    Color? corDetalhes,
    bool? faixas,
    bool? temNumero,
    int? numero,
    Adesivo? adesivo,
    Color? corRodas,
    bool? estepe,
    Suspensao? suspensao,
    bool? aerofolio,
    bool? kitEsportivo,
    bool? rack,
    CargaRack? carga,
    bool? entradaAr,
    bool? impulsao,
    bool? escapamento,
    bool? antena,
    LuzTeto? luzTeto,
    bool? neon,
    Color? corNeon,
    Vidros? vidros,
    Color? corFarol,
    bool? farolAceso,
    String? placa,
    String? apelido,
  }) =>
      CarroPersonalizado(
        modelo: modelo ?? this.modelo,
        cor: cor ?? this.cor,
        acabamento: acabamento ?? this.acabamento,
        tetoBicolor: tetoBicolor ?? this.tetoBicolor,
        corTeto: corTeto ?? this.corTeto,
        corDetalhes: corDetalhes ?? this.corDetalhes,
        faixas: faixas ?? this.faixas,
        temNumero: temNumero ?? this.temNumero,
        numero: (numero ?? this.numero).clamp(0, 99),
        adesivo: adesivo ?? this.adesivo,
        corRodas: corRodas ?? this.corRodas,
        estepe: estepe ?? this.estepe,
        suspensao: suspensao ?? this.suspensao,
        aerofolio: aerofolio ?? this.aerofolio,
        kitEsportivo: kitEsportivo ?? this.kitEsportivo,
        rack: rack ?? this.rack,
        carga: carga ?? this.carga,
        entradaAr: entradaAr ?? this.entradaAr,
        impulsao: impulsao ?? this.impulsao,
        escapamento: escapamento ?? this.escapamento,
        antena: antena ?? this.antena,
        luzTeto: luzTeto ?? this.luzTeto,
        neon: neon ?? this.neon,
        corNeon: corNeon ?? this.corNeon,
        vidros: vidros ?? this.vidros,
        corFarol: corFarol ?? this.corFarol,
        farolAceso: farolAceso ?? this.farolAceso,
        placa: placa == null ? this.placa : limparPlaca(placa),
        apelido: apelido == null ? this.apelido : limparApelido(apelido),
      );

  Map<String, Object?> paraMapa() => {
        'modelo': modelo.name,
        'cor': cor.toARGB32(),
        'acabamento': acabamento.name,
        'tetoBicolor': tetoBicolor,
        'corTeto': corTeto.toARGB32(),
        'corDetalhes': corDetalhes.toARGB32(),
        'faixas': faixas,
        'temNumero': temNumero,
        'numero': numero,
        'adesivo': adesivo.name,
        'corRodas': corRodas.toARGB32(),
        'estepe': estepe,
        'suspensao': suspensao.name,
        'aerofolio': aerofolio,
        'kitEsportivo': kitEsportivo,
        'rack': rack,
        'carga': carga.name,
        'entradaAr': entradaAr,
        'impulsao': impulsao,
        'escapamento': escapamento,
        'antena': antena,
        'luzTeto': luzTeto.name,
        'neon': neon,
        'corNeon': corNeon.toARGB32(),
        'vidros': vidros.name,
        'corFarol': corFarol.toARGB32(),
        'farolAceso': farolAceso,
        'placa': placa,
        'apelido': apelido,
      };

  static CarroPersonalizado doMapa(Object? dados) {
    if (dados is! Map) return const CarroPersonalizado();
    final Map<dynamic, dynamic> m = dados;
    const p = CarroPersonalizado();
    Color cor(String chave, Color padrao) {
      final v = m[chave];
      return v is int ? Color(v) : padrao;
    }

    bool sim(String chave) => m[chave] == true;
    String texto(String chave, String padrao) {
      final v = m[chave];
      return v is String ? v : padrao;
    }

    final numero = m['numero'];
    return CarroPersonalizado(
      modelo: ModeloCarro.values.asNameMap()[m['modelo']] ?? p.modelo,
      cor: cor('cor', p.cor),
      acabamento: Acabamento.values.asNameMap()[m['acabamento']] ?? p.acabamento,
      tetoBicolor: sim('tetoBicolor'),
      corTeto: cor('corTeto', p.corTeto),
      corDetalhes: cor('corDetalhes', p.corDetalhes),
      faixas: sim('faixas'),
      temNumero: sim('temNumero'),
      numero: numero is int ? numero.clamp(0, 99) : p.numero,
      adesivo: Adesivo.values.asNameMap()[m['adesivo']] ?? p.adesivo,
      corRodas: cor('corRodas', p.corRodas),
      estepe: sim('estepe'),
      suspensao: Suspensao.values.asNameMap()[m['suspensao']] ?? p.suspensao,
      aerofolio: sim('aerofolio'),
      kitEsportivo: sim('kitEsportivo'),
      rack: sim('rack'),
      carga: CargaRack.values.asNameMap()[m['carga']] ?? p.carga,
      entradaAr: sim('entradaAr'),
      impulsao: sim('impulsao'),
      escapamento: sim('escapamento'),
      antena: sim('antena'),
      luzTeto: LuzTeto.values.asNameMap()[m['luzTeto']] ?? p.luzTeto,
      neon: sim('neon'),
      corNeon: cor('corNeon', p.corNeon),
      vidros: Vidros.values.asNameMap()[m['vidros']] ?? p.vidros,
      corFarol: cor('corFarol', p.corFarol),
      farolAceso: sim('farolAceso'),
      placa: limparPlaca(texto('placa', p.placa)),
      apelido: limparApelido(texto('apelido', '')),
    );
  }

  bool igual(CarroPersonalizado o) {
    final a = paraMapa(), b = o.paraMapa();
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }
}

class CarroPublico {
  const CarroPublico({
    required this.uid,
    required this.dono,
    required this.carro,
    this.nivel,
    this.codigo,
    this.atualizadoEm,
    this.meu = false,
    this.exemplo = false,
  });

  final String uid;

  final String dono;
  final CarroPersonalizado carro;

  final int? nivel;
  final String? codigo;
  final DateTime? atualizadoEm;

  final bool meu;

  final bool exemplo;

  bool get noMapa => nivel != null && codigo != null;
}
