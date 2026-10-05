import 'package:flutter/material.dart';

import 'garagem_controller.dart';
import 'garagem_scene.dart';
import 'hud.dart';

/// Tela principal (garagem 3D/2D), exibida depois do login.
class GaragemPagina extends StatefulWidget {
  const GaragemPagina({super.key, this.onSair});

  final VoidCallback? onSair;

  @override
  State<GaragemPagina> createState() => _GaragemPaginaState();
}

class _GaragemPaginaState extends State<GaragemPagina> {
  final _controller = GaragemController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: GaragemScene(controller: _controller)),
          Positioned.fill(child: Hud(controller: _controller, onSair: widget.onSair)),
        ],
      ),
    );
  }
}
