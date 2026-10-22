"""
publicar_firebase.py — VagaVision

Envia o estado das vagas detectado pelo detectar_ocupacao.py para o Cloud Firestore,
onde o app (web e celular) escuta e atualiza o mapa em tempo real.

Documento gravado (um por bloco + nível), coleção "ocupacao":

    ocupacao/bloco-u-1 = {
        "bloco": "Bloco U",
        "nivel": 1,
        "fonte": "teste_carros.mp4",
        "atualizadoEm": <hora do servidor>,
        "vagas": {"A1": {"ocupada": true, "desde": <hora>}, "A2": {...}, ...}
    }

O envio roda numa thread separada: o vídeo não trava esperando a rede. Só o estado mais
recente é enviado (se várias mudanças chegarem juntas, vai uma gravação só) e, mesmo sem
mudanças, o documento é regravado a cada `batimento` segundos para o app saber que a
câmera está no ar.
"""

import os
import re
import sys
import threading
import time
import unicodedata
from datetime import datetime, timedelta, timezone

COLECAO = "ocupacao"


def id_documento(bloco, nivel):
    """'Bloco U', 1 -> 'bloco-u-1' (o app usa a mesma regra)."""
    sem_acento = unicodedata.normalize("NFKD", bloco).encode("ascii", "ignore").decode()
    return f"{re.sub(r'[^a-z0-9]+', '-', sem_acento.lower()).strip('-')}-{nivel}"


def iniciar_firestore(chave):
    """Conecta no Firestore com a chave da conta de serviço. Se a variável
    FIRESTORE_EMULATOR_HOST estiver definida, usa o emulador local (para testes)."""
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError:
        sys.exit("Erro: instale as dependências com  pip install -r requirements.txt")

    if os.environ.get("FIRESTORE_EMULATOR_HOST"):
        from google.auth.credentials import AnonymousCredentials
        from google.cloud import firestore as cloud_firestore

        projeto = os.environ.get("GCLOUD_PROJECT", "vagavision-13295")
        print(f"Firestore: usando o EMULADOR em {os.environ['FIRESTORE_EMULATOR_HOST']} (projeto {projeto}).")
        # no emulador o cliente entra como administrador, sem precisar de chave
        return cloud_firestore.Client(project=projeto, credentials=AnonymousCredentials()), firestore.SERVER_TIMESTAMP
    else:
        if not chave or not os.path.exists(chave):
            sys.exit(
                f"Erro: chave do Firebase '{chave}' não encontrada.\n"
                "Baixe em: Console do Firebase > Configurações do projeto > Contas de serviço > "
                "Gerar nova chave privada, e salve como visao/firebase-chave.json."
            )
        app = firebase_admin.initialize_app(credentials.Certificate(chave), name="vagavision")
        print(f"Firestore: conectado ao projeto {app.project_id}.")
    return firestore.client(app), firestore.SERVER_TIMESTAMP


class PublicadorFirebase:
    def __init__(self, chave, bloco, nivel, fonte, batimento=30.0):
        self.cliente, self._hora_servidor = iniciar_firestore(chave)
        self.bloco, self.nivel, self.fonte = bloco, nivel, fonte
        self.documento = self.cliente.collection(COLECAO).document(id_documento(bloco, nivel))
        self.batimento = batimento
        self._estado = None
        self._novo = threading.Event()
        self._parar = threading.Event()
        self._erro_avisado = False
        self._thread = threading.Thread(target=self._rodar, name="publicador-firebase", daemon=True)
        self._thread.start()
        print(f"Publicando em {COLECAO}/{self.documento.id}.")

    def publicar(self, vagas, tempo_video):
        """Registra o estado atual (não bloqueia). `vagas` são objetos Vaga do detector com
        o atributo `codigo` (código da vaga no app, ex.: 'A1')."""
        agora = datetime.now(timezone.utc)
        self._estado = {
            v.codigo: {
                "ocupada": v.ocupada,
                # "desde" é tempo do vídeo; converte para hora real contando para trás
                "desde": agora - timedelta(seconds=max(0.0, tempo_video - v.desde)),
            }
            for v in vagas
        }
        self._novo.set()

    def _gravar(self):
        self.documento.set({
            "bloco": self.bloco,
            "nivel": self.nivel,
            "fonte": self.fonte,
            "atualizadoEm": self._hora_servidor,
            "vagas": self._estado,
        })

    def _rodar(self):
        while True:
            self._novo.wait(timeout=self.batimento)
            self._novo.clear()
            if self._parar.is_set():
                break  # o último estado é enviado pelo fechar()
            if self._estado is None:
                continue
            try:
                self._gravar()
                self._erro_avisado = False
            except Exception as erro:  # sem internet, chave inválida...: tenta de novo depois
                if not self._erro_avisado:
                    print(f"Aviso: não foi possível enviar ao Firebase ({erro}). Tentando de novo...")
                    self._erro_avisado = True
                time.sleep(2)
                self._novo.set()

    def fechar(self):
        """Envia o último estado e encerra a thread."""
        self._parar.set()
        self._novo.set()
        self._thread.join(timeout=10)
        if self._estado is not None:
            try:
                self._gravar()
            except Exception as erro:
                print(f"Aviso: o último estado não foi enviado ao Firebase ({erro}).")
