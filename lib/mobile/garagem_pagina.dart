import 'dart:async';

import 'package:flutter/material.dart';

import '../historico.dart';
import '../meu_carro.dart';
import '../notificacoes.dart';
import '../tema_controller.dart';
import '../widget_inicial.dart';
import 'alertas_controller.dart';
import 'alertas_pagina.dart';
import 'avisos_pagina.dart';
import 'garagem_controller.dart';
import 'garagem_scene.dart';
import 'hud.dart';
import 'painel_pagina.dart';
import 'quadro_tela.dart';

/// Tela "Mapa" (garagem 3D), exibida depois do login.
class GaragemPagina extends StatefulWidget {
  const GaragemPagina({super.key, required this.tema, required this.notif, this.onSair});

  final TemaController tema;
  final NotificacoesController notif;
  final VoidCallback? onSair;

  @override
  State<GaragemPagina> createState() => _GaragemPaginaState();
}

class _GaragemPaginaState extends State<GaragemPagina> {
  final _controller = GaragemController();
  final _alertas = AlertasController();
  final _vagas = RastreadorVagas();
  final _meuCarro = MeuCarro();
  final _historico = HistoricoOcupacao();
  Timer? _amostragem;
  late int _livresAntes = _controller.stats.livres;
  late int _nivelAntes = _controller.nivel;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_verificarAvisos);
    _meuCarro.carregar();
    _historico.carregar();
    // além das mudanças, registra a ocupação a cada 5 min (alimenta a previsão e o painel)
    _amostragem = Timer.periodic(const Duration(minutes: 5), (_) => _amostrar());
    _amostrar();
  }

  /// Guarda a ocupação no histórico e atualiza o widget da tela inicial (Android).
  void _amostrar() {
    final niveis = [
      for (final n in _controller.niveis) [for (final v in n) v.ocupada],
    ];
    _historico.registrar(ocupacaoGeral(niveis));
    final total = niveis.fold<int>(0, (s, n) => s + n.length);
    final ocupadas = niveis.fold<int>(0, (s, n) => s + n.where((o) => o).length);
    WidgetInicial.atualizar(livres: total - ocupadas, total: total);
  }

  /// Avisa cada vaga desocupada (se a chave dos Avisos estiver ligada) e, com algum alerta
  /// ligado, avisa também quando o nível lota.
  void _verificarAvisos() {
    _amostrar();
    final ativos = _alertas.itens.where((i) => i.ativo);
    final bloco = ativos.isEmpty ? 'Bloco U' : ativos.first.nome;
    for (var n = 0; n < _controller.niveis.length; n++) {
      final vs = _controller.niveis[n];
      final liberadas = _vagas.desocupadas(n, [for (final v in vs) v.code], [for (final v in vs) v.ocupada]);
      widget.notif.vagasDesocupadas(bloco, n + 1, liberadas);
    }
    final livres = _controller.stats.livres;
    final antes = _livresAntes;
    final nivelMudou = _controller.nivel != _nivelAntes;
    _nivelAntes = _controller.nivel;
    _livresAntes = livres;
    if (nivelMudou || livres == antes || ativos.isEmpty) return;
    if (livres == 0) {
      widget.notif.adicionar('$bloco lotado', 'Nível ${_controller.nivel + 1} sem vagas livres.',
          tipo: TipoNotificacao.critico);
    }
  }

  @override
  void dispose() {
    _amostragem?.cancel();
    _controller.removeListener(_verificarAvisos);
    _meuCarro.dispose();
    _historico.dispose();
    _controller.dispose();
    _alertas.dispose();
    super.dispose();
  }

  void _abrirAlertas() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AlertasPagina(controller: _alertas)),
    );
  }

  void _abrirPainel() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PainelPagina(historico: _historico, controller: _controller)),
    );
  }

  void _abrirAvisos() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AvisosPagina(notif: widget.notif)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return QuadroTela(
      titulo: 'Mapa',
      icone: const Icon(Icons.location_on, color: Colors.white, size: 36),
      child: Stack(
        children: [
          Positioned.fill(child: GaragemScene(controller: _controller, meuCarro: _meuCarro)),
          Positioned.fill(
            child: Hud(
              controller: _controller,
              tema: widget.tema,
              notif: widget.notif,
              meuCarro: _meuCarro,
              onAlertas: _abrirAlertas,
              onAvisos: _abrirAvisos,
              onPainel: _abrirPainel,
              onSair: widget.onSair,
            ),
          ),
        ],
      ),
    );
  }
}
