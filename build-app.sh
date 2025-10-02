#!/bin/bash

echo "🔨 Сборка I2PD GUI приложения"
echo "================================"

# Проверяем наличие Swift
if ! command -v swiftc &> /dev/null; then
    echo "❌ Swift компилятор не найден"
    exit 1
fi

echo "📦 Компиляция приложения..."

# Компилируем приложение
swiftc \
    -o i2pd-gui-app \
    i2pd-gui-main.swift \
    -framework Cocoa \
    -framework SwiftUI \
    -target arm64-apple-macos14.0

if [ $? -eq 0 ]; then
    echo "✅ Компиляция успешна!"
    echo "📁 Исполняемый файл: i2pd-gui-app"
    echo ""
    echo "🚀 Для запуска приложения:"
    echo "   ./i2pd-gui-app"
    echo ""
    echo "📋 Функции приложения:"
    echo "   • Управление I2P daemon"
    echo "   • Просмотр статуса в реальном времени"
    echo "   • Система логирования"
    echo "   • Современный macOS интерфейс"
else
    echo "❌ Ошибка компиляции"
    exit 1
fi
