import 'package:flutter/material.dart';

import 'tema_controller.dart';
import 'theme.dart';

Widget _comIcone(IconData? icone, Widget texto, Color cor, double tamanho) {
  if (icone == null) return texto;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icone, size: tamanho, color: cor), const SizedBox(width: 8), texto],
  );
}

class BotaoAzul extends StatelessWidget {
  const BotaoAzul({
    super.key,
    required this.texto,
    required this.onTap,
    this.altura = alvoToque,
    this.pequeno = false,
    this.icone,
  });

  final String texto;
  final VoidCallback onTap;
  final double altura;
  final bool pequeno;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(pequeno ? 10 : 12);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: raio,
        boxShadow: [
          BoxShadow(
            color: Cores.azulBotao.withValues(alpha: pequeno ? 0.25 : 0.35),
            blurRadius: pequeno ? 10 : 18,
            offset: Offset(0, pequeno ? 3 : 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: raio,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(Cores.azulBotao, Colors.white, 0.14)!, Cores.azulBotao],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: altura,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: pequeno ? 12 : 16),
              child: _comIcone(
                icone,
                Text(texto, textAlign: TextAlign.center, style: mono(pequeno ? 12 : 13, peso: FontWeight.w700, cor: Colors.white)),
                Colors.white,
                pequeno ? 16 : 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BotaoContorno extends StatelessWidget {
  const BotaoContorno({super.key, required this.texto, required this.onTap, this.altura = alvoToque, this.icone});

  final String texto;
  final VoidCallback onTap;
  final double altura;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.textoSuave.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: altura,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _comIcone(
            icone,
            Text(texto, textAlign: TextAlign.center, style: mono(13, peso: FontWeight.w700, cor: p.texto)),
            p.texto,
            18,
          ),
        ),
      ),
    );
  }
}

class IconeBolha extends StatelessWidget {
  const IconeBolha({super.key, required this.icone, required this.cor, this.tamanho = 40});

  final IconData icone;
  final Color cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tamanho * 0.3),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Icon(icone, size: tamanho * 0.5, color: cor),
    );
  }
}

class PaginaFolha extends StatelessWidget {
  const PaginaFolha({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}

class FolhaBranca extends StatelessWidget {
  const FolhaBranca({
    super.key,
    required this.titulo,
    required this.filhos,
    required this.rodape,
    this.subtitulo,
    this.icone,
  });

  final String titulo;
  final String? subtitulo;
  final IconData? icone;
  final List<Widget> filhos;
  final Widget rodape;

  @override
  Widget build(BuildContext context) {
    final p = context.paleta;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final icone = this.icone;
    final subtitulo = this.subtitulo;
    return Container(
      decoration: BoxDecoration(
        color: p.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: (escuro ? Colors.white : Colors.black).withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: escuro ? 0.35 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icone != null) ...[
                IconeBolha(icone: icone, cor: escuro ? p.destaque : Cores.azulBotao, tamanho: 44),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: mono(20, peso: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    if (subtitulo != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitulo, style: mono(12, peso: FontWeight.w400, cor: p.textoSuave)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, thickness: 1, color: p.textoSuave.withValues(alpha: 0.18)),
          const SizedBox(height: 14),
          Expanded(child: ListView(children: filhos)),
          const SizedBox(height: 12),
          rodape,
        ],
      ),
    );
  }
}

class BotaoTema extends StatelessWidget {
  const BotaoTema({super.key, required this.tema, this.sobreFundoEscuro = false});

  final TemaController tema;

  final bool sobreFundoEscuro;

  @override
  Widget build(BuildContext context) {
    final brilho = Theme.of(context).brightness;
    final escuro = brilho == Brightness.dark;
    final p = context.paleta;
    return Tooltip(
      message: escuro ? 'Modo claro' : 'Modo escuro',
      child: Material(
        color: sobreFundoEscuro ? Colors.white.withValues(alpha: 0.06) : p.superficie,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => tema.alternar(brilho),
          child: SizedBox(
            width: alvoToque,
            height: alvoToque,
            child: Icon(
              escuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 22,
              color: sobreFundoEscuro ? Colors.white : p.destaque,
              semanticLabel: escuro ? 'Modo claro' : 'Modo escuro',
            ),
          ),
        ),
      ),
    );
  }
}
