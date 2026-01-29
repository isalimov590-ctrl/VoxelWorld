#!/bin/bash

# VoxelWorld Server Launcher
# Простой скрипт для запуска выделенного сервера

echo "==================================="
echo "  VoxelWorld Dedicated Server"
echo "==================================="
echo ""

# Путь к исполняемому файлу Godot
GODOT_BINARY="godot"

# Проверяем наличие Godot
if ! command -v $GODOT_BINARY &> /dev/null; then
    echo "Error: Godot not found in PATH"
    echo "Please install Godot 4.6 or set GODOT_BINARY variable"
    exit 1
fi

# Путь к проекту
PROJECT_PATH="$(dirname "$0")/.."

# Параметры запуска
SERVER_SCENE="res://server/dedicated_server.tscn"

echo "Starting server..."
echo "Project path: $PROJECT_PATH"
echo ""

# Запускаем сервер в headless режиме
$GODOT_BINARY --headless --path "$PROJECT_PATH" "$SERVER_SCENE"

echo ""
echo "Server stopped"
