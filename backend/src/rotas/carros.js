import { Router } from 'express';

import { exigirLogin } from '../auth.js';
import { erroCliente, naoEncontrado, rota } from '../erros.js';
import { Carro } from '../models/Carro.js';
import { Estacionamento } from '../models/Estacionamento.js';
import { placaValida } from '../placa.js';

export const rotasCarros = Router();
rotasCarros.use(exigirLogin);

/** Campos aceitos do corpo, já limpos. */
function corpoCarro(body, { parcial = false } = {}) {
  const dados = {};
  for (const campo of ['placa', 'modelo', 'cor', 'apelido']) {
    if (body[campo] !== undefined) dados[campo] = body[campo] === null ? null : String(body[campo]).trim();
  }
  if (!parcial) {
    for (const campo of ['placa', 'modelo', 'cor']) {
      if (!dados[campo]) throw erroCliente(`Informe o campo "${campo}".`);
    }
  }
  if (dados.placa !== undefined && !placaValida(dados.placa)) {
    throw erroCliente('Placa inválida. Use o formato ABC1234 ou ABC1D23 (Mercosul).', 'placa_invalida');
  }
  if (dados.apelido === '') dados.apelido = null;
  return dados;
}

rotasCarros.get('/', rota(async (req, res) => {
  const carros = await Carro.find({ usuarioId: req.usuario._id }).sort({ criadoEm: 1 });
  res.json(carros.map((c) => c.toJSON()));
}));

rotasCarros.post('/', rota(async (req, res) => {
  const carro = await Carro.create({ ...corpoCarro(req.body ?? {}), usuarioId: req.usuario._id });
  res.status(201).json(carro.toJSON());
}));

rotasCarros.patch('/:id', rota(async (req, res) => {
  const carro = await Carro.findOneAndUpdate(
    { _id: req.params.id, usuarioId: req.usuario._id },
    { $set: corpoCarro(req.body ?? {}, { parcial: true }) },
    { new: true, runValidators: true },
  );
  if (!carro) throw naoEncontrado('Carro não encontrado.');
  res.json(carro.toJSON());
}));

rotasCarros.delete('/:id', rota(async (req, res) => {
  const carro = await Carro.findOne({ _id: req.params.id, usuarioId: req.usuario._id });
  if (!carro) throw naoEncontrado('Carro não encontrado.');

  const ativo = await Estacionamento.findOne({ carroId: carro._id, saidaEm: null });
  if (ativo) {
    throw erroCliente(
      `Este carro está marcado na vaga ${ativo.vaga}. Registre a saída antes de remover o carro.`,
      'carro_estacionado',
    );
  }
  // o histórico do carro vai junto: sem o carro ele não diria mais nada
  await Estacionamento.deleteMany({ carroId: carro._id });
  await carro.deleteOne();
  res.status(204).end();
}));
