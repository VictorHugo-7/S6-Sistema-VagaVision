import 'dart:async';

import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../carros_usuario.dart';
import '../estacionamentos.dart';
import '../localizacao.dart';
import '../meu_carro.dart';
import '../notificacoes.dart';
import '../ocupacao_ao_vivo.dart';
import '../tema_controller.dart';
import '../widget_inicial.dart';
import 'alertas_controller.dart';
import 'alertas_pagina.dart';
import 'avisos_pagina.dart';
import '../garagem_controller.dart';
import '../garagem_scene.dart';
import 'hud.dart';
import 'onde_parei_pagina.dart';
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
  // carros personalizados dos usuários, desenhados nas vagas como no site
  // carros do usuário (placa/modelo/cor) e registros de onde ele parou: vêm da API (MongoDB)
  final _carrosUsuario = CarrosUsuarioController();
  late final _estacionamentos = EstacionamentosController(meuCarro: _meuCarro);
  // ocupação detectada pela câmera (visao/detectar_ocupacao.py --firebase); esta tela só
  // aparece com usuário logado, que é o que as regras do Firestore exigem
  late final _aoVivo = OcupacaoAoVivo(_controller.aplicarLeitura);
  final _campus = LocalizacaoCampus();
  Timer? _amostragem;
  late int _livresAntes = _controller.stats.livres;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_verificarAvisos);
    _aoVivo.iniciar();
    _meuCarro.carregar();
    if (AuthService.pronto) {
      // as rotas da API exigem login; esta tela só aparece com usuário logado
      _carrosUsuario.carregar();
      _estacionamentos.carregar();
    }
    // sem avisos com o carro já estacionado ou quando o usuário está fora da faculdade
    widget.notif.motivoBloqueio = () => motivoSemAviso(
          carro: _meuCarro,
          campus: _campus,
          somenteNaFaculdade: widget.notif.somenteNaFaculdade,
        );
    _campus.iniciar(); // pede a localização ao entrar no mapa (já logado)
    // atualiza o widget da tela inicial (Android) a cada 5 min, além das mudanças
    _amostragem = Timer.periodic(const Duration(minutes: 5), (_) => _amostrar());
    _amostrar();
  }

  /// Atualiza o widget da tela inicial (Android) com a ocupação de agora.
  void _amostrar() {
    final stats = _controller.stats;
    WidgetInicial.atualizar(livres: stats.livres, total: stats.total);
  }

  /// Avisa cada vaga desocupada (se a chave dos Avisos estiver ligada) e, com algum alerta
  /// ligado, avisa também quando o pátio lota.
  void _verificarAvisos() {
    _amostrar();
    final ativos = _alertas.itens.where((i) => i.ativo);
    final bloco = ativos.isEmpty ? 'Bloco U' : ativos.first.nome;
    final vs = _controller.vagas;
    widget.notif.vagasDesocupadas(
      bloco,
      _vagas.desocupadas([for (final v in vs) v.code], [for (final v in vs) v.ocupada]),
    );
    final livres = _controller.stats.livres;
    final antes = _livresAntes;
    _livresAntes = livres;
    if (livres == antes || ativos.isEmpty) return;
    if (livres == 0) {
      widget.notif.adicionar('$bloco lotado', 'Sem vagas livres no pátio.', tipo: TipoNotificacao.critico);
    }
  }

  @override
  void dispose() {
    _amostragem?.cancel();
    _aoVivo.parar();
    _carrosUsuario.dispose();
    _estacionamentos.dispose();
    _controller.removeListener(_verificarAvisos);
    widget.notif.motivoBloqueio = null;
    _meuCarro.dispose();
    _campus.dispose();
    _controller.dispose();
    _alertas.dispose();
    super.dispose();
  }

  void _abrirAlertas() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AlertasPagina(controller: _alertas)),
    );
  }

  void _abrirOndeParei() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OndePareiPagina(
          controller: _controller,
          meuCarro: _meuCarro,
          carros: _carrosUsuario,
          estacionamentos: _estacionamentos,
        ),
      ),
    );
  }

  void _abrirAvisos() {
    _campus.verificar(); // atualiza a localização ao abrir os avisos
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AvisosPagina(notif: widget.notif, campus: _campus, meuCarro: _meuCarro),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return QuadroTela(
      titulo: 'Mapa',
      icone: const Icon(Icons.location_on, color: Colors.white, size: 36),
      child: Stack(
        children: [
          // a cena é a mesma do site; fica entre os botões de cima e a faixa de baixo do HUD
          // para o pátio não ficar escondido atrás deles
          Positioned(
            left: 0,
            right: 0,
            top: 210,
            bottom: 70,
            child: GaragemScene(controller: _controller, meuCarro: _meuCarro),
          ),
          Positioned.fill(
            child: Hud(
              controller: _controller,
              carrosUsuario: _carrosUsuario,
              estacionamentos: _estacionamentos,
              tema: widget.tema,
              notif: widget.notif,
              meuCarro: _meuCarro,
              onAlertas: _abrirAlertas,
              onAvisos: _abrirAvisos,
              onPainel: _abrirOndeParei,
              onSair: widget.onSair,
            ),
          ),
        ],
      ),
    );
  }
}
