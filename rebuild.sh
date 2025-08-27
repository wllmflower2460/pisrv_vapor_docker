#!/bin/bash

CONTAINER_NAME=vapor-app

echo "🔍 Checking if container '$CONTAINER_NAME' is already running..."

# Check if container is running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "🛑 Stopping running container..."
    docker stop $CONTAINER_NAME
fi

# Check if container exists (even if stopped)
if [ "$(docker ps -a -q -f name=$CONTAINER_NAME)" ]; then
    echo "🧹 Removing old container..."
    docker rm $CONTAINER_NAME
fi

echo "🔨 Rebuilding Docker image..."
docker build -t $CONTAINER_NAME .

echo "🚀 Starting new container with volume mount..."
docker run -it \
  -p 8082:8080 \
  -v ~/vapor-docker:/app \
  --name $CONTAINER_NAME \
  $CONTAINER_NAME

