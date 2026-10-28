@echo off
rem VagaVision - liga o detector para a apresentacao (sem janela; o video aparece no app).
rem Duplo clique para iniciar. Para desligar: Ctrl+C ou feche esta janela.
cd /d "%~dp0"
".venv\Scripts\python.exe" detectar_ocupacao.py ..\videos\teste_carros.mp4 --firebase --repetir --inicio 200 --sem-janela
pause
