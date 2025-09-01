#!/usr/bin/env bash
set -euo pipefail
docker volume create swiftpm-cache >/dev/null
docker volume create swiftpm-config >/dev/null

docker run --rm   -v "$PWD":/app -w /app   -v swiftpm-cache:/root/.cache   -v swiftpm-config:/root/.swiftpm   swift:5.10-jammy bash -lc '
    swift package resolve &&
    swift test -Xswiftc -enable-testing -v --jobs 2
  '
