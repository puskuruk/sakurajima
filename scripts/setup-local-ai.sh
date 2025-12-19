#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
# 🧠 SAKURAJIMA LOCAL AI SETUP

info(){ printf "ℹ️  %s\n" "$*"; }
ok(){ printf "✅ %s\n" "$*"; }
warn(){ printf "⚠️  %s\n" "$*"; }

MODEL="llama3.2"

if ! command -v ollama >/dev/null 2>&1; then
  warn "Ollama not found. Skipping Local AI setup."
  exit 0
fi

info "Ensuring Ollama service is running..."

# Function to check if Ollama is up
is_ollama_up() {
  curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/tags | grep -q "200"
}

if ! is_ollama_up; then
  info "Starting Ollama service..."
  brew services start ollama || true
  
  # Wait loop
  for i in {1..10}; do
    if is_ollama_up; then
      ok "Ollama started."
      break
    fi
    sleep 2
    printf "."
  done
  echo
fi

if ! is_ollama_up; then
  warn "Could not start Ollama. Please check 'brew services info ollama'."
  exit 1
fi

info "Checking for model: $MODEL"
if ollama list | grep -q "$MODEL"; then
  ok "Model $MODEL already exists."
else
  info "Pulling $MODEL (this may take a while)..."
  ollama pull "$MODEL"
  ok "Model $MODEL pulled."
fi

ok "Local AI setup complete."
