#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Trencadís — instal·lació del model de llenguatge local (macOS)
# Doble clic per executar-lo. Només cal fer-ho un cop per ordinador.
# Instal·la llama.cpp (Homebrew) i descarrega Qwen3.5 2B Instruct (≈ 1,3 GB).
# El sketch engega i atura el servidor sol (LLAMA_AUTOSTART a language_viz/Config.pde).
# ─────────────────────────────────────────────────────────────
cd "$(dirname "$0")"
MODEL_DIR="language_viz/models"
MODEL_FILE="Qwen3.5-2B-Q4_K_M.gguf"   # el mateix que LLAMA_MODEL_FILE a Config.pde
MODEL_URL="https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/$MODEL_FILE"

echo "== Trencadís · instal·lant el model de llenguatge local =="

if ! command -v llama-server >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/llama-server ] && [ ! -x /usr/local/bin/llama-server ]; then
  if command -v brew >/dev/null 2>&1; then
    echo "Instal·lant llama.cpp amb Homebrew…"
    brew install llama.cpp || { read -p "No s'ha pogut instal·lar llama.cpp. Prem Enter per tancar…"; exit 1; }
  else
    echo "No trobo Homebrew. Instal·la'l des de https://brew.sh i torna a executar aquest fitxer."
    open "https://brew.sh"
    read -p "Prem Enter per tancar…"
    exit 1
  fi
fi

mkdir -p "$MODEL_DIR"
if [ -f "$MODEL_DIR/$MODEL_FILE" ]; then
  echo "El model ja hi és: $MODEL_DIR/$MODEL_FILE"
else
  echo "Descarregant $MODEL_FILE (≈ 1,3 GB, només el primer cop; si es talla, torna-hi i continua)…"
  curl -L --fail -C - -o "$MODEL_DIR/$MODEL_FILE.part" "$MODEL_URL" \
    && mv "$MODEL_DIR/$MODEL_FILE.part" "$MODEL_DIR/$MODEL_FILE" \
    || { echo "No s'ha pogut descarregar el model."; read -p "Prem Enter per tancar…"; exit 1; }
fi

echo
echo "Fet! Obre language_viz/language_viz.pde a Processing: el sketch engega el model sol."
read -p "Prem Enter per tancar…"
