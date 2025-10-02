#!/bin/bash

echo "🔍 Диагностика проблемы с путями в I2P-GUI"
echo "==========================================="

APP_PATH="./I2P-GUI-Fresh.app"
BINARY_PATH="${APP_PATH}/Contents/Resources/i2pd"

echo "📍 Путь к приложению: $APP_PATH"
echo "🔧 Путь к бинарнику: $BINARY_PATH"
echo ""

if [ -f "$BINARY_PATH" ]; then
    echo "✅ Бинарник найден"
    echo "📊 Информация о файле:"
    ls -la "$BINARY_PATH"
    echo ""
    
    echo "⚡ Тест запуска бинарника:"
    echo "Команда: \"$BINARY_PATH\" --version"
    "$BINARY_PATH" --version
    echo ""
    
    echo "🎯 Тест запуска daemon (5 секунд):"
    echo "Команда: \"$BINARY_PATH\" --daemon --pidfile=\"/tmp/debug-test.pid\""
    
    # Запускаем daemon в фоне
    "$BINARY_PATH" --daemon --pidfile="/tmp/debug-test.pid" &
    DAEMON_PID=$!
    
    echo "🚀 Процесс daemon запущен с PID: $DAEMON_PID"
    
    # Проверяем что процесс запустился
    sleep 2
    if ps -p $DAEMON_PID > /dev/null 2>&1; then
        echo "✅ Proцесс daemon все еще работает"
    else
        echo "❌ Процесс daemon завершился быстро"
    fi
    
    # Проверяем новые процессы i2pd
    echo ""
    echo "📋 Все процессы i2pd:"
    ps aux | grep i2pd | grep -v grep || echo "Процессы не найдены"
    
    # Останавливаем тестовый процесс
    echo ""
    echo "🛑 Остановка тестового daemon..."
    if ps -p $DAEMON_PID > /dev/null 2>&1; then
        kill -TERM $DAEMON_PID
        sleep 1
        if ps -p $DAEMON_PID > /dev/null 2>&1; then
            kill -KILL $DAEMON_PID
        fi
    fi
    
    # Очистка через pkill
    pkill -f "i2pd.*pidfile=.*debug-test" 2>/dev/null || true
    
    echo "✅ Тестовый daemon остановлен"
    
else
    echo "❌ Бинарник не найден"
    echo "📂 Содержимое Resources директории:"
    ls -la "$APP_PATH/Contents/Resources/" 2>/dev/null || echo "Директория не существует"
fi

echo ""
echo "🔍 Проверка Bundle path концепции:"
echo "=================================="

# Симулируем что делает Swift Bundle.main.resourceURL?.path
echo "📍 Директория Script: $(dirname "$0")"
echo "📍 Директория App Resources: ${APP_PATH}/Contents/Resources"
echo "📍 Конструкция Bundle path + /i2pd: ${APP_PATH}/Contents/Resources/i2pd"

echo ""
echo "✅ Диагностика завершена"
