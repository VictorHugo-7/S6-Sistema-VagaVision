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
