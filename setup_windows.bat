@echo off
chcp 65001 >nul
REM ─────────────────────────────────────────────────────────────
REM Trencadís — instal·lació del model de llenguatge local (Windows)
REM Doble clic per executar-lo. Només cal fer-ho un cop per ordinador.
REM Instal·la llama.cpp (winget) i descarrega Salamandra 7B Instruct 2606 (BSC, ≈ 4,9 GB).
REM El sketch engega i atura el servidor sol (LLAMA_AUTOSTART a language_viz\Config.pde).
REM ─────────────────────────────────────────────────────────────
cd /d "%~dp0"
set "MODEL_DIR=language_viz\models"
set "MODEL_FILE=salamandra-7b-instruct-2606.i1-Q4_K_M.gguf"
REM (el mateix que LLAMA_MODEL_FILE a language_viz\Config.pde)
set "MODEL_URL=https://huggingface.co/mradermacher/salamandra-7b-instruct-2606-i1-GGUF/resolve/main/%MODEL_FILE%"

echo == Trencadís · instal·lant el model de llenguatge local ==

where llama-server >nul 2>nul
if errorlevel 1 (
  if not exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\llama-server.exe" (
    echo Instal·lant llama.cpp amb winget...
    winget install --id ggml.llamacpp -e --accept-source-agreements --accept-package-agreements
    if errorlevel 1 (
      echo No s'ha pogut instal·lar. Descarrega llama.cpp des de https://github.com/ggml-org/llama.cpp/releases
      echo i posa la ruta de llama-server.exe a LLAMA_SERVER, a language_viz\Config.pde.
      start https://github.com/ggml-org/llama.cpp/releases
      pause
      exit /b 1
    )
  )
)

if not exist "%MODEL_DIR%" mkdir "%MODEL_DIR%"
if exist "%MODEL_DIR%\%MODEL_FILE%" (
  echo El model ja hi és: %MODEL_DIR%\%MODEL_FILE%
) else (
  echo Descarregant %MODEL_FILE% ^(≈ 4,9 GB, només el primer cop; si es talla, torna-hi i continua^)...
  curl -L --fail -C - -o "%MODEL_DIR%\%MODEL_FILE%.part" "%MODEL_URL%"
  if errorlevel 1 (
    echo No s'ha pogut descarregar el model.
    pause
    exit /b 1
  )
  move /y "%MODEL_DIR%\%MODEL_FILE%.part" "%MODEL_DIR%\%MODEL_FILE%" >nul
)

echo.
echo Fet! Obre language_viz\language_viz.pde a Processing: el sketch engega el model sol.
pause
