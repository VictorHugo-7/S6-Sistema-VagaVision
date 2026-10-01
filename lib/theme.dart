import 'package:flutter/material.dart';

class Cores {
  static const asfalto = Color(0xFF23262B);
  static const fundoCena = Color(0xFF1C1E22);
  static const amarelo = Color(0xFFF2B134);
  static const livre = Color(0xFF36B37E);
  static const livreDim = Color(0xFF1F6B4C);
  static const ocupada = Color(0xFFE0524A);
  static const texto = Color(0xFFF3F0E8);
  static const textoFraco = Color(0xFFA8AAB0);
  static const textoSobreAmarelo = Color(0xFF23200F);
  static const painel = Color.fromRGBO(30, 32, 37, 0.92);
  static const borda = Color.fromRGBO(255, 255, 255, 0.09);
}

class ConfigPatio {
  static const cols = 10;
  static const spotW = 2.6;
  static const spotD = 4.8;
  static const aisle = 6.4;
  static const numNiveis = 2;

  static const larguraPatio = cols * spotW + 4;
  static const profundidadePatio = aisle + 2 * spotD + 4;
}
