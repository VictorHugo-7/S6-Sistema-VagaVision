import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta extraída do protótipo do Figma.
class Cores {
  static const azul = Color(0xFF203D65);
  static const azulEscuro = Color(0xFF0E294F);
  static const azulLateral = Color(0xFF162F52);
  static const azulBotao = Color(0xFF124BBD);
  static const folha = Color(0xFFF6F8FA);
  static const livre = Color(0xFF6BB74D);
  static const ocupada = Color(0xFFD33F3F);
  static const barra = Color(0xFFF3F33C);
  static const ativo = Color(0xFF267A18);
  static const cinza = Color(0xFFB8B8B8);
  // contraste mínimo de 4.5:1 sobre branco/folha (WCAG AA); o Figma usava #8C8C8C
  static const cinzaTexto = Color(0xFF5F6670);
  static const campo = Color(0xFFF2F2F2);
  static const texto = Color(0xFF111111);
  static const alertaSimples = Color(0xFFF3C33C);
  static const alertaMedio = Color(0xFFF08A24);

  // cena 3D
  static const piso3d = Color(0xFF2A4A78);
  static const via3d = Color(0xFF264470);
  static const coluna3d = Color(0xFF3C5A85);
  static const chao3d = Color(0xFF1A3459);
  static const calcada3d = Color(0xFF3A5B88);
  static const canteiro3d = Color(0xFF2E5A55);
  static const predio3d = Color(0xFF9DB1CC);
}

/// Área mínima de toque recomendada (Material / HIG).
const double alvoToque = 44;

/// Texto padrão (IBM Plex Mono). Sem [cor], herda a cor do tema (clara ou escura).
TextStyle mono(double tamanho, {FontWeight peso = FontWeight.w500, Color? cor}) =>
    GoogleFonts.ibmPlexMono(fontSize: tamanho, fontWeight: peso, color: cor);

/// Cores que mudam entre o modo claro e o escuro. Use `context.paleta` (se a cor não
/// estiver aqui, ela é igual nos dois modos e continua em [Cores]).
class Paleta extends ThemeExtension<Paleta> {
  const Paleta({
    required this.fundo,
    required this.lateral,
    required this.profundo,
    required this.superficie,
    required this.folha,
    required this.texto,
    required this.textoSuave,
    required this.campo,
    required this.destaque,
    required this.moldura,
  });

  final Color fundo; // fundo das telas
  final Color lateral; // menu lateral / trilho
  final Color profundo; // splash e topo do login
  final Color superficie; // cartões, barra inferior, pílulas
  final Color folha; // folha do login
  final Color texto;
  final Color textoSuave;
  final Color campo;
  final Color destaque; // o azul usado em ícones/linhas sobre a superfície
  final Color moldura; // contorno do mapa

  static const claro = Paleta(
    fundo: Cores.azul,
    lateral: Cores.azulLateral,
    profundo: Cores.azulEscuro,
    superficie: Colors.white,
    folha: Cores.folha,
    texto: Cores.texto,
    textoSuave: Cores.cinzaTexto,
    campo: Cores.campo,
    destaque: Cores.azul,
    moldura: Colors.white,
  );

  static const escuro = Paleta(
    fundo: Color(0xFF0B1626),
    lateral: Color(0xFF070F1B),
    profundo: Color(0xFF050B14),
    superficie: Color(0xFF16233A),
    folha: Color(0xFF111C2E),
    texto: Color(0xFFE8ECF3),
    textoSuave: Color(0xFF9AA7BD),
    campo: Color(0xFF1E2C46),
    destaque: Color(0xFF8FB4FF),
    moldura: Color(0xFF5B7399),
  );

  @override
  Paleta copyWith({Color? fundo, Color? lateral, Color? profundo, Color? superficie, Color? folha, Color? texto,
          Color? textoSuave, Color? campo, Color? destaque, Color? moldura}) =>
      Paleta(
        fundo: fundo ?? this.fundo,
        lateral: lateral ?? this.lateral,
        profundo: profundo ?? this.profundo,
        superficie: superficie ?? this.superficie,
        folha: folha ?? this.folha,
        texto: texto ?? this.texto,
        textoSuave: textoSuave ?? this.textoSuave,
        campo: campo ?? this.campo,
        destaque: destaque ?? this.destaque,
        moldura: moldura ?? this.moldura,
      );

  @override
  Paleta lerp(ThemeExtension<Paleta>? other, double t) {
    if (other is! Paleta) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Paleta(
      fundo: l(fundo, other.fundo),
      lateral: l(lateral, other.lateral),
      profundo: l(profundo, other.profundo),
      superficie: l(superficie, other.superficie),
      folha: l(folha, other.folha),
      texto: l(texto, other.texto),
      textoSuave: l(textoSuave, other.textoSuave),
      campo: l(campo, other.campo),
      destaque: l(destaque, other.destaque),
      moldura: l(moldura, other.moldura),
    );
  }
}

extension PaletaDoContexto on BuildContext {
  Paleta get paleta => Theme.of(this).extension<Paleta>() ?? Paleta.claro;
}

/// Tema do app para o modo escolhido.
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

class ConfigPatio {
  // Trecho do estacionamento do Bloco U em escala real (medido na planta do campus):
  // duas fileiras de costas uma para a outra, separadas por um canteiro central.
  static const cols = 6;
  static const spotW = 2.5;
  static const spotD = 5.0;
  static const aisle = 3.8; // largura do canteiro entre as fileiras
  static const numNiveis = 2;

  static const larguraPatio = cols * spotW + 4;
  static const profundidadePatio = aisle + 2 * spotD + 4;

  // vista 2D (estilo do Figma): vagas mais estreitas, divisórias e moldura
  static const vagaLarg2d = spotW * 0.67;
  static const vagaProf2d = spotD - 0.6;
  static const quadroMeiaLargura = (cols / 2 - 0.165) * spotW + 0.55;
  static const quadroMeiaAltura = aisle / 2 + spotD - 0.3 + 0.55;
}
