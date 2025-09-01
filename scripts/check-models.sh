#!/usr/bin/env bash
set -euo pipefail

DIR="${1:-appdata/models/tcn_vae}"
REQ=( "tcn_encoder_for_edgeinfer.pth" "full_tcn_vae_for_edgeinfer.pth" "model_config.json" )

if [ ! -d "$DIR" ]; then
  echo "Models directory not found: $DIR" >&2
  echo "If using a submodule, run: git submodule update --init --recursive" >&2
  exit 1
fi

MISSING=0
for f in "${REQ[@]}"; do
  if [ ! -f "$DIR/$f" ]; then
    echo "Missing: $DIR/$f" >&2
    MISSING=1
  else
    echo "Found:  $DIR/$f"
  fi
done

if [ "$MISSING" -ne 0 ]; then
  echo "One or more model artifacts are missing. Please populate $(realpath "$DIR")." >&2
  exit 1
fi

echo "All model artifacts present."
