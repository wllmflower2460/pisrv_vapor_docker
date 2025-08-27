#!/bin/bash

CONTAINER_NAME=vapor-app

echo "📖 Tailing logs for container: $CONTAINER_NAME"

# Check if container exists
if [ "$(docker ps -a -q -f name=$CONTAINER_NAME)" ]; then
    docker logs -f $CONTAINER_NAME
else
    echo "❌ Container '$CONTAINER_NAME' not found."
    exit 1
fi
