#!/usr/bin/env bash
session_zip="$1"
session_dir="/sessions/$(basename "${session_zip%.*}")"
mkdir -p "$session_dir"
unzip -o "$session_zip" -d "$session_dir"
cd "$(dirname "$0")/../h8-examples"
source setup_env.sh
python3 basic_pipelines/detection.py \
  --hef-path local_resources/hefs/yolov10_640x640.hef \
  --input-path "$session_dir/session.mp4" \
  --log-json "$session_dir/output-detections.json"
echo "Inference complete for $session_zip ? $session_dir/output-detections.json"
