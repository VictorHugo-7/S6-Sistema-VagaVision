import 'package:flutter/material.dart';

/// Paleta tirada do Figma do VagaVision.
class Cores {
  static const fundo = Color(0xFF203D65); // azul-marinho de fundo
  static const moldura = Color(0xFFFBFBFB); // linha branca das molduras
  static const branco = Color(0xFFFFFFFF);
  static const preto = Color(0xFF000000);
  static const livre = Color(0xFF6BB74D); // vaga livre (verde)
  static const ocupada = Color(0xFFD33F3F); // vaga ocupada (vermelho)
  static const barra = Color(0xFFF0F340); // amarelo da barra "Vagas Disponíveis"
  static const azulBotao = Color(0xFF124BBD); // botões "Alertas" e "Voltar"
  static const cinza = Color(0xFFB7B7B7); // interruptores desligados
  static const divisor = Color(0xFFD9D9D9); // linhas entre as vagas
  static const ativo = Color(0xFF287A18); // interruptor ligado (verde escuro)
}

/// Medidas do pátio em unidades do mundo 3D (proporções do Figma: vaga 92x134).
class ConfigPatio {
  static const cols = 5; // vagas por fileira
  static const vagaW = 2.6; // largura da vaga
  static const vagaD = 3.8; // profundidade da vaga
  static const passo = 3.9; // distância entre o centro de vagas vizinhas
  static const aisle = 11.8; // corredor entre as duas fileiras (proporção do Figma)
  static const margem = 1.0; // folga entre as vagas e a moldura branca
  static const numNiveis = 2;

  static const larguraPatio = (cols - 1) * passo + vagaW + 2 * margem;
  static const profundidadePatio = aisle + 2 * vagaD + 2 * margem;
}

/// Cores que mudam entre o modo claro e o escuro (use `context.paleta`).
class Paleta extends ThemeExtension<Paleta> {
  const Paleta({
    required this.fundo,
    required this.superficie,
    required this.folha,
    required this.texto,
    required this.textoSuave,
    required this.borda,
    required this.moldura,
    required this.divisor,
    required this.destaque,
    required this.campo,
  });

  final Color fundo; // fundo azul das telas e da cena
  final Color superficie; // pílulas, cartões, folha inferior
  final Color folha; // folha do login
  final Color texto;
  final Color textoSuave;
  final Color borda; // contorno preto dos botões do mapa
  final Color moldura; // linha do quadro e do pátio
  final Color divisor; // linhas entre as vagas
  final Color destaque; // o azul-marinho usado em barras e ícones sobre a superfície
  final Color campo;

  static const claro = Paleta(
    fundo: Cores.fundo,
    superficie: Cores.branco,
    folha: Color(0xFFF6F8FA),
    texto: Cores.preto,
    textoSuave: Color(0xFF8B929C),
    borda: Cores.preto,
    moldura: Cores.moldura,
    divisor: Cores.divisor,
    destaque: Cores.fundo,
    campo: Color(0xFFF2F2F2),
  );

  static const escuro = Paleta(
    fundo: Color(0xFF0B1626),
    superficie: Color(0xFF16233A),
    folha: Color(0xFF111C2E),
    texto: Color(0xFFE8ECF3),
    textoSuave: Color(0xFF9AA7BD),
    borda: Color(0xFF5B7399),
    moldura: Color(0xFF8FA3C4),
    divisor: Color(0xFF2C3E5C),
    destaque: Color(0xFF8FB4FF),
    campo: Color(0xFF1E2C46),
  );

  @override
  Paleta copyWith({Color? fundo, Color? superficie, Color? folha, Color? texto, Color? textoSuave, Color? borda,
          Color? moldura, Color? divisor, Color? destaque, Color? campo}) =>
      Paleta(
        fundo: fundo ?? this.fundo,
        superficie: superficie ?? this.superficie,
        folha: folha ?? this.folha,
        texto: texto ?? this.texto,
        textoSuave: textoSuave ?? this.textoSuave,
        borda: borda ?? this.borda,
        moldura: moldura ?? this.moldura,
        divisor: divisor ?? this.divisor,
        destaque: destaque ?? this.destaque,
        campo: campo ?? this.campo,
      );

  @override
  Paleta lerp(ThemeExtension<Paleta>? other, double t) {
    if (other is! Paleta) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Paleta(
      fundo: l(fundo, other.fundo),
      superficie: l(superficie, other.superficie),
      folha: l(folha, other.folha),
      texto: l(texto, other.texto),
      textoSuave: l(textoSuave, other.textoSuave),
      borda: l(borda, other.borda),
      moldura: l(moldura, other.moldura),
      divisor: l(divisor, other.divisor),
      destaque: l(destaque, other.destaque),
      campo: l(campo, other.campo),
    );
  }
}

extension PaletaDoContexto on BuildContext {
  Paleta get paleta => Theme.of(this).extension<Paleta>() ?? Paleta.claro;
}

ThemeData temaDoApp(Paleta p, Brightness brilho) => ThemeData(
      useMaterial3: true,
      brightness: brilho,
      scaffoldBackgroundColor: p.fundo,
      colorScheme: ColorScheme.fromSeed(seedColor: Cores.azulBotao, brightness: brilho).copyWith(
        onSurface: p.texto,
        surface: p.superficie,
      ),
      extensions: [p],
    );
