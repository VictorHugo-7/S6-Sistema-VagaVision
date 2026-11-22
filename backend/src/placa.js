// Validação de placa brasileira: modelo antigo (ABC1234) e Mercosul (ABC1D23).

const ANTIGA = /^[A-Z]{3}[0-9]{4}$/;
const MERCOSUL = /^[A-Z]{3}[0-9][A-Z][0-9]{2}$/;

/** 'abc-1d23' -> 'ABC1D23'. */
export function normalizarPlaca(valor) {
  return String(valor ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '');
}

export function placaValida(valor) {
  const p = normalizarPlaca(valor);
  return ANTIGA.test(p) || MERCOSUL.test(p);
}

/** 'ABC1D23' -> 'Mercosul' | 'antigo'; `null` se for inválida. */
export function modeloDaPlaca(valor) {
  const p = normalizarPlaca(valor);
  if (MERCOSUL.test(p)) return 'Mercosul';
  if (ANTIGA.test(p)) return 'antigo';
  return null;
}

/** 'ABC1234' -> 'ABC-1234'; Mercosul fica sem hífen, como é o padrão. */
export function formatarPlaca(valor) {
  const p = normalizarPlaca(valor);
  return ANTIGA.test(p) ? `${p.slice(0, 3)}-${p.slice(3)}` : p;
}
