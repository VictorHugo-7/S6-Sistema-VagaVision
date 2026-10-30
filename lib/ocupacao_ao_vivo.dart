import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'janela_camera.dart';

/// Estado de uma vaga lido da câmera.
typedef LeituraVaga = ({bool ocupada, DateTime? desde});

/// Ocupação de um nível do bloco enviada pelo detector (visao/detectar_ocupacao.py --firebase).
class LeituraNivel {
  const LeituraNivel({
    required this.nivel,
    required this.vagas,
    required this.atualizadoEm,
    this.fonte,
    this.controle,
  });

  /// 0 = Nível 1 (mesmo índice de `GaragemController.niveis`).
  final int nivel;
  final Map<String, LeituraVaga> vagas;
  final DateTime atualizadoEm;
  final String? fonte;

  /// Endereço do controle remoto do detector (vídeo + pausar/pular), ex. http://192.168.0.10:8765.
  final String? controle;

  /// O detector regrava o documento a cada 30 s; sem notícias há mais tempo que isso,
  /// a câmera (ou o computador do detector) caiu.
  static const tolerancia = Duration(minutes: 2);

  bool online([DateTime? agora]) => (agora ?? DateTime.now()).difference(atualizadoEm) <= tolerancia;

  /// Converte o documento `ocupacao/{bloco}-{nivel}` do Firestore. Devolve `null` se o
  /// documento estiver incompleto.
  static LeituraNivel? doDocumento(Map<String, dynamic> dados) {
    final nivel = dados['nivel'];
    final vagas = dados['vagas'];
    if (nivel is! int || nivel < 1 || vagas is! Map) return null;
    final leituras = <String, LeituraVaga>{};
    for (final MapEntry(:key, :value) in vagas.entries) {
      if (key is! String || value is! Map || value['ocupada'] is! bool) continue;
      leituras[key] = (ocupada: value['ocupada'] as bool, desde: _data(value['desde']));
    }
    return LeituraNivel(
      nivel: nivel - 1,
      vagas: leituras,
      // logo após a gravação o horário do servidor ainda não chegou (fica nulo): usa agora
      atualizadoEm: _data(dados['atualizadoEm']) ?? DateTime.now(),
      fonte: dados['fonte'] as String?,
      controle: dados['controle'] is String ? dados['controle'] as String : null,
    );
  }

  static DateTime? _data(Object? v) => switch (v) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        _ => null,
      };
}

/// Escuta no Firestore a ocupação detectada pela câmera e repassa cada nível recebido.
/// Só funciona com usuário logado (as regras do Firestore exigem login para ler).
class OcupacaoAoVivo {
  OcupacaoAoVivo(this.aoReceber, {this.bloco = 'Bloco U'});

  final void Function(LeituraNivel leitura) aoReceber;
  final String bloco;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _assinatura;

  bool get ativo => _assinatura != null;

  void iniciar() {
    if (!AuthService.pronto || _assinatura != null) return;
    _assinatura = FirebaseFirestore.instance
        .collection('ocupacao')
        .where('bloco', isEqualTo: bloco)
        .snapshots()
        .listen(
      (consulta) {
        for (final doc in consulta.docs) {
          final leitura = LeituraNivel.doDocumento(doc.data());
          if (leitura != null) aoReceber(leitura);
        }
      },
      onError: (Object e) {
        // ex.: regras do Firestore ainda não publicadas; o app segue com a simulação
        debugPrint('Ocupação ao vivo indisponível: $e');
        _assinatura = null;
      },
    );
  }

  void parar() {
    _assinatura?.cancel();
    _assinatura = null;
  }
}

/// Selo "Câmera ao vivo" (ou "Câmera offline há X min") para o nível que tem câmera.
/// Ocupa o lugar dos botões de simulação; se reavalia sozinho porque a câmera pode
/// parar de mandar notícias sem nenhum evento chegar. Com a câmera no ar, um toque abre
/// a janela com o vídeo e os controles de reprodução.
class SeloCamera extends StatefulWidget {
  const SeloCamera({super.key, required this.leitura, required this.estilo, required this.fundo, this.borda});

  final LeituraNivel leitura;
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
              : () => JanelaCamera.abrir(context, controle, titulo: 'Câmera · Nível ${leitura.nivel + 1}'),
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
                Text(online ? 'Câmera ao vivo' : 'Câmera offline há $minutos min', style: widget.estilo),
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
