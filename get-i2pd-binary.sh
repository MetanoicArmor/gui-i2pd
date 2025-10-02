#!/bin/bash

echo "🔍 Загрузка бинарника i2pd для macOS"
echo "====================================="

# Проверяем архитектуру
ARCH=$(uname -m)
echo "📱 Обнаруженная архитектура: $ARCH"

if [[ "$ARCH" == "arm64" ]]; then
    echo "🍎 Apple Silicon (ARM64) detected"
elif [[ "$ARCH" == "x86_64" ]]; then
    echo "💻 Intel Mac (x86_64) detected"
else
    echo "❌ Неподдерживаемая архитектура: $ARCH"
    exit 1
fi

# URL откуда скачивать (нужно заменить на реальный)
I2PD_URL="https://github.com/PurpleI2P/i2pd/releases/latest/download/i2pd_2.58.0_darwin_$ARCH.tar.gz"
I2PD_DIR="./i2pd-src"

echo "📥 Загружаем i2pd..."
echo "URL: $I2PD_URL"

# Создаем временную директорию
mkdir -p "$I2PD_DIR"
cd "$I2PD_DIR"

# Загружаем (закомментировано, так как нужен реальный URL)
echo "⚠️ Для работы нужно загрузить реальный бинарник i2pd"
echo "📍 Поместите бинарник 'i2pd' в корень проекта"

echo "✅ Скрипт завершен!"
