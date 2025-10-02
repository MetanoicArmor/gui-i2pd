#!/bin/bash

echo "🧪 Ручной тест запуска daemon"
echo "============================="

# Проверяем где находится бинарник в приложении
APP_PATH="./I2P-GUI-Fresh.app"
BINARY_PATH="${APP_PATH}/Contents/Resources/i2pd"

echo "📍 Путь к приложению: $APP_PATH"
echo "🔧 Путь к бинарнику: $BINARY_PATH"

if [ -f "$BINARY_PATH" ]; then
    echo "✅ Бинарник найден"
    ls -la "$BINARY_PATH"
    echo ""
    
    echo "🔍 Проверка версии бинарника:"
    "$BINARY_PATH" --version
    echo ""
    
    echo "🧭 Проверка помощи daemon режима:"
    "$BINARY_PATH" --daemon --help 2>&1 | grep -i daemon || echo "Нет информации о daemon режиме"
    echo ""
    
    echo "💿 Создаем тестовую директорию конфигурации:"
    TEST_CONFIG_DIR="/tmp/i2pd-test-$(date +%s)"
    mkdir -p "$TEST_CONFIG_DIR"
    echo "📁 Создана директория: $TEST_CONFIG_DIR"
    echo ""
    
    echo "🚀 Попытка запуска daemon в тестовом режиме:"
    echo "Команда: $BINARY_PATH --daemon --datadir=\"$TEST_CONFIG_DIR\" --pidfile=\"$TEST_CONFIG_DIR/i2pd.pid\" --help"
    
    timeout 5s "$BINARY_PATH" --daemon --datadir="$TEST_CONFIG_DIR" --pidfile="$TEST_CONFIG_DIR/i2pd.pid" 2>&1 | head -10 || echo "Команда прервана или daemon запущен"
    
    sleep 2
    
    echo ""
    echo "📊 Проверка процессов i2pd:"
    ps aux | grep i2pd | grep -v grep || echo "Процессы i2pd не найдены"
    
    echo ""
    echo "📁 Созданные файлы в тестовой директории:"
    ls -la "$TEST_CONFIG_DIR" 2>/dev/null || echo "Директория не создана или пуста"
    
    echo ""
    echo "🧹 Очистка тестовых файлов:"
    if pgrep -f "i2pd.*datadir=$TEST_CONFIG_DIR" >/dev/null; then
        echo "🛑 Остановка тестового daemon..."
        pkill -f "i2pd.*datadir=$TEST_CONFIG_DIR"
        sleep 1
    fi
    rm -rf "$TEST_CONFIG_DIR"
    echo "✅ Очищено"
    
else
    echo "❌ Бинарник не найден по пути: $BINARY_PATH"
    echo "📂 Содержимое директории приложения:"
    ls -la "$APP_PATH/Contents/Resources/"
fi

echo ""
echo "✅ Тест завершен"
