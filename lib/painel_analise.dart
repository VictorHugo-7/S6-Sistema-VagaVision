import 'package:flutter/material.dart';

import 'historico.dart';

/// Cores e fonte do painel. Cada interface (web e celular) tem o seu tema, então quem usa o
/// painel entrega aqui as cores do tema atual.
class EstiloPainel {
  const EstiloPainel({
    required this.texto,
    required this.suave,
    required this.cartao,
    required this.destaque,
    required this.livre,
    required this.medio,
    required this.ocupada,
    required this.fonte,
  });

  final Color texto, suave, cartao, destaque, livre, medio, ocupada;
  final TextStyle Function(double tamanho, {FontWeight? peso, Color? cor}) fonte;

  /// Verde (vazio), amarelo (movimentado) ou vermelho (quase lotado).
  Color corDaOcupacao(double o) => o < 0.5 ? livre : (o < 0.8 ? medio : ocupada);
}

const _nomesDias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

/// Previsão de lotação + painel de análise (picos, melhor horário, ocupação por hora e por dia).
class PainelAnalise extends StatefulWidget {
  const PainelAnalise({
    super.key,
    required this.historico,
    required this.estilo,
    this.ocupacaoAtual,
    this.agora,
  });

  final HistoricoOcupacao historico;
  final EstiloPainel estilo;

  /// Fração de vagas ocupadas neste momento (0 a 1).
  final double? ocupacaoAtual;

  /// Relógio usado nos cálculos (só para testes); por padrão, a hora atual.
  final DateTime? agora;

  @override
  State<PainelAnalise> createState() => _PainelAnaliseState();
}

class _PainelAnaliseState extends State<PainelAnalise> {
  late int _dia = (widget.agora ?? DateTime.now()).weekday;

  @override
  Widget build(BuildContext context) {
    final e = widget.estilo;
    final h = widget.historico;
    final agora = widget.agora ?? DateTime.now();
    final hoje = agora.weekday;
    final atual = widget.ocupacaoAtual ?? h.ocupacaoEsperada(hoje, agora.hour);
    final pico = h.picoDoDia(hoje);
    final melhor = h.melhorHoraDoDia(hoje);
    final prox = h.previsao(agora);
    final lotacao = h.proximaLotacao(agora);

    return ListenableBuilder(
      listenable: h,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _Numero(estilo: e, titulo: 'Agora', valor: pctTexto(atual), cor: e.corDaOcupacao(atual), legenda: 'ocupado')),
              const SizedBox(width: 8),
              Expanded(
                child: _Numero(
                  estilo: e,
                  titulo: 'Pico hoje',
                  valor: horaTexto(pico.hora),
                  cor: e.corDaOcupacao(pico.ocupacao),
                  legenda: pctTexto(pico.ocupacao),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Numero(
                  estilo: e,
                  titulo: 'Melhor hora',
                  valor: horaTexto(melhor.hora),
                  cor: e.corDaOcupacao(melhor.ocupacao),
                  legenda: pctTexto(melhor.ocupacao),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Titulo(estilo: e, texto: 'Previsão de lotação'),
          const SizedBox(height: 6),
          Text(
            lotacao == null
                ? 'Nas próximas horas o estacionamento deve ter vagas.'
                : 'Deve lotar por volta das ${horaTexto(lotacao.hora)} (${pctTexto(lotacao.ocupacao)} ocupado).',
            style: e.fonte(12, peso: FontWeight.w600, cor: e.texto),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < prox.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _HoraPrevista(estilo: e, ponto: prox[i])),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _Titulo(estilo: e, texto: 'Ocupação por hora'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                _ChipDia(estilo: e, texto: _nomesDias[d - 1], marcado: d == _dia, onTap: () => setState(() => _dia = d)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: Size.infinite,
              painter: _GraficoHoras(
                pontos: [for (final p in h.dia(_dia)) if (p.hora >= 6 && p.hora <= 22) p],
                estilo: e,
                horaAtual: _dia == hoje ? agora.hour : null,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Titulo(estilo: e, texto: 'Média por dia da semana'),
          const SizedBox(height: 8),
          for (var d = 1; d <= 7; d++) _LinhaDia(estilo: e, nome: _nomesDias[d - 1], media: h.mediaDoDia(d), hoje: d == hoje),
          const SizedBox(height: 14),
          Text(
            h.confiavel
                ? 'Baseado em ${h.leituras} leituras feitas neste aparelho.'
                : 'Estimativa inicial (curva típica de campus) com ${h.leituras} '
                    '${h.leituras == 1 ? 'leitura' : 'leituras'} deste aparelho. '
                    'Quanto mais você usa o app, mais a previsão se ajusta.',
            style: e.fonte(10, peso: FontWeight.w500, cor: e.suave),
          ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo({required this.estilo, required this.texto});

  final EstiloPainel estilo;
  final String texto;

  @override
  Widget build(BuildContext context) => Text(texto, style: estilo.fonte(14, peso: FontWeight.w700, cor: estilo.texto));
}

class _Numero extends StatelessWidget {
  const _Numero({required this.estilo, required this.titulo, required this.valor, required this.cor, required this.legenda});

  final EstiloPainel estilo;
  final String titulo, valor, legenda;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$titulo: $valor, $legenda',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(color: estilo.cartao, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: estilo.fonte(10, peso: FontWeight.w600, cor: estilo.suave)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valor, style: estilo.fonte(22, peso: FontWeight.w700, cor: estilo.texto)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(legenda, style: estilo.fonte(10, peso: FontWeight.w600, cor: estilo.suave), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HoraPrevista extends StatelessWidget {
  const _HoraPrevista({required this.estilo, required this.ponto});

  final EstiloPainel estilo;
  final PontoHora ponto;

  @override
  Widget build(BuildContext context) {
    final cor = estilo.corDaOcupacao(ponto.ocupacao);
    return Semantics(
      label: '${horaTexto(ponto.hora)}: ${pctTexto(ponto.ocupacao)} ocupado',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: estilo.cartao, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(horaTexto(ponto.hora), style: estilo.fonte(11, peso: FontWeight.w700, cor: estilo.texto)),
            const SizedBox(height: 5),
            Container(
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 5),
            Text(pctTexto(ponto.ocupacao), style: estilo.fonte(10, peso: FontWeight.w600, cor: estilo.suave)),
          ],
        ),
      ),
    );
  }
}

class _ChipDia extends StatelessWidget {
  const _ChipDia({required this.estilo, required this.texto, required this.marcado, required this.onTap});

  final EstiloPainel estilo;
  final String texto;
  final bool marcado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: marcado,
      label: texto,
      excludeSemantics: true,
      child: Material(
        color: marcado ? estilo.destaque : estilo.cartao,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              texto,
              style: estilo.fonte(12, peso: FontWeight.w700, cor: marcado ? Colors.white : estilo.texto),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinhaDia extends StatelessWidget {
  const _LinhaDia({required this.estilo, required this.nome, required this.media, required this.hoje});

  final EstiloPainel estilo;
  final String nome;
  final double media;
  final bool hoje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(nome, style: estilo.fonte(11, peso: hoje ? FontWeight.w700 : FontWeight.w500, cor: estilo.texto)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  Container(height: 10, color: estilo.cartao),
                  FractionallySizedBox(
                    widthFactor: media.clamp(0.02, 1.0),
                    child: Container(height: 10, color: estilo.corDaOcupacao(media)),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(pctTexto(media), textAlign: TextAlign.right, style: estilo.fonte(11, peso: FontWeight.w600, cor: estilo.suave)),
          ),
        ],
      ),
    );
  }
}

/// Gráfico de barras: uma barra por hora, colorida pela ocupação; a hora atual ganha contorno.
class _GraficoHoras extends CustomPainter {
  _GraficoHoras({required this.pontos, required this.estilo, required this.horaAtual});

  final List<PontoHora> pontos;
  final EstiloPainel estilo;
  final int? horaAtual;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || pontos.isEmpty) return;
    const rodape = 18.0;
    final altura = size.height - rodape;
    final largura = size.width / pontos.length;

    // linhas de referência em 50% e 100%
    final linha = Paint()
      ..color = estilo.suave.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (final f in [0.5, 1.0]) {
      final y = altura * (1 - f);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linha);
    }

    for (var i = 0; i < pontos.length; i++) {
      final p = pontos[i];
      final alt = (altura * p.ocupacao).clamp(2.0, altura);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * largura + largura * 0.15, altura - alt, largura * 0.7, alt),
        const Radius.circular(3),
      );
      canvas.drawRRect(r, Paint()..color = estilo.corDaOcupacao(p.ocupacao));
      if (p.hora == horaAtual) {
        canvas.drawRRect(
          r.inflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = estilo.texto,
        );
      }
      if (p.hora % 2 == 0) {
        final tp = TextPainter(
          text: TextSpan(text: horaTexto(p.hora), style: estilo.fonte(9, peso: FontWeight.w600, cor: estilo.suave)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(i * largura + (largura - tp.width) / 2, altura + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraficoHoras old) =>
      old.pontos != pontos || old.horaAtual != horaAtual || old.estilo != estilo;
}
