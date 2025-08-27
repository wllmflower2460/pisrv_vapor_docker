#!/bin/bash

CONTAINER_NAME=vapor-app

echo "🔁 Restarting container '$CONTAINER_NAME'..."

# Stop the container if it's running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "🛑 Stopping running container..."
    docker stop $CONTAINER_NAME
fi

# Remove it if it exists
if [ "$(docker ps -a -q -f name=$CONTAINER_NAME)" ]; then
    echo "🧹 Removing container..."
    docker rm $CONTAINER_NAME
fi

# Run it again without rebuilding
echo "🚀 Starting container from existing image..."
docker run -it \
  -p 8080:8080 \
  -v ~/vapor-docker:/app \
  --name $CONTAINER_NAME \
  $CONTAINER_NAME
