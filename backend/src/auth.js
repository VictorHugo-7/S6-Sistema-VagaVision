import fs from 'node:fs';

import admin from 'firebase-admin';

import { env } from './env.js';
import { erroCliente, naoAutenticado, rota } from './erros.js';
import { Usuario } from './models/Usuario.js';

// Autenticação: valida o id_token do Firebase enviado no header Authorization.

let iniciado = false;

export function iniciarFirebase() {
  if (iniciado) return;
  if (!fs.existsSync(env.firebaseChave)) {
    console.error(`\nErro: chave do Firebase não encontrada em ${env.firebaseChave}`);
    console.error('Baixe em: Console do Firebase > Configurações do projeto > Contas de serviço >');
    console.error('Gerar nova chave privada, e aponte FIREBASE_SERVICE_ACCOUNT para o arquivo.\n');
    process.exit(1);
  }
  const chave = JSON.parse(fs.readFileSync(env.firebaseChave, 'utf8'));
  admin.initializeApp({ credential: admin.credential.cert(chave) });
  iniciado = true;
  console.log(`Firebase Admin pronto (projeto ${chave.project_id}).`);
}

function tokenDoHeader(req) {
  const header = req.get('authorization') ?? '';
  const [tipo, valor] = header.split(' ');
  if (tipo?.toLowerCase() !== 'bearer' || !valor) return null;
  return valor;
}

/// Exige usuário logado e deixa em `req.usuario` o documento do nosso banco
/// (criado na hora, se for o primeiro acesso dele).
export const exigirLogin = rota(async (req, _res, next) => {
  const token = tokenDoHeader(req);
  if (!token) throw naoAutenticado();

  let dados;
  try {
    dados = await admin.auth().verifyIdToken(token);
  } catch (e) {
    // token expirado é o caso comum: o app renova e tenta de novo
    throw naoAutenticado(e?.code === 'auth/id-token-expired' ? 'Sessão expirada, entre de novo.' : 'Sessão inválida.');
  }

  const email = dados.email?.toLowerCase();
  if (!email) throw naoAutenticado('Sua conta não tem e-mail; use outra forma de login.');

  req.usuario = await Usuario.findOneAndUpdate(
    { firebaseUid: dados.uid },
    {
      $set: {
        nome: dados.name || email.split('@')[0],
        email,
        foto: dados.picture ?? null,
        ultimoLogin: new Date(),
      },
      $setOnInsert: { criadoEm: new Date() },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );
  next();
});

/// Só o detector de visão computacional pode gravar o status das vagas.
/// Ele manda o segredo combinado (DETECTOR_TOKEN) no header X-Detector-Token.
export function exigirDetector(req, _res, next) {
  const enviado = req.get('x-detector-token');
  if (!enviado) return next(erroCliente('Header X-Detector-Token ausente.'));
  // comparação simples: o segredo é local, não vale complicar
  if (enviado !== env.tokenDetector) return next(naoAutenticado('X-Detector-Token inválido.'));
  next();
}
