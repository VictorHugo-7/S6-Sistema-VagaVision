// Popula a coleção `spots` a partir de visao/vagas.json (npm run seed [-- --reset]).
import fs from 'node:fs';
import path from 'node:path';

import { conectar, desconectar } from '../src/db.js';
import { raizRepo } from '../src/env.js';
import { Vaga } from '../src/models/Vaga.js';

const reset = process.argv.includes('--reset');
const arquivo = path.join(raizRepo, 'visao', 'vagas.json');

if (!fs.existsSync(arquivo)) {
  console.error(`Erro: ${arquivo} não encontrado.`);
  process.exit(1);
}

const mapeamento = JSON.parse(fs.readFileSync(arquivo, 'utf8'));
const vagas = Array.isArray(mapeamento.vagas) ? mapeamento.vagas : [];

// 'codigo' é o nome da vaga no app; 'id' (V01...) é só o rótulo do mapeamento no vídeo.
// O setor sai da letra do código: A1 -> fileira A.
const itens = [];
const vistos = new Set();
for (const v of vagas) {
  const codigo = String(v.codigo ?? v.id ?? '').toUpperCase().trim();
  if (!codigo || vistos.has(codigo)) continue;
  vistos.add(codigo);
  itens.push({ codigo, setor: /^[A-Z]/.test(codigo) ? `Fileira ${codigo[0]}` : null });
}

if (itens.length === 0) {
  console.error(`Erro: nenhuma vaga com "codigo" em ${arquivo}.`);
  console.error('Rode o visao/mapear_vagas.py para gerar o mapeamento com os códigos do app.');
  process.exit(1);
}

await conectar();

if (reset) {
  const { deletedCount } = await Vaga.deleteMany({});
  console.log(`--reset: ${deletedCount} vaga(s) apagada(s).`);
}

const agora = new Date();
const r = await Vaga.bulkWrite(
  itens.map((item) => ({
    updateOne: {
      filter: { codigo: item.codigo },
      // só o que identifica a vaga é gravado; o status fica como está (quem manda nele é o detector)
      update: { $setOnInsert: { ...item, status: 'livre', desde: agora, updatedAt: agora } },
      upsert: true,
    },
  })),
  { ordered: false },
);

console.log(`Seed pronto: ${itens.length} vaga(s) no mapeamento, ${r.upsertedCount ?? 0} criada(s), ${(r.matchedCount ?? 0)} já existia(m).`);
console.log(`Vagas: ${itens.map((i) => i.codigo).sort().join(', ')}`);

await desconectar();
