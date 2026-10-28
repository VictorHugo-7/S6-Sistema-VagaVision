"""
controle_remoto.py — VagaVision

Servidor HTTP que o detectar_ocupacao.py liga para o app (ou o navegador) ver o vídeo
anotado e controlar a reprodução: pausar, continuar, pular, voltar ao início e mudar a
velocidade. Roda em threads à parte; o laço do vídeo só entrega quadros e lê comandos.

    GET  /             página com o vídeo e os controles (abre em outra aba do navegador)
    GET  /video.mjpg   vídeo ao vivo (MJPEG, toca direto numa <img>)
    GET  /quadro.jpg   último quadro (o app busca um atrás do outro)
    GET  /estado       {"pausado", "posicao", "duracao", "velocidade", "livres", "ocupadas", "total"}
    POST /comando?acao=...&valor=...
         acao: pausar | continuar | alternar | reiniciar | pular (valor = segundos, pode ser
               negativo) | ir (valor = segundo do vídeo) | velocidade (valor = 0.5, 1, 2, 4...)

Aceita conexões de outros aparelhos da rede (o celular no mesmo Wi-Fi do computador).
"""

import json
import queue
import socket
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import cv2

ACOES = {"pausar", "continuar", "alternar", "reiniciar", "pular", "ir", "velocidade"}
VELOCIDADE_MIN, VELOCIDADE_MAX = 0.25, 8.0
QUADROS_POR_SEGUNDO = 12  # do vídeo enviado; mais que isso só gasta rede
LARGURA_ENVIO = 1280


def ip_local():
    """IP do computador na rede local (o que o celular usa para chegar até ele)."""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        try:
            s.connect(("10.255.255.255", 1))  # não envia nada; só escolhe a interface de saída
            return s.getsockname()[0]
        except OSError:
            return "127.0.0.1"


class ServidorControle:
    def __init__(self, porta, titulo="VagaVision"):
        self.titulo = titulo
        self.comandos = queue.Queue()
        self._estado = {}
        self._jpeg = None
        self._numero = 0
        self._ultimo_envio = 0.0
        self._ultimo_pedido = 0.0
        self._novo_quadro = threading.Condition()
        self._parar = threading.Event()

        servidor = self

        class Atendente(_Atendente):
            controle = servidor

        try:
            self._http = _Servidor(("0.0.0.0", porta), Atendente)
        except OSError as erro:
            raise SystemExit(f"Erro: a porta {porta} já está em uso ({erro}). Use --porta com outro número.")
        self.url = f"http://{ip_local()}:{porta}"
        threading.Thread(target=self._http.serve_forever, name="controle-remoto", daemon=True).start()

    # ---- chamado pelo laço do vídeo ----

    def enviar_quadro(self, img):
        """Guarda o quadro anotado para quem estiver assistindo. Só codifica se alguém pediu
        vídeo nos últimos segundos e respeitando QUADROS_POR_SEGUNDO."""
        agora = time.time()
        if agora - self._ultimo_pedido > 5 or agora - self._ultimo_envio < 1 / QUADROS_POR_SEGUNDO:
            return
        self._ultimo_envio = agora
        if img.shape[1] > LARGURA_ENVIO:
            fator = LARGURA_ENVIO / img.shape[1]
            img = cv2.resize(img, None, fx=fator, fy=fator, interpolation=cv2.INTER_AREA)
        ok, jpeg = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 75])
        if ok:
            with self._novo_quadro:
                self._jpeg = jpeg.tobytes()
                self._numero += 1
                self._novo_quadro.notify_all()

    def atualizar_estado(self, **estado):
        self._estado = estado

    def proximo_comando(self):
        """Devolve (acao, valor) ou None se não houver comando esperando."""
        try:
            return self.comandos.get_nowait()
        except queue.Empty:
            return None

    def fechar(self):
        self._parar.set()
        with self._novo_quadro:
            self._novo_quadro.notify_all()
        self._http.shutdown()
        self._http.server_close()

    # ---- usado pelo atendente HTTP ----

    def _esperar_quadro(self, numero_visto, timeout):
        self._ultimo_pedido = time.time()
        with self._novo_quadro:
            self._novo_quadro.wait_for(
                lambda: (self._jpeg is not None and self._numero != numero_visto) or self._parar.is_set(),
                timeout=timeout,
            )
            return self._numero, self._jpeg


class _Servidor(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):
        if isinstance(sys.exc_info()[1], ConnectionError):
            return  # o app fechou a janela no meio de um envio: normal, sem traceback
        super().handle_error(request, client_address)


class _Atendente(BaseHTTPRequestHandler):
    controle: ServidorControle = None
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass  # sem uma linha no terminal a cada quadro

    def _cabecalhos(self, codigo, tipo, tamanho=None):
        self.send_response(codigo)
        self.send_header("Content-Type", tipo)
        self.send_header("Cache-Control", "no-store")
        # o app web roda em outra porta (outra origem) e precisa poder ler as respostas
        self.send_header("Access-Control-Allow-Origin", "*")
        if tamanho is not None:
            self.send_header("Content-Length", str(tamanho))
        self.end_headers()

    def _responder(self, codigo, corpo, tipo):
        self._cabecalhos(codigo, tipo, len(corpo))
        self.wfile.write(corpo)

    def _json(self, dados, codigo=200):
        self._responder(codigo, json.dumps(dados).encode(), "application/json")

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        url = urlparse(self.path)
        caminho = url.path
        if caminho == "/":
            pagina = PAGINA.replace("{titulo}", self.controle.titulo).encode()
            self._responder(200, pagina, "text/html; charset=utf-8")
        elif caminho == "/estado":
            self._json(self.controle._estado)
        elif caminho == "/quadro.jpg":
            # ?n=<número do último quadro recebido>: espera um quadro mais novo que esse
            try:
                visto = int(parse_qs(url.query).get("n", ["-1"])[0])
            except ValueError:
                visto = -1
            numero, jpeg = self.controle._esperar_quadro(visto, 2.0)
            if jpeg is None:
                self._json({"erro": "ainda sem vídeo"}, 503)
                return
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Content-Length", str(len(jpeg)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Expose-Headers", "X-Quadro")
            self.send_header("X-Quadro", str(numero))
            self.end_headers()
            self.wfile.write(jpeg)
        elif caminho == "/video.mjpg":
            self._mjpeg()
        else:
            self._json({"erro": "não encontrado"}, 404)

    def _mjpeg(self):
        self.send_response(200)
        self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=quadro")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Connection", "close")
        self.end_headers()
        visto = None
        try:
            while not self.controle._parar.is_set():
                visto, jpeg = self.controle._esperar_quadro(visto, 2.0)
                if jpeg is None:
                    continue
                self.wfile.write(
                    b"--quadro\r\nContent-Type: image/jpeg\r\nContent-Length: "
                    + str(len(jpeg)).encode() + b"\r\n\r\n" + jpeg + b"\r\n"
                )
        except (ConnectionError, OSError):
            pass  # a aba foi fechada
        self.close_connection = True

    def do_POST(self):
        url = urlparse(self.path)
        if url.path != "/comando":
            self._json({"erro": "não encontrado"}, 404)
            return
        if int(self.headers.get("Content-Length") or 0):
            self.rfile.read(int(self.headers["Content-Length"]))
        parametros = parse_qs(url.query)
        acao = parametros.get("acao", [""])[0]
        valor = None
        if acao not in ACOES:
            self._json({"erro": f"ação inválida: '{acao}'"}, 400)
            return
        if acao in ("pular", "ir", "velocidade"):
            try:
                valor = float(parametros.get("valor", [""])[0])
            except ValueError:
                self._json({"erro": f"'{acao}' precisa de um valor numérico"}, 400)
                return
            if acao == "velocidade":
                valor = min(max(valor, VELOCIDADE_MIN), VELOCIDADE_MAX)
        self.controle.comandos.put((acao, valor))
        self._json({"ok": True})


PAGINA = """<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{titulo} - câmera</title>
<style>
  :root { color-scheme: dark; --fundo: #0f1115; --painel: #1a1d24; --borda: #2b303b; --texto: #e6e8ec;
          --fraco: #9aa3b2; --verde: #22c55e; --vermelho: #ef4444; }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--fundo); color: var(--texto); font: 15px system-ui, sans-serif;
         min-height: 100vh; display: flex; flex-direction: column; align-items: center; padding: 16px; gap: 12px; }
  h1 { font-size: 17px; margin: 0; align-self: stretch; max-width: 1280px; margin-inline: auto; width: 100%; }
  .video { width: 100%; max-width: 1280px; aspect-ratio: 16 / 9; background: #000; border-radius: 10px;
           overflow: hidden; border: 1px solid var(--borda); }
  .video img { width: 100%; height: 100%; object-fit: contain; display: block; }
  .painel { width: 100%; max-width: 1280px; background: var(--painel); border: 1px solid var(--borda);
            border-radius: 10px; padding: 12px; display: flex; flex-direction: column; gap: 10px; }
  .linha { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
  button { background: #262b35; color: var(--texto); border: 1px solid var(--borda); border-radius: 8px;
           padding: 8px 12px; font: inherit; cursor: pointer; min-width: 44px; }
  button:hover { background: #303644; }
  button.ativo { background: var(--verde); color: #04130a; border-color: var(--verde); font-weight: 700; }
  input[type=range] { flex: 1; min-width: 160px; accent-color: var(--verde); }
  .tempo { font-variant-numeric: tabular-nums; color: var(--fraco); min-width: 110px; text-align: right; }
  .contagem b { color: var(--verde); } .contagem i { color: var(--vermelho); font-style: normal; font-weight: 700; }
  .erro { color: var(--vermelho); }
</style>
</head>
<body>
<h1>{titulo} — câmera <span id="aviso" class="erro"></span></h1>
<div class="video"><img id="video" src="video.mjpg" alt="Vídeo da câmera com as vagas"></div>
<div class="painel">
  <div class="linha">
    <input id="barra" type="range" min="0" max="1" step="0.1" value="0" aria-label="Posição do vídeo">
    <span class="tempo" id="tempo">--:-- / --:--</span>
  </div>
  <div class="linha">
    <button onclick="comando('reiniciar')" title="Voltar ao início">⏮</button>
    <button onclick="comando('pular', -10)" title="Voltar 10 s">−10s</button>
    <button id="play" onclick="comando('alternar')" title="Pausar / continuar">⏸</button>
    <button onclick="comando('pular', 10)" title="Avançar 10 s">+10s</button>
    <span style="flex:1"></span>
    <span id="velocidades"></span>
  </div>
  <div class="linha contagem" id="contagem"></div>
</div>
<script>
const VELOCIDADES = [0.5, 1, 2, 4];
const barra = document.getElementById('barra');
let arrastando = false, estado = {};
const fmt = s => { s = Math.max(0, Math.floor(s || 0)); return String(Math.floor(s / 60)).padStart(2, '0') + ':' + String(s % 60).padStart(2, '0'); };
function comando(acao, valor) {
  const q = new URLSearchParams({ acao }); if (valor !== undefined) q.set('valor', valor);
  fetch('comando?' + q, { method: 'POST' }).then(atualizar);
}
document.getElementById('velocidades').innerHTML = VELOCIDADES.map(v =>
  `<button data-v="${v}" onclick="comando('velocidade', ${v})">${String(v).replace('.', ',')}x</button>`).join(' ');
barra.addEventListener('input', () => { arrastando = true; document.getElementById('tempo').textContent = fmt(barra.value) + ' / ' + fmt(estado.duracao); });
barra.addEventListener('change', () => { arrastando = false; comando('ir', barra.value); });
async function atualizar() {
  try {
    estado = await (await fetch('estado')).json();
    document.getElementById('aviso').textContent = '';
    barra.max = estado.duracao || 1;
    if (!arrastando) { barra.value = estado.posicao; document.getElementById('tempo').textContent = fmt(estado.posicao) + ' / ' + fmt(estado.duracao); }
    document.getElementById('play').textContent = estado.pausado ? '▶' : '⏸';
    document.querySelectorAll('[data-v]').forEach(b => b.classList.toggle('ativo', Number(b.dataset.v) === estado.velocidade));
    document.getElementById('contagem').innerHTML = `Livres: <b>${estado.livres}</b> · Ocupadas: <i>${estado.ocupadas}</i> · Total: ${estado.total}`;
  } catch (e) {
    document.getElementById('aviso').textContent = '(detector desligado)';
  }
}
setInterval(atualizar, 500); atualizar();
// se o detector reiniciar, reconecta o vídeo
document.getElementById('video').onerror = e => setTimeout(() => { e.target.src = 'video.mjpg?' + Date.now(); }, 2000);
</script>
</body>
</html>
"""
