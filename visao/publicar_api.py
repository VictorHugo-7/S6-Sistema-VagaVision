"""
publicar_api.py — VagaVision

Envia o estado das vagas detectado pelo detectar_ocupacao.py para a API (backend/),
que grava na coleção `spots` do MongoDB. O app (web e celular) lê daquela coleção e
atualiza o mapa.

Requisição feita (uma por lote de mudanças):

    PUT {VAGAVISION_API}/vagas/status
    X-Detector-Token: <DETECTOR_TOKEN>
    {"fonte": "teste_carros.mp4",
     "controle": "http://192.168.0.10:8765",
     "vagas": [{"codigo": "A1", "status": "ocupada", "desde": "2026-11-19T12:00:00+00:00"}, ...]}

O envio roda numa thread separada: o vídeo não trava esperando a rede. Só o estado mais
recente é enviado (se várias mudanças chegarem juntas, vai uma gravação só) e, mesmo sem
mudanças, o estado é regravado a cada `batimento` segundos para o app saber que a câmera
está no ar.

Substitui o publicar_firebase.py: a ocupação agora mora no MongoDB, não no Firestore.
"""

import json
import os
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone


def ler_env(raiz=None):
    """Lê o .env da raiz do projeto (mesmo arquivo que o backend usa).

    Não usa biblioteca externa: são poucas linhas `CHAVE=valor`. Variáveis já
    definidas no ambiente têm prioridade sobre o arquivo.
    """
    if raiz is None:
        raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    valores = {}
    caminho = os.path.join(raiz, ".env")
    if os.path.exists(caminho):
        with open(caminho, encoding="utf-8") as f:
            for linha in f:
                linha = linha.strip()
                if not linha or linha.startswith("#") or "=" not in linha:
                    continue
                chave, _, valor = linha.partition("=")
                valores[chave.strip()] = valor.strip().strip('"').strip("'")
    for chave in ("VAGAVISION_API", "DETECTOR_TOKEN"):
        if os.environ.get(chave):
            valores[chave] = os.environ[chave]
    return valores


class PublicadorApi:
    """Publica a ocupação na API em segundo plano.

    `endereco` e `token` vêm do .env (VAGAVISION_API e DETECTOR_TOKEN) quando não
    são passados. `extras` são campos fixos a mais no corpo (ex.: controle remoto).
    """

    def __init__(self, fonte, endereco=None, token=None, extras=None, batimento=30.0, timeout=10.0):
        env = ler_env()
        self.endereco = (endereco or env.get("VAGAVISION_API") or "http://localhost:3000/api").rstrip("/")
        self.token = token or env.get("DETECTOR_TOKEN") or ""
        if not self.token:
            raise SystemExit(
                "Erro: DETECTOR_TOKEN não definido.\n"
                "Copie o .env.example da raiz para .env e preencha DETECTOR_TOKEN com o\n"
                "mesmo valor que o backend usa."
            )
        self.url = f"{self.endereco}/vagas/status"
        self.fonte = fonte
        self.extras = extras or {}
        self.batimento = batimento
        self.timeout = timeout
        self._estado = None
        self._novo = threading.Event()
        self._parar = threading.Event()
        self._erro_avisado = False
        self._thread = threading.Thread(target=self._rodar, name="publicador-api", daemon=True)
        self._thread.start()
        print(f"Publicando a ocupação em {self.url}.")

    def publicar(self, vagas, tempo_video):
        """Registra o estado atual (não bloqueia). `vagas` são objetos Vaga do detector,
        com o atributo `codigo` (código da vaga no app, ex.: 'A1')."""
        agora = datetime.now(timezone.utc)
        self._estado = [
            {
                "codigo": v.codigo,
                "status": "ocupada" if v.ocupada else "livre",
                # "desde" é tempo do vídeo; converte para hora real contando para trás
                "desde": (agora - timedelta(seconds=max(0.0, tempo_video - v.desde))).isoformat(),
            }
            for v in vagas
        ]
        self._novo.set()

    def _gravar(self):
        corpo = json.dumps({"fonte": self.fonte, "vagas": self._estado, **self.extras}).encode("utf-8")
        pedido = urllib.request.Request(
            self.url,
            data=corpo,
            method="PUT",
            headers={"Content-Type": "application/json", "X-Detector-Token": self.token},
        )
        with urllib.request.urlopen(pedido, timeout=self.timeout) as r:
            return json.loads(r.read().decode("utf-8"))

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
            except Exception as erro:  # backend fora do ar, token errado...: tenta de novo
                if not self._erro_avisado:
                    print(f"Aviso: não foi possível enviar à API ({self._explicar(erro)}). Tentando de novo...")
                    self._erro_avisado = True
                time.sleep(2)
                self._novo.set()

    @staticmethod
    def _explicar(erro):
        if isinstance(erro, urllib.error.HTTPError):
            try:
                detalhe = json.loads(erro.read().decode("utf-8")).get("erro", "")
            except Exception:
                detalhe = ""
            if erro.code == 401:
                return "X-Detector-Token inválido: confira o DETECTOR_TOKEN no .env"
            return f"HTTP {erro.code}{': ' + detalhe if detalhe else ''}"
        if isinstance(erro, urllib.error.URLError):
            return f"backend inacessível ({erro.reason}); o 'npm start' está rodando?"
        return str(erro)

    def fechar(self):
        """Envia o último estado e encerra a thread."""
        self._parar.set()
        self._novo.set()
        self._thread.join(timeout=10)
        if self._estado is not None:
            try:
                self._gravar()
            except Exception as erro:
                print(f"Aviso: o último estado não foi enviado à API ({self._explicar(erro)}).")
