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
}

/// Área mínima de toque recomendada (Material / HIG).
const double alvoToque = 44;

TextStyle mono(double tamanho, {FontWeight peso = FontWeight.w500, Color cor = Cores.texto}) =>
    GoogleFonts.ibmPlexMono(fontSize: tamanho, fontWeight: peso, color: cor);

class ConfigPatio {
  static const cols = 5;
  static const spotW = 2.6;
  static const spotD = 4.4;
  static const aisle = 12.0;
  static const numNiveis = 2;

  static const larguraPatio = cols * spotW + 4;
  static const profundidadePatio = aisle + 2 * spotD + 4;

  // vista 2D (estilo do Figma): vagas mais estreitas, divisórias e moldura
  static const vagaLarg2d = spotW * 0.67;
  static const vagaProf2d = spotD - 0.6;
  static const quadroMeiaLargura = (cols / 2 - 0.165) * spotW + 0.55;
  static const quadroMeiaAltura = aisle / 2 + spotD - 0.3 + 0.55;
}
