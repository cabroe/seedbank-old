#!/usr/bin/env bash
# One-time setup: download GTE-Small from Hugging Face and convert to .gtemodel

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELS_DIR="$PROJECT_ROOT/models"
GTE_SMALL_DIR="$MODELS_DIR/gte-small"
OUTPUT_FILE="$MODELS_DIR/gte-small.gtemodel"
GTE_GO_RAW="https://raw.githubusercontent.com/rcarmo/gte-go/main"
VENV="$PROJECT_ROOT/.venv"

cd "$PROJECT_ROOT"
mkdir -p "$MODELS_DIR"

# Python with deps: use PYTHON if it has safetensors+requests, else use/create .venv
if [[ -n "${PYTHON}" ]] && "$PYTHON" -c "import safetensors, requests" 2>/dev/null; then
  :
elif [[ -x "$VENV/bin/python" ]] && "$VENV/bin/python" -c "import safetensors, requests" 2>/dev/null; then
  PYTHON="$VENV/bin/python"
else
  echo "==> Setting up .venv and installing safetensors, requests..."
  if [[ ! -x "$VENV/bin/python" ]] || ! "$VENV/bin/python" -c "import pip" 2>/dev/null; then
    rm -rf "$VENV"
    py="${PYTHON:-python3}"
    if ! "$py" -m venv "$VENV" 2>/dev/null; then
      ver=$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "3")
      echo "Could not create venv. On Debian/Ubuntu: sudo apt install python${ver}-venv"
      exit 1
    fi
  fi
  PYTHON="$VENV/bin/python"
  "$PYTHON" -m pip install -q safetensors requests
fi

if [[ -f "$OUTPUT_FILE" ]]; then
  echo "==> $OUTPUT_FILE already exists. Remove it to re-download."
  exit 0
fi

echo "==> Downloading GTE-Small from Hugging Face into $GTE_SMALL_DIR..."
mkdir -p "$GTE_SMALL_DIR"
"$PYTHON" - "$GTE_SMALL_DIR" << 'PY'
import os, sys, requests
from pathlib import Path
base = "https://huggingface.co/thenlper/gte-small/resolve/main"
files = ["config.json", "vocab.txt", "tokenizer_config.json", "special_tokens_map.json", "model.safetensors"]
out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
for name in files:
    url = f"{base}/{name}"
    path = out / name
    if path.exists():
        print(f"  skip {name}")
        continue
    print(f"  fetch {name}")
    r = requests.get(url, stream=True)
    r.raise_for_status()
    with open(path, "wb") as f:
        for chunk in r.iter_content(8192):
            if chunk:
                f.write(chunk)
PY

echo "==> Downloading convert_model.py from gte-go..."
curl -sSL -o "$SCRIPT_DIR/convert_model.py" "$GTE_GO_RAW/convert_model.py"

echo "==> Converting to .gtemodel..."
"$PYTHON" "$SCRIPT_DIR/convert_model.py" "$GTE_SMALL_DIR" "$OUTPUT_FILE"

echo "==> Done. Model: $OUTPUT_FILE"
