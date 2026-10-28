import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Estado da reprodução informado pelo detector (`GET /estado` do visao/controle_remoto.py).
class EstadoCamera {
  const EstadoCamera({
    required this.pausado,
    required this.posicao,
    required this.duracao,
    required this.velocidade,
    required this.livres,
    required this.ocupadas,
  });

  final bool pausado;
  final double posicao;
  final double duracao;
  final double velocidade;
  final int livres;
  final int ocupadas;

  static EstadoCamera doJson(Map<String, dynamic> j) {
    double numero(Object? v) => v is num ? v.toDouble() : 0;
    return EstadoCamera(
      pausado: j['pausado'] == true,
      posicao: numero(j['posicao']),
      duracao: numero(j['duracao']),
      velocidade: j['velocidade'] is num ? numero(j['velocidade']) : 1,
      livres: numero(j['livres']).toInt(),
      ocupadas: numero(j['ocupadas']).toInt(),
    );
  }
}

/// Conversa com o controle remoto do detector: vídeo, estado e comandos de reprodução.
class ControleCamera {
  ControleCamera(this.base, {http.Client? cliente}) : _cliente = cliente ?? http.Client();

  /// Ex.: http://192.168.0.10:8765 (vem do campo `controle` do documento no Firestore).
  final String base;
  final http.Client _cliente;

  Future<EstadoCamera> estado() async {
    final r = await _cliente.get(Uri.parse('$base/estado')).timeout(const Duration(seconds: 3));
    return EstadoCamera.doJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Próximo quadro mais novo que [depoisDe] (o detector segura o pedido até ter um).
  Future<({Uint8List jpeg, int numero})> quadro(int depoisDe) async {
    final r = await _cliente.get(Uri.parse('$base/quadro.jpg?n=$depoisDe')).timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) throw http.ClientException('sem vídeo (${r.statusCode})');
    return (jpeg: r.bodyBytes, numero: int.tryParse(r.headers['x-quadro'] ?? '') ?? depoisDe + 1);
  }

  /// acao: pausar, continuar, alternar, reiniciar, pular (valor em segundos), ir (segundo
  /// do vídeo) ou velocidade (0.5, 1, 2, 4).
  Future<void> comando(String acao, [num? valor]) async {
    final uri = Uri.parse('$base/comando').replace(queryParameters: {
      'acao': acao,
      if (valor != null) 'valor': '$valor',
    });
    await _cliente.post(uri).timeout(const Duration(seconds: 3));
  }

  void fechar() => _cliente.close();
}

/// Janela flutuante com o vídeo da câmera e os controles de reprodução, por cima do app.
/// Dá para arrastar pela barra de título e redimensionar pelo canto.
class JanelaCamera {
  static OverlayEntry? _aberta;

  static bool get aberta => _aberta != null;

  static void abrir(BuildContext context, String url, {String titulo = 'Câmera'}) {
    fechar();
    _aberta = OverlayEntry(builder: (_) => _JanelaCamera(url: url, titulo: titulo, aoFechar: fechar));
    Overlay.of(context, rootOverlay: true).insert(_aberta!);
  }

  static void fechar() {
    _aberta?.remove();
    _aberta = null;
  }
}

class _JanelaCamera extends StatefulWidget {
  const _JanelaCamera({required this.url, required this.titulo, required this.aoFechar});

  final String url;
  final String titulo;
  final VoidCallback aoFechar;

  @override
  State<_JanelaCamera> createState() => _JanelaCameraState();
}

class _JanelaCameraState extends State<_JanelaCamera> {
  static const _fundo = Color(0xFF15181E);
  static const _borda = Color(0xFF2B303B);
  static const _texto = Color(0xFFE6E8EC);
  static const _fraco = Color(0xFF9AA3B2);
  static const _verde = Color(0xFF22C55E);
  static const _vermelho = Color(0xFFEF4444);
  static const _velocidades = [0.5, 1.0, 2.0, 4.0];
  static const _larguraMin = 280.0;

  late final _controle = ControleCamera(widget.url);
  late final Timer _relogioEstado;
  bool _ativa = true;
  Offset? _posicao;
  double? _largura;
  Uint8List? _imagem;
  int _numero = -1;
  EstadoCamera? _estado;
  bool _semConexao = false;
  double? _arrastandoPara; // posição escolhida na barra enquanto o dedo está nela

  @override
  void initState() {
    super.initState();
    _buscarQuadros();
    _relogioEstado = Timer.periodic(const Duration(milliseconds: 500), (_) => _buscarEstado());
    _buscarEstado();
  }

  @override
  void dispose() {
    _ativa = false;
    _relogioEstado.cancel();
    _controle.fechar();
    super.dispose();
  }

  /// Pede um quadro atrás do outro; o detector manda no máximo ~12 por segundo.
  Future<void> _buscarQuadros() async {
    while (_ativa) {
      try {
        final q = await _controle.quadro(_numero);
        if (!_ativa) return;
        setState(() {
          _imagem = q.jpeg;
          _numero = q.numero;
          _semConexao = false;
        });
      } catch (_) {
        if (!_ativa) return;
        setState(() => _semConexao = true);
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _buscarEstado() async {
    try {
      final e = await _controle.estado();
      if (_ativa) setState(() => _estado = e);
    } catch (_) {
      // a falta de vídeo já mostra o aviso de conexão
    }
  }

  Future<void> _comando(String acao, [num? valor]) async {
    try {
      await _controle.comando(acao, valor);
      await _buscarEstado();
    } catch (_) {
      if (_ativa) setState(() => _semConexao = true);
    }
  }

  void _abrirEmNovaAba() =>
      launchUrl(Uri.parse(widget.url), webOnlyWindowName: '_blank', mode: LaunchMode.externalApplication);

  static String _tempo(double s) {
    final t = s.isFinite ? math.max(0, s.floor()) : 0;
    return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.sizeOf(context);
    final margem = MediaQuery.paddingOf(context);
    final largura =
        (_largura ?? math.min(560.0, tela.width - 24)).clamp(math.min(_larguraMin, tela.width), tela.width).toDouble();
    // começa no canto de baixo à direita (no celular, em cima, para não tapar os botões)
    final inicial = tela.width < 600
        ? Offset((tela.width - largura) / 2, margem.top + 12)
        : Offset(tela.width - largura - 24, tela.height - largura * 9 / 16 - 180);
    final pos = _posicao ?? inicial;
    final x = pos.dx.clamp(0.0, math.max(0.0, tela.width - largura)).toDouble();
    final y = pos.dy.clamp(margem.top, math.max(margem.top, tela.height - 80)).toDouble();

    return Positioned(
      left: x,
      top: y,
      width: largura,
      child: Material(
        color: _fundo,
        elevation: 16,
        shadowColor: Colors.black,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: DefaultTextStyle(
          style: const TextStyle(color: _texto, fontSize: 13),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _barraTitulo(Offset(x, y)),
                  _video(),
                  _controles(),
                ],
              ),
              Positioned(right: 0, bottom: 0, child: _alcaRedimensionar(largura, tela.width)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraTitulo(Offset atual) {
    final e = _estado;
    return GestureDetector(
      onPanUpdate: (d) => setState(() => _posicao = (_posicao ?? atual) + d.delta),
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Container(
          padding: const EdgeInsets.only(left: 12, right: 4),
          height: 40,
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borda))),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator_rounded, size: 16, color: _fraco),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: _semConexao ? _fraco : _vermelho, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _semConexao ? '${widget.titulo} · sem conexão' : widget.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (e != null && !_semConexao)
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${e.livres}', style: const TextStyle(color: _verde, fontWeight: FontWeight.w700)),
                    const TextSpan(text: ' livres · ', style: TextStyle(color: _fraco)),
                    TextSpan(text: '${e.ocupadas}', style: const TextStyle(color: _vermelho, fontWeight: FontWeight.w700)),
                    const TextSpan(text: ' ocup.', style: TextStyle(color: _fraco)),
                  ]),
                  style: const TextStyle(fontSize: 12),
                ),
              _BotaoIcone(icone: Icons.open_in_new_rounded, dica: 'Abrir em outra aba', onTap: _abrirEmNovaAba),
              _BotaoIcone(icone: Icons.close_rounded, dica: 'Fechar', onTap: widget.aoFechar),
            ],
          ),
        ),
      ),
    );
  }

  Widget _video() {
    final imagem = _imagem;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imagem != null) Image.memory(imagem, gaplessPlayback: true, fit: BoxFit.contain),
            if (imagem == null || _semConexao)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _semConexao
                        ? 'Sem conexão com o detector em ${widget.url}.\n'
                            'Ele está rodando? O aparelho está no mesmo Wi-Fi do computador?'
                        : 'Carregando o vídeo...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _fraco),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _controles() {
    final e = _estado;
    final duracao = e?.duracao ?? 0;
    final posicao = _arrastandoPara ?? e?.posicao ?? 0;
    final habilitado = e != null && !_semConexao;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: _verde,
                    inactiveTrackColor: _borda,
                    thumbColor: _verde,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: duracao > 0 ? posicao.clamp(0, duracao) : 0,
                    max: duracao > 0 ? duracao : 1,
                    onChanged: habilitado && duracao > 0 ? (v) => setState(() => _arrastandoPara = v) : null,
                    onChangeEnd: (v) {
                      _comando('ir', v);
                      setState(() => _arrastandoPara = null);
                    },
                  ),
                ),
              ),
              Text('${_tempo(posicao)} / ${_tempo(duracao)}',
                  style: const TextStyle(color: _fraco, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BotaoIcone(icone: Icons.skip_previous_rounded, dica: 'Voltar ao início', onTap: habilitado ? () => _comando('reiniciar') : null),
                  _BotaoIcone(icone: Icons.replay_10_rounded, dica: 'Voltar 10 s', onTap: habilitado ? () => _comando('pular', -10) : null),
                  _BotaoIcone(
                    icone: (e?.pausado ?? false) ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    dica: (e?.pausado ?? false) ? 'Continuar' : 'Pausar',
                    grande: true,
                    onTap: habilitado ? () => _comando('alternar') : null,
                  ),
                  _BotaoIcone(icone: Icons.forward_10_rounded, dica: 'Avançar 10 s', onTap: habilitado ? () => _comando('pular', 10) : null),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final v in _velocidades)
                    _ChipVelocidade(
                      rotulo: '${v == v.roundToDouble() ? v.toInt() : v.toString().replaceAll('.', ',')}x',
                      ativo: e?.velocidade == v,
                      onTap: habilitado ? () => _comando('velocidade', v) : null,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alcaRedimensionar(double largura, double larguraTela) {
    return GestureDetector(
      onPanUpdate: (d) =>
          setState(() => _largura = (largura + d.delta.dx).clamp(math.min(_larguraMin, larguraTela), larguraTela)),
      child: const MouseRegion(
        cursor: SystemMouseCursors.resizeDownRight,
        child: Tooltip(
          message: 'Arraste para mudar o tamanho',
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.open_in_full_rounded, size: 14, color: _fraco),
          ),
        ),
      ),
    );
  }
}

class _BotaoIcone extends StatelessWidget {
  const _BotaoIcone({required this.icone, required this.dica, required this.onTap, this.grande = false});

  final IconData icone;
  final String dica;
  final VoidCallback? onTap;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icone),
      tooltip: dica,
      onPressed: onTap,
      iconSize: grande ? 30 : 22,
      color: _JanelaCameraState._texto,
      disabledColor: _JanelaCameraState._borda,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ChipVelocidade extends StatelessWidget {
  const _ChipVelocidade({required this.rotulo, required this.ativo, required this.onTap});

  final String rotulo;
  final bool ativo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: ativo ? _JanelaCameraState._verde : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ativo ? _JanelaCameraState._verde : _JanelaCameraState._borda),
          ),
          child: Text(
            rotulo,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ativo ? const Color(0xFF04130A) : _JanelaCameraState._texto,
            ),
          ),
        ),
      ),
    );
  }
}
