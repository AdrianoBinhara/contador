#!/bin/sh
# Instala o Contador:
#   curl -fsSL https://raw.githubusercontent.com/AdrianoBinhara/contador/main/install.sh | sh
set -e
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo "Baixando o Contador..."
curl -fsSL https://github.com/AdrianoBinhara/contador/releases/latest/download/Contador.zip -o "$tmp/Contador.zip"
ditto -x -k "$tmp/Contador.zip" "$tmp"
pkill -x Contador 2>/dev/null || true
# /Applications pode ser bloqueado pro Terminal (proteção do macOS); nesse caso usa ~/Applications
dest=/Applications
if ! { rm -rf "$dest/Contador.app" && ditto "$tmp/Contador.app" "$dest/Contador.app"; } 2>/dev/null; then
  dest="$HOME/Applications"
  mkdir -p "$dest"
  rm -rf "$dest/Contador.app"
  ditto "$tmp/Contador.app" "$dest/Contador.app"
fi
open "$dest/Contador.app"
echo "Pronto: $dest/Contador.app"
