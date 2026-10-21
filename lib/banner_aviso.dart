import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'notificacoes.dart';

/// Mostra o banner (SnackBar flutuante) de uma notificação nova, por cima de qualquer tela.
void mostrarBannerAviso(ScaffoldMessengerState? mensageiro, Notificacao n) {
  if (mensageiro == null) return;
  final (fundo, texto) = switch (n.tipo) {
    TipoNotificacao.info => (const Color(0xFF124BBD), Colors.white),
    TipoNotificacao.livre => (const Color(0xFF287A18), Colors.white),
    TipoNotificacao.aviso => (const Color(0xFFF08A24), const Color(0xFF111111)),
    TipoNotificacao.critico => (const Color(0xFFD33F3F), Colors.white),
  };
  TextStyle mono(double t, FontWeight p) => GoogleFonts.ibmPlexMono(fontSize: t, fontWeight: p, color: texto);
  mensageiro
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: fundo,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      showCloseIcon: true,
      closeIconColor: texto,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.titulo, style: mono(14, FontWeight.w700)),
          Text(n.mensagem, style: mono(12, FontWeight.w500)),
        ],
      ),
    ));
}
