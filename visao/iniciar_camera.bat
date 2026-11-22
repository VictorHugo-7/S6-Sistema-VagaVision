@echo off
rem VagaVision - liga o detector para a apresentacao (sem janela; o video aparece no app).
rem Duplo clique para iniciar. Para desligar: Ctrl+C ou feche esta janela.
rem Precisa do backend rodando (na pasta backend: npm start).
cd /d "%~dp0"

set PY=.venv\Scripts\python.exe
set VIDEO=..\videos\teste_carros.mp4

if not exist "%PY%" (
  echo [ERRO] Ambiente Python nao encontrado em visao\.venv
  echo.
  echo Crie uma vez, nesta pasta:
  echo     python -m venv .venv
  echo     .venv\Scripts\python.exe -m pip install -r requirements.txt
  echo.
  pause
  exit /b 1
)

if not exist "%VIDEO%" (
  echo [ERRO] Video nao encontrado: %VIDEO%
  echo Coloque o arquivo teste_carros.mp4 na pasta videos\ da raiz do projeto.
  echo.
  pause
  exit /b 1
)

if not exist "..\.env" (
  echo [ERRO] Arquivo .env nao encontrado na raiz do projeto.
  echo.
  echo Copie o .env.example para .env e preencha MONGODB_URI e DETECTOR_TOKEN:
  echo     copy ..\.env.example ..\.env
  echo.
  echo Para rodar sem enviar ao app ^(so a janela do video^), use:
  echo     .venv\Scripts\python.exe detectar_ocupacao.py %VIDEO% --repetir --inicio 200
  echo.
  pause
  exit /b 1
)

rem Na primeira vez o modelo yolov8s.pt e baixado (~22 MB); pode demorar um pouco.
echo Iniciando o detector... (Ctrl+C para desligar)
echo.
"%PY%" detectar_ocupacao.py "%VIDEO%" --api --repetir --inicio 200 --sem-janela
echo.
echo Detector encerrado.
pause
