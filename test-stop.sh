#!/bin/bash

echo "🧪 Тест логики остановки i2pd daemon"
echo "===================================="

# Сначала запускаем daemon для тестирования
echo "🚀 Создаем тестовый daemon процесс..."
sleep 3 &
DAEMON_PID=$!
sleep 1

echo "📍 Запущен тестовый процесс: $DAEMON_PID"

# Тестируем новую логику остановки i2pd
echo "🔍 Тестируем логику поиска процессов..."
RESULT=$(ps aux | awk '/i2pd.*daemon/ && !/I2P-GUI/ {print $2}')
echo "📍 Найденные daemon процессы: $RESULT"

echo "⏹️ Тестируем команду остановки..."

# Выполняем саму команду остановки
STOP_COMMAND='
echo "🔍 Остановка i2pd daemon..." &&

# Простая и эффективная остановка всех процессов i2pd daemon
DAEMON_PIDS=$(ps aux | awk "/i2pd.*daemon/ && !/I2P-GUI/ {print \$2}") &&

if [ -n "$DAEMON_PIDS" ]; then
    echo "📍 Найдены процессы i2pd daemon: $DAEMON_PIDS" &&
    for PID in $DAEMON_PIDS; do
        echo "🛑 Отправляем SIGTERM процессу $PID..." &&
        kill -TERM $PID 2>/dev/null &&
        sleep 1
    done &&
    sleep 2 &&
    
    # Проверяем какие процессы все еще работают
    REMAINING_PIDS=$(ps aux | awk "/i2pd.*daemon/ && !/I2P-GUI/ {print \$2}") &&
    if [ -n "$REMAINING_PIDS" ]; then
        echo "⚠️ Используем SIGKILL для оставшихся процессов: $REMAINING_PIDS" &&
        for PID in $REMAINING_PIDS; do
            kill -KILL $PID 2>/dev/null &&
            echo "💥 Принудительная остановка $PID"
        done &&
        sleep 1
    fi
else
    echo "ℹ️ Процессы i2pd daemon не найдены"
fi &&

# Финальная проверка
FINAL_PIDS=$(ps aux | awk "/i2pd.*daemon/ && !/I2P-GUI/ {print \$2}") &&
if [ -z "$FINAL_PIDS" ]; then
    echo "✅ i2pd daemon полностью остановлен"
else
    echo "❌ Процессы все еще работают: $FINAL_PIDS"
fi'

bash -c "$STOP_COMMAND"

echo ""
echo "✅ Тест завершен!"
