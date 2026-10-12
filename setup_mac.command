#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Trencadís — instal·lació del model de llenguatge (macOS)
# Doble clic per executar-lo. Només cal fer-ho un cop per ordinador.
# Instal·la Ollama, l'engega i descarrega el model (≈ 3 GB).
# ─────────────────────────────────────────────────────────────
MODEL="gemma3:4b"     # el mateix que OLLAMA_MODEL_LOCAL a language_viz/Config.pde

echo "== Trencadís · instal·lant el model de llenguatge =="

if ! command -v ollama >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Instal·lant Ollama amb Homebrew…"
    brew install ollama || exit 1
  else
    echo "No trobo Homebrew. Descarrega i instal·la Ollama des de https://ollama.com/download"
    echo "i torna a executar aquest fitxer."
    open "https://ollama.com/download"
    read -p "Prem Enter per tancar…"
    exit 1
  fi
fi

# Engega Ollama (com a servei si s'ha instal·lat amb Homebrew, o l'app)
if ! curl -s -m 2 http://localhost:11434/api/version >/dev/null; then
  echo "Engegant Ollama…"
  if command -v brew >/dev/null 2>&1 && brew list ollama >/dev/null 2>&1; then
    brew services start ollama
  else
    open -a Ollama 2>/dev/null || (ollama serve >/dev/null 2>&1 &)
  fi
  for i in $(seq 1 30); do curl -s -m 2 http://localhost:11434/api/version >/dev/null && break; sleep 1; done
fi

echo "Descarregant el model $MODEL (només el primer cop)…"
ollama pull "$MODEL" || { echo "No s'ha pogut descarregar el model."; read -p "Prem Enter per tancar…"; exit 1; }

echo
echo "Fet! Ja pots obrir language_viz/language_viz.pde a Processing."
read -p "Prem Enter per tancar…"
