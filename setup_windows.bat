@echo off
chcp 65001 >nul
REM ─────────────────────────────────────────────────────────────
REM Trencadís — preparació de l'ordinador de la sala (Windows)
REM Doble clic per executar-lo. Només cal fer-ho un cop per ordinador.
REM Tot queda dins d'aquesta carpeta (es pot portar sencera en un pen drive):
REM   language_viz\llama.cpp\       llama.cpp per a Windows, GPU (Vulkan: NVIDIA, AMD, Intel)  ≈ 100 MB
REM   language_viz\llama.cpp-cpu\   llama.cpp només CPU (si la GPU falla)                     ≈ 60 MB
REM   language_viz\models\          el model local, Qwen3.5 2B Instruct                        ≈ 1,3 GB
REM El que ja hi és (copiat del pen drive) no es torna a descarregar.
REM Les biblioteques de Processing (Spout, Minim, The MidiBus) ja són a language_viz\code\.
REM ─────────────────────────────────────────────────────────────
cd /d "%~dp0"
set "SKETCH=language_viz"
set "LLAMA_TAG=b11932"
set "LLAMA_URL=https://github.com/ggml-org/llama.cpp/releases/download/%LLAMA_TAG%"
set "MODEL_DIR=%SKETCH%\models"
set "MODEL_FILE=Qwen3.5-2B-Q4_K_M.gguf"
REM (el mateix que LLAMA_MODEL_FILE a language_viz\Config.pde)
set "MODEL_URL=https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/%MODEL_FILE%"

echo == Trencadís · preparant l'ordinador de la sala ==
echo.

call :llama "%SKETCH%\llama.cpp" "llama-%LLAMA_TAG%-bin-win-vulkan-x64.zip" || goto :fail
call :llama "%SKETCH%\llama.cpp-cpu" "llama-%LLAMA_TAG%-bin-win-cpu-x64.zip" || goto :fail

if not exist "%MODEL_DIR%" mkdir "%MODEL_DIR%"
if exist "%MODEL_DIR%\%MODEL_FILE%" (
  echo El model ja hi és: %MODEL_DIR%\%MODEL_FILE%
) else (
  echo Descarregant %MODEL_FILE% ^(≈ 1,3 GB; si es talla, torna-hi i continua^)...
  curl -L --fail -C - -o "%MODEL_DIR%\%MODEL_FILE%.part" "%MODEL_URL%" || goto :fail
  move /y "%MODEL_DIR%\%MODEL_FILE%.part" "%MODEL_DIR%\%MODEL_FILE%" >nul
)

echo.
echo L'ordinador no s'adormirà ni apagarà les pantalles (endollat)...
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-ac 0

echo.
echo Fet! Falta només Processing 4 (https://processing.org/download): obre
echo language_viz\language_viz.pde i prem Play. El sketch engega el model sol.
pause
exit /b 0

REM ── llama.cpp: descarrega i descomprimeix el zip a la carpeta, si encara no hi és ──
:llama
if exist "%~1\llama-server.exe" (
  echo llama.cpp ja hi és: %~1
  exit /b 0
)
echo Descarregant %~2...
curl -L --fail -o "%TEMP%\%~2" "%LLAMA_URL%/%~2" || exit /b 1
if not exist "%~1" mkdir "%~1"
tar -xf "%TEMP%\%~2" -C "%~1" || exit /b 1
del "%TEMP%\%~2"
exit /b 0

:fail
echo.
echo No s'ha pogut completar (sense internet?). Si tens el pen drive, copia'n les carpetes
echo language_viz\llama.cpp, language_viz\llama.cpp-cpu i language_viz\models aquí.
pause
exit /b 1
