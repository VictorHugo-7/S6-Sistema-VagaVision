import 'package:flutter/material.dart';

import 'alertas_controller.dart';
import 'alertas_pagina.dart';
import 'garagem_controller.dart';
import 'garagem_scene.dart';
import 'hud.dart';
import 'quadro_tela.dart';

/// Tela "Mapa" (garagem 3D), exibida depois do login.
class GaragemPagina extends StatefulWidget {
  const GaragemPagina({super.key, this.onSair});

  final VoidCallback? onSair;

  @override
  State<GaragemPagina> createState() => _GaragemPaginaState();
}

class _GaragemPaginaState extends State<GaragemPagina> {
  final _controller = GaragemController();
  final _alertas = AlertasController();

  @override
  void dispose() {
    _controller.dispose();
    _alertas.dispose();
    super.dispose();
  }

  void _abrirAlertas() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AlertasPagina(controller: _alertas)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return QuadroTela(
      titulo: 'Mapa',
      icone: const Icon(Icons.location_on, color: Colors.white, size: 36),
      child: Stack(
        children: [
          Positioned.fill(child: GaragemScene(controller: _controller)),
          Positioned.fill(
            child: Hud(controller: _controller, onAlertas: _abrirAlertas, onSair: widget.onSair),
          ),
        ],
      ),
    );
  }
}
