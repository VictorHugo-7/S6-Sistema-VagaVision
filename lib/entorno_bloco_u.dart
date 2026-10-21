import 'projecao.dart';
import 'theme.dart';

/// Retângulo no chão, em metros, nas coordenadas da planta do campus.
///
/// A planta foi girada 46° para alinhar a fileira de vagas na horizontal
/// (escala medida: ~7,4 px por metro, usando a vaga de 2,50 m como régua).
/// Origem no canto noroeste da fileira dupla; X segue a fileira (leste) e Z vai para o sul.
class AreaPlanta {
  const AreaPlanta(this.x0, this.x1, this.z0, this.z1);

  final double x0, x1, z0, z1;

  /// Centro já convertido para a cena (que é centrada no trecho em foco).
  double get cx => (x0 + x1) / 2 - EntornoBlocoU.origemX;
  double get cz => (z0 + z1) / 2 - EntornoBlocoU.origemZ;
  double get largura => x1 - x0;
  double get profundidade => z1 - z0;
}

class PredioPlanta {
  const PredioPlanta(this.area, this.altura);

  final AreaPlanta area;
  final double altura;

  V3 get centro => V3(area.cx, altura / 2, area.cz);
  V3 get tamanho => V3(area.largura, altura, area.profundidade);
}

/// Entorno real do estacionamento do Bloco U (trecho noroeste da fileira dupla).
/// As alturas dos prédios são estimadas (3,5 m por andar); a planta não informa andares.
class EntornoBlocoU {
  /// Centro do trecho em foco nas coordenadas da planta.
  static const origemX = ConfigPatio.cols * ConfigPatio.spotW / 2;
  static const origemZ = ConfigPatio.spotD + ConfigPatio.aisle / 2;

  static const vagasPorFileira = 42;
  static const comprimentoFileira = vagasPorFileira * ConfigPatio.spotW;
  static const profundidadeFileira = 2 * ConfigPatio.spotD + ConfigPatio.aisle;

  static const chao = AreaPlanta(-80, 140, -80, 90);

  static const vias = [
    AreaPlanta(-12, 125, -7.0, -2.6), // via ao norte da fileira
    AreaPlanta(-7.8, -1.5, -30, 70), // via a oeste (entre o prédio e a fileira)
    AreaPlanta(0, 108, profundidadeFileira, 17.4), // corredor ao sul da fileira
    AreaPlanta(59.6, 108, 17.4, 19.2),
    AreaPlanta(-12, 82, -27.8, -24.1), // via entre os prédios do norte
    AreaPlanta(107, 121, -30, 70), // via a leste
  ];

  static const calcadas = [
    AreaPlanta(-12, 107, -2.6, 0),
    AreaPlanta(-12, 82, -8.9, -7.0),
    AreaPlanta(-9.3, -7.8, -7.0, 32),
    AreaPlanta(-1.5, 0, -2.6, 17.4),
  ];

  static const fileiras = [
    AreaPlanta(0, comprimentoFileira, 0, profundidadeFileira), // fileira dupla (foco na ponta oeste)
    AreaPlanta(60.3, 106.9, 19.2, 24.7), // fileira sul
  ];

  /// Canteiro entre as duas fileiras, que ficam de costas uma para a outra.
  static const canteiro = AreaPlanta(0, comprimentoFileira, ConfigPatio.spotD, ConfigPatio.spotD + ConfigPatio.aisle);

  static const predios = [
    PredioPlanta(AreaPlanta(-45.8, -9.3, -5.5, 31.6), 10.5), // bloco a oeste
    PredioPlanta(AreaPlanta(-8.6, 14.3, -19.7, -9.6), 7), // prédio ao norte (3 volumes)
    PredioPlanta(AreaPlanta(14.3, 50.1, -24.1, -8.9), 10.5),
    PredioPlanta(AreaPlanta(50.1, 79.2, -19.7, -9.6), 7),
    PredioPlanta(AreaPlanta(22.4, 50.8, -48.1, -28.5), 10.5), // prédio do triângulo
    PredioPlanta(AreaPlanta(24.5, 46.1, -54.9, -48.1), 7),
    PredioPlanta(AreaPlanta(13.6, 19.1, -47.4, -40), 3), // guarita
    PredioPlanta(AreaPlanta(0.8, 59.6, 17.4, 45.8), 10.5), // bloco ao sul
    PredioPlanta(AreaPlanta(0.8, 40.7, 45.8, 66.8), 7),
    PredioPlanta(AreaPlanta(40.7, 58.9, 45.8, 64), 10.5),
  ];

  /// Divisórias das vagas fora do foco (resto da fileira dupla e fileira sul), só para contexto.
  static final List<AreaPlanta> divisoriasContexto = _gerarDivisorias();

  static List<AreaPlanta> _gerarDivisorias() {
    const meia = 0.06;
    const w = ConfigPatio.spotW;
    const d = ConfigPatio.spotD;
    final saida = <AreaPlanta>[];
    for (var i = ConfigPatio.cols; i <= vagasPorFileira; i++) {
      final x = i * w;
      saida
        ..add(AreaPlanta(x - meia, x + meia, 0, d))
        ..add(AreaPlanta(x - meia, x + meia, profundidadeFileira - d, profundidadeFileira));
    }
    for (var x = 60.3; x <= 106.9; x += w) {
      saida.add(AreaPlanta(x - meia, x + meia, 19.2, 24.7));
    }
    return saida;
  }
}
