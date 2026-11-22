import mongoose from 'mongoose';

import { env } from './env.js';

/** Conecta no MongoDB Atlas. Lança se não conseguir (o server.js aborta). */
export async function conectar() {
  mongoose.set('strictQuery', true);
  await mongoose.connect(env.mongoUri, {
    dbName: env.mongoDb,
    serverSelectionTimeoutMS: 10000,
  });
  console.log(`MongoDB conectado (banco "${env.mongoDb}").`);
  return mongoose.connection;
}

export async function desconectar() {
  await mongoose.connection.close();
}
