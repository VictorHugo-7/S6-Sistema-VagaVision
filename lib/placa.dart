/// Validação de placa brasileira: modelo antigo (ABC1234) e Mercosul (ABC1D23).
library;

final _antiga = RegExp(r'^[A-Z]{3}[0-9]{4}$');
final _mercosul = RegExp(r'^[A-Z]{3}[0-9][A-Z][0-9]{2}$');

/// 'abc-1d23' -> 'ABC1D23' (é assim que a placa é gravada).
String normalizarPlaca(String valor) => valor.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

bool placaValida(String valor) {
  final p = normalizarPlaca(valor);
  return _antiga.hasMatch(p) || _mercosul.hasMatch(p);
}

/// 'ABC1234' -> 'ABC-1234'; Mercosul fica sem hífen, como é o padrão.
String formatarPlaca(String valor) {
  final p = normalizarPlaca(valor);
  return _antiga.hasMatch(p) ? '${p.substring(0, 3)}-${p.substring(3)}' : p;
}

/// Mensagem de erro para o formulário, ou `null` se a placa está boa.
/// Aceita `null` para encaixar direto em `TextFormField.validator`.
String? erroPlaca(String? valor) {
  final p = normalizarPlaca(valor ?? '');
  if (p.isEmpty) return 'Informe a placa.';
  if (!placaValida(p)) return 'Placa inválida. Use ABC1234 ou ABC1D23 (Mercosul).';
  return null;
}
