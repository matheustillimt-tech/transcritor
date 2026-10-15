#!/bin/zsh
# Instala tudo que o Transcritor precisa e abre o app.
# Pode rodar de novo sem medo: pula o que já estiver instalado.
set -euo pipefail
cd "$(dirname "$0")"

MODEL_DIR="$HOME/.cache/whisper-models"
MODEL="$MODEL_DIR/ggml-large-v3-turbo.bin"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "⚠️  Este Mac não é Apple Silicon. Vai funcionar, mas a transcrição fica bem mais lenta."
fi

# 1. Ferramentas de linha de comando da Apple (traz o compilador Swift)
if ! xcode-select -p >/dev/null 2>&1; then
  echo "→ Instalando as Command Line Tools da Apple. Clique em “Instalar” na janela que abrir."
  xcode-select --install || true
  until xcode-select -p >/dev/null 2>&1; do sleep 10; done
fi

# 2. Homebrew
if ! command -v brew >/dev/null 2>&1; then
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$b" ]] && eval "$("$b" shellenv)" && break
  done
fi
if ! command -v brew >/dev/null 2>&1; then
  echo "→ Instalando o Homebrew (vai pedir a senha do Mac)."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
fi

# 3. Motor do Whisper
if ! command -v whisper-server >/dev/null 2>&1; then
  echo "→ Instalando whisper-cpp…"
  brew install whisper-cpp
fi

# 4. Modelo (~1,6 GB, só na primeira vez)
if [[ ! -s "$MODEL" ]]; then
  echo "→ Baixando o modelo Whisper large-v3-turbo (~1,6 GB)…"
  mkdir -p "$MODEL_DIR"
  curl -L --fail --progress-bar -C - -o "$MODEL.part" "$MODEL_URL"
  mv "$MODEL.part" "$MODEL"
fi

# 5. Compila, instala em /Applications e abre
./build.sh

echo ""
echo "🎙️  Pronto! Falta só liberar 2 permissões quando o macOS pedir:"
echo "   1. Microfone: Permitir."
echo "   2. Ajustes do Sistema › Privacidade e Segurança › Acessibilidade: ative o Transcritor."
echo "   Dica: em Ajustes › Teclado, deixe “Pressionar a tecla 🌐” como “Não fazer nada”."
