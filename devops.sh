#!/bin/bash

CONTAINER_NAME=vapor-app

show_menu() {
    echo ""
    echo "📦 Data Dogs DevOps Toolkit for $CONTAINER_NAME"
    echo "-----------------------------------------------"
    echo "1) Rebuild & Run Container"
    echo "2) Restart Container Only"
    echo "3) Check Container Status"
    echo "4) View Live Logs"
    echo "5) Stop & Remove Container"
    echo "6) Exit"
    echo ""
    read -p "Choose an option [1-6]: " choice
    echo ""
}

while true; do
    show_menu
    case $choice in
        1)
            ./rebuild.sh
            break
            ;;
        2)
            ./restart.sh
            break
            ;;
        3)
            ./status.sh
            break
            ;;
        4)
            ./logs.sh
            break
            ;;
        5)
            echo "🛑 Stopping and removing container..."
            docker stop $CONTAINER_NAME 2>/dev/null
            docker rm $CONTAINER_NAME 2>/dev/null
            echo "✅ Done."
            break
            ;;
        6)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Try again."
            ;;
    esac
done
