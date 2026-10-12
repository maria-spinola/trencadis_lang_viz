@echo off
chcp 65001 >nul
REM ─────────────────────────────────────────────────────────────
REM Trencadís — instal·lació del model de llenguatge (Windows)
REM Doble clic per executar-lo. Només cal fer-ho un cop per ordinador.
REM Instal·la Ollama, l'engega i descarrega el model (≈ 3 GB).
REM ─────────────────────────────────────────────────────────────
set MODEL=gemma3:4b
REM (el mateix que OLLAMA_MODEL_LOCAL a language_viz\Config.pde)

echo == Trencadís · instal·lant el model de llenguatge ==

set OLLAMA=ollama
where ollama >nul 2>nul
if errorlevel 1 (
  if exist "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" (
    set "OLLAMA=%LOCALAPPDATA%\Programs\Ollama\ollama.exe"
  ) else (
    echo Instal·lant Ollama amb winget...
    winget install --id Ollama.Ollama -e --accept-source-agreements --accept-package-agreements
    if errorlevel 1 (
      echo No s'ha pogut instal·lar. Descarrega Ollama des de https://ollama.com/download i torna a executar aquest fitxer.
      start https://ollama.com/download
      pause
      exit /b 1
    )
    set "OLLAMA=%LOCALAPPDATA%\Programs\Ollama\ollama.exe"
  )
)

REM Engega Ollama si no està en marxa
curl -s -m 2 http://localhost:11434/api/version >nul 2>nul
if errorlevel 1 (
  echo Engegant Ollama...
  start "" "%OLLAMA%" serve
  timeout /t 5 >nul
)

echo Descarregant el model %MODEL% (només el primer cop)...
"%OLLAMA%" pull %MODEL%
if errorlevel 1 (
  echo No s'ha pogut descarregar el model.
  pause
  exit /b 1
)

echo.
echo Fet! Ja pots obrir language_viz\language_viz.pde a Processing.
pause
