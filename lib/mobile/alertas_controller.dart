import 'package:flutter/foundation.dart';

class ItemAlerta {
  ItemAlerta(this.nome, {this.ativo = false});

  final String nome;

  /// Pílula da direita no Figma (verde = alerta ligado).
  bool ativo;

  /// Quadradinho cinza da esquerda no Figma (função ainda a definir).
  bool secundario = false;
}

/// Estado da tela "Ativar alertas".
class AlertasController extends ChangeNotifier {
  // No Figma são 11 linhas "Bloco U"; troque os nomes aqui quando tiver os blocos reais.
  AlertasController() : itens = List.generate(11, (i) => ItemAlerta('Bloco U', ativo: i == 0));

  final List<ItemAlerta> itens;

  void alternarAlerta(int i) {
    itens[i].ativo = !itens[i].ativo;
    notifyListeners();
  }

  void alternarSecundario(int i) {
    itens[i].secundario = !itens[i].secundario;
    notifyListeners();
  }
}
