import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'janela_camera.dart';

/// Estado de uma vaga lido da câmera.
typedef LeituraVaga = ({bool ocupada, DateTime? desde});

/// Ocupação do pátio como está no banco (coleção `spots`), preenchida pelo detector
/// de visão computacional (visao/detectar_ocupacao.py --api).
class LeituraPatio {
  const LeituraPatio({
    required this.vagas,
    required this.atualizadoEm,
    this.fonte,
    this.controle,
  });

  final Map<String, LeituraVaga> vagas;

  /// Gravação mais recente do detector (vem do `updatedAt` das vagas).
  final DateTime atualizadoEm;

  /// Vídeo ou câmera de onde vem a detecção.
  final String? fonte;

  /// Endereço do controle remoto do detector (vídeo + pausar/pular), ex. http://192.168.0.10:8765.
  final String? controle;

  /// O detector regrava a cada 30 s; sem notícias há mais tempo que isso,
  /// a câmera (ou o computador do detector) caiu.
  static const tolerancia = Duration(minutes: 2);

  bool online([DateTime? agora]) => (agora ?? DateTime.now()).difference(atualizadoEm) <= tolerancia;

  int get total => vagas.length;
  int get ocupadas => vagas.values.where((v) => v.ocupada).length;

  /// Converte a resposta de `GET /api/vagas`. Devolve `null` se vier sem vagas
  /// (banco ainda sem o seed, por exemplo) — aí o app segue com a simulação.
  static LeituraPatio? doJson(Object? json) {
    if (json is! Map) return null;
    final lista = json['vagas'];
    if (lista is! List || lista.isEmpty) return null;

    final leituras = <String, LeituraVaga>{};
    for (final item in lista) {
      if (item is! Map) continue;
      final codigo = item['codigo'];
      if (codigo is! String) continue;
      leituras[codigo] = (ocupada: item['status'] == 'ocupada', desde: _data(item['desde']));
    }
    if (leituras.isEmpty) return null;

    return LeituraPatio(
      vagas: leituras,
      // sem atualizadoEm (nenhuma gravação ainda) o selo já nasce "offline", que é a verdade
      atualizadoEm: _data(json['atualizadoEm']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      fonte: json['fonte'] as String?,
      controle: json['controle'] is String ? json['controle'] as String : null,
    );
  }

  static DateTime? _data(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
}

/// Busca a ocupação na API de tempo em tempo e repassa cada leitura recebida.
class OcupacaoAoVivo {
  OcupacaoAoVivo(this.aoReceber, {Api? api, this.intervalo = const Duration(seconds: 3)})
      : _api = api ?? Api();

  final void Function(LeituraPatio leitura) aoReceber;
  final Api _api;

  /// Tempo entre duas buscas.
  final Duration intervalo;

  Timer? _timer;
  bool _buscando = false;
  bool _erroAvisado = false;

  bool get ativo => _timer != null;

  void iniciar() {
    if (_timer != null) return;
    _timer = Timer.periodic(intervalo, (_) => _buscar());
    _buscar(); // não espera o primeiro intervalo
  }

  Future<void> _buscar() async {
    if (_buscando) return; // a busca anterior ainda não voltou: não enfileira
    _buscando = true;
    try {
      final leitura = LeituraPatio.doJson(await _api.get('/vagas'));
      if (leitura != null) aoReceber(leitura);
      _erroAvisado = false;
    } on ErroApi catch (e) {
      // backend fora do ar ou sessão expirada: o app segue com a simulação.
      // Avisa uma vez só para não encher o console a cada 3 s.
      if (!_erroAvisado) {
        debugPrint('Ocupação ao vivo indisponível: ${e.mensagem}');
        _erroAvisado = true;
      }
    } finally {
      _buscando = false;
    }
  }

  void parar() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Selo "Câmera ao vivo" (ou "Câmera offline há X min") do pátio.
class SeloCamera extends StatefulWidget {
  const SeloCamera({super.key, required this.leitura, required this.estilo, required this.fundo, this.borda});

  final LeituraPatio leitura;
  final TextStyle estilo;
  final Color fundo;
  final Color? borda;

  static const corOnline = Color(0xFF22C55E);
  static const corOffline = Color(0xFF9CA3AF);

  @override
  State<SeloCamera> createState() => _SeloCameraState();
}

class _SeloCameraState extends State<SeloCamera> {
  late final Timer _relogio;

  @override
  void initState() {
    super.initState();
    _relogio = Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _relogio.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leitura = widget.leitura;
    final online = leitura.online();
    final minutos = DateTime.now().difference(leitura.atualizadoEm).inMinutes;
    final fonte = leitura.fonte == null ? '' : ' (${leitura.fonte})';
    final controle = online ? leitura.controle : null;
    final raio = BorderRadius.circular(16);
    return Tooltip(
      message: controle != null
          ? 'Ocupação detectada pela câmera em tempo real$fonte. Toque para ver o vídeo'
          : online
              ? 'Ocupação detectada pela câmera em tempo real$fonte'
              : 'A câmera parou de enviar dados; mostrando a última leitura$fonte',
      child: Material(
        color: widget.fundo,
        shape: RoundedRectangleBorder(
          borderRadius: raio,
          side: widget.borda == null ? BorderSide.none : BorderSide(color: widget.borda!, width: 1.5),
        ),
        child: InkWell(
          borderRadius: raio,
          onTap: controle == null
              ? null
              : () => JanelaCamera.abrir(context, controle, titulo: 'Câmera ao vivo${fonte.isEmpty ? '' : fonte}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: online ? SeloCamera.corOnline : SeloCamera.corOffline,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  online ? 'Câmera ao vivo' : (minutos > 9999 ? 'Câmera sem dados' : 'Câmera offline há $minutos min'),
                  style: widget.estilo,
                ),
                if (controle != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.videocam_rounded, size: 18, color: widget.estilo.color),
                  const SizedBox(width: 4),
                  Text('Ver', style: widget.estilo),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
