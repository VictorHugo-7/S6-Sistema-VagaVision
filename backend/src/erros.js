/// Erro com status HTTP e mensagem já pronta para o app mostrar ao usuário.
export class ErroApi extends Error {
  constructor(status, mensagem, codigo = null) {
    super(mensagem);
    this.status = status;
    this.codigo = codigo;
  }
}

export const erroCliente = (msg, codigo) => new ErroApi(400, msg, codigo);
export const naoAutenticado = (msg = 'Entre na sua conta para continuar.') => new ErroApi(401, msg);
export const naoEncontrado = (msg = 'Não encontrado.') => new ErroApi(404, msg);
export const conflito = (msg, codigo) => new ErroApi(409, msg, codigo);

/** Embrulha um handler async para que erros caiam no middleware de erro. */
export const rota = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

/** Middleware final: traduz qualquer erro numa resposta JSON com mensagem legível. */
export function tratarErros(erro, _req, res, _next) {
  // erro de validação do Mongoose (placa inválida, campo faltando...)
  if (erro?.name === 'ValidationError') {
    const primeiro = Object.values(erro.errors)[0];
    return res.status(400).json({ erro: primeiro?.message ?? 'Dados inválidos.' });
  }
  // índice único violado
  if (erro?.code === 11000) {
    const campo = Object.keys(erro.keyPattern ?? {}).join(', ');
    if (erro.keyPattern?.carroId) {
      return res.status(409).json({
        erro: 'Este carro já está marcado em outra vaga. Registre a saída antes de marcar uma nova.',
        codigo: 'carro_ja_estacionado',
      });
    }
    if (erro.keyPattern?.placa) {
      return res.status(409).json({ erro: 'Você já cadastrou um carro com esta placa.', codigo: 'placa_duplicada' });
    }
    if (erro.keyPattern?.email) {
      return res.status(409).json({ erro: 'Este e-mail já está cadastrado.', codigo: 'email_duplicado' });
    }
    return res.status(409).json({ erro: `Valor duplicado em: ${campo || 'campo único'}.` });
  }
  if (erro?.name === 'CastError') {
    return res.status(400).json({ erro: 'Identificador inválido.' });
  }
  if (erro instanceof ErroApi) {
    return res.status(erro.status).json({ erro: erro.message, codigo: erro.codigo ?? undefined });
  }
  // corpo que não é JSON válido (o express.json() rejeita antes de chegar na rota)
  if (erro?.type === 'entity.parse.failed') {
    return res.status(400).json({ erro: 'Corpo da requisição não é um JSON válido.' });
  }
  if (erro?.type === 'entity.too.large') {
    return res.status(413).json({ erro: 'Corpo da requisição muito grande.' });
  }
  console.error('Erro inesperado:', erro);
  return res.status(500).json({ erro: 'Erro interno no servidor.' });
}
