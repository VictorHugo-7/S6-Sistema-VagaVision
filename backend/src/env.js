import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import dotenv from 'dotenv';

const aqui = path.dirname(fileURLToPath(import.meta.url));

/** Raiz do repositório (backend/src -> backend -> raiz). */
export const raizRepo = path.resolve(aqui, '..', '..');

// O .env fica na raiz do repositório (um só para o backend e para o detector).
// backend/.env, se existir, tem prioridade — útil para rodar duas instâncias.
for (const arquivo of [path.join(raizRepo, 'backend', '.env'), path.join(raizRepo, '.env')]) {
  if (fs.existsSync(arquivo)) dotenv.config({ path: arquivo });
}

/** Lê uma variável obrigatória; aborta com uma mensagem útil se faltar. */
function obrigatoria(nome, dica) {
  const valor = process.env[nome];
  if (!valor) {
    console.error(`\nErro: a variável ${nome} não está definida.\n${dica}\n`);
    console.error('Copie o .env.example da raiz para .env e preencha os valores.\n');
    process.exit(1);
  }
  return valor;
}

/** Resolve um caminho do .env: absoluto fica como está, relativo conta da raiz do repositório. */
function caminhoDaRaiz(valor) {
  if (!valor) return null;
  return path.isAbsolute(valor) ? valor : path.resolve(raizRepo, valor);
}

export const env = {
  porta: Number(process.env.PORT ?? 3000),
  mongoUri: obrigatoria('MONGODB_URI', 'É a connection string do MongoDB Atlas (Connect > Drivers > Node.js).'),
  mongoDb: process.env.MONGODB_DB || 'vagavision',
  // separadas por vírgula; vazio = libera qualquer origem (bom para desenvolvimento)
  origens: (process.env.CORS_ORIGINS || '').split(',').map((o) => o.trim()).filter(Boolean),
  // chave da conta de serviço do Firebase (caminho relativo à raiz do repositório).
  firebaseChave: caminhoDaRaiz(process.env.FIREBASE_SERVICE_ACCOUNT) ?? path.join(raizRepo, 'visao', 'firebase-chave.json'),
  // segredo combinado com o detector (visao/) para ele poder gravar o status das vagas
  tokenDetector: obrigatoria('DETECTOR_TOKEN', 'Qualquer texto secreto; o detector manda o mesmo valor no header X-Detector-Token.'),
};
