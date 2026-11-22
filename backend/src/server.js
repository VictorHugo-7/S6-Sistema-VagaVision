import cors from 'cors';
import express from 'express';

import { iniciarFirebase } from './auth.js';
import { conectar } from './db.js';
import { env } from './env.js';
import { tratarErros } from './erros.js';
import { rotasCarros } from './rotas/carros.js';
import { rotasEstacionamentos } from './rotas/estacionamentos.js';
import { rotasUsuarios } from './rotas/usuarios.js';
import { rotasVagas } from './rotas/vagas.js';

const app = express();

app.use(express.json({ limit: '256kb' }));
app.use(
  cors({
    // CORS_ORIGINS vazio libera qualquer origem: o Flutter Web roda numa porta
    // diferente a cada `flutter run`, então fixar origem só atrapalha em desenvolvimento
    origin: env.origens.length === 0 ? true : env.origens,
  }),
);

// log de uma linha por requisição (sem dependência extra)
app.use((req, _res, next) => {
  console.log(`${req.method} ${req.originalUrl}`);
  next();
});

app.get('/api/saude', (_req, res) => res.json({ ok: true, hora: new Date() }));

app.use('/api/usuarios', rotasUsuarios);
app.use('/api/carros', rotasCarros);
app.use('/api/estacionamentos', rotasEstacionamentos);
app.use('/api/vagas', rotasVagas);

app.use((_req, res) => res.status(404).json({ erro: 'Rota não encontrada.' }));
app.use(tratarErros);

iniciarFirebase();
try {
  await conectar();
} catch (erro) {
  console.error('\nErro: não foi possível conectar no MongoDB.');
  console.error(erro.message);
  console.error('\nConfira a MONGODB_URI e se o seu IP está liberado em Atlas > Network Access.\n');
  process.exit(1);
}

const servidor = app.listen(env.porta, () => {
  console.log(`API do VagaVision em http://localhost:${env.porta}/api`);
});

for (const sinal of ['SIGINT', 'SIGTERM']) {
  process.on(sinal, () => {
    console.log('\nEncerrando...');
    servidor.close(() => process.exit(0));
  });
}
