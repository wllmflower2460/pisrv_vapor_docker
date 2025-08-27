#!/bin/bash

CONTAINER_NAME=vapor-app

echo "📦 Checking status of container: $CONTAINER_NAME"

# Check if container is running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "✅ Container is running."
    echo "🔍 Showing last 10 logs:"
    docker logs --tail 10 $CONTAINER_NAME
    exit 0
fi

# Check if container exists but is stopped
if [ "$(docker ps -a -q -f name=$CONTAINER_NAME)" ]; then
    echo "⚠️  Container exists but is not running."
    exit 1
fi

echo "❌ Container does not exist."
exit 2
