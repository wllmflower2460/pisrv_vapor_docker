#!/bin/bash
set -e

echo "🔨 Building vapor-app Docker image..."
docker build -t vapor-app:latest .

echo "🗑 Stopping and removing old container..."
docker compose down

echo "🚀 Starting new container..."
docker compose up -d --build

echo "⏳ Waiting for health check..."
sleep 5

curl -I http://localhost:8080/healthz || echo "⚠️ Health check failed!"

echo "✅ Deploy complete."
