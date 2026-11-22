import { Router } from 'express';

import { exigirDetector, exigirLogin } from '../auth.js';
import { erroCliente, rota } from '../erros.js';
import { Camera } from '../models/Camera.js';
import { Vaga } from '../models/Vaga.js';
import { encerrarAbandonados } from '../reconciliar.js';

export const rotasVagas = Router();

/// O app lê daqui (polling curto). Devolve também `atualizadoEm`, o instante da
/// gravação mais recente: é por ele que o app sabe se a câmera está no ar.
rotasVagas.get('/', exigirLogin, rota(async (_req, res) => {
  const [vagas, camera] = await Promise.all([Vaga.find().sort({ codigo: 1 }), Camera.findById('camera')]);
  const atualizadoEm = vagas.reduce((maior, v) => (!maior || v.updatedAt > maior ? v.updatedAt : maior), null);
  res.json({
    atualizadoEm,
    total: vagas.length,
    ocupadas: vagas.filter((v) => v.status === 'ocupada').length,
    // de onde vem a detecção e onde assistir ao vídeo (null se o detector não está rodando)
    fonte: camera?.fonte ?? null,
    controle: camera?.controle ?? null,
    vagas: vagas.map((v) => v.toJSON()),
  });
}));

// Gravação em lote feita pelo detector: PUT /api/vagas/status.
rotasVagas.put('/status', exigirDetector, rota(async (req, res) => {
  const lista = req.body?.vagas;
  if (!Array.isArray(lista) || lista.length === 0) throw erroCliente('Mande "vagas" com ao menos um item.');

  const agora = new Date();
  const anteriores = new Map(
    (await Vaga.find({ codigo: { $in: lista.map((v) => String(v.codigo ?? '').toUpperCase().trim()) } }))
      .map((v) => [v.codigo, v]),
  );

  const operacoes = [];
  const liberadas = []; // vagas que acabaram de ficar livres (ver encerrarAbandonados)
  for (const item of lista) {
    const codigo = String(item.codigo ?? '').toUpperCase().trim();
    if (!codigo) throw erroCliente('Vaga sem "codigo".');
    const status = item.status === 'ocupada' || item.ocupada === true ? 'ocupada' : 'livre';
    if (status === 'livre') liberadas.push(codigo);
    const antes = anteriores.get(codigo);
    // "desde" só muda quando o status muda: assim o app mostra "ocupada há 25 min" certo
    const mudou = !antes || antes.status !== status;
    const desde = mudou ? (item.desde ? new Date(item.desde) : agora) : antes.desde;
    operacoes.push({
      updateOne: {
        filter: { codigo },
        update: {
          $set: { status, desde, updatedAt: agora },
          $setOnInsert: { codigo, setor: item.setor ?? null },
        },
        upsert: true,
      },
    });
  }

  const r = await Vaga.bulkWrite(operacoes, { ordered: false });
  // guarda de onde vem a detecção, para o app achar o vídeo ao vivo
  await Camera.findByIdAndUpdate(
    'camera',
    { $set: { fonte: req.body?.fonte ?? null, controle: req.body?.controle ?? null, atualizadoEm: agora } },
    { upsert: true },
  );
  // quem estacionou e foi embora sem tocar em "Já saí" tem a saída registrada aqui,
  // na hora em que a câmera viu a vaga vazia
  const encerrados = await encerrarAbandonados({ codigos: liberadas });

  res.json({
    ok: true,
    gravadas: operacoes.length,
    criadas: r.upsertedCount ?? 0,
    registrosEncerrados: encerrados,
    atualizadoEm: agora,
    fonte: req.body?.fonte ?? null,
    controle: req.body?.controle ?? null,
  });
}));
