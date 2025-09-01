#!/usr/bin/env bash
set -euo pipefail
MODELS_DIR=${1:-appdata/models}
shopt -s nullglob
missing=0
need=("tcn_vae" "TCN-VAE_models")
for d in "${need[@]}"; do
  if [ ! -d "$MODELS_DIR/$d" ]; then
    echo "MISSING: $MODELS_DIR/$d"
    missing=1
  else
    echo "OK: $MODELS_DIR/$d"
  fi
done
if [ $missing -ne 0 ]; then
  echo "One or more model directories missing." >&2
  exit 1
fi
echo "All required model directories present."
