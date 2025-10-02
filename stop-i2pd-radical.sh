#!/bin/bash

echo "🔍 РАДИКАЛЬНАЯ остановка i2pd daemon..."
echo "========================================"

# Метод 1: pkill с SIGINT
echo "🛑 Метод 1: pkill -INT..."
pkill -INT -f "i2pd.*daemon" 2>/dev/null || true
sleep 2

# Метод 2: pkill с SIGKILL  
echo "💀 Метод 2: pkill -KILL..."
pkill -KILL -f "i2pd.*daemon" 2>/dev/null || true
sleep 1

# Метод 3: killall по имени
echo "⚰️ Метод 3: killall i2pd..."
killall -INT i2pd 2>/dev/null || true
sleep 1
killall -KILL i2pd 2>/dev/null || true
sleep 1

# Метод 4: поиск через ps и kill по PID
echo "🎯 Метод 4: поиск и kill по PID..."
ps aux | grep "i2pd" | grep -v "grep" | grep "daemon" | while read line; do
    PID=$(echo "$line" | awk '{print $2}')
    echo "💉 Kill PID: $PID"
    kill -INT "$PID" 2>/dev/null || true
    sleep 0.5
    kill -KILL "$PID" 2>/dev/null || true
done
sleep 2

# Финальная проверка
echo "🔍 Финальная проверка..."
FINAL_COUNT=$(ps aux | grep "i2pd.*daemon" | grep -v "grep" | wc -l | tr -d ' ')
if [ "$FINAL_COUNT" -eq 0 ]; then
    echo "✅ i2pd daemon ПОЛНОСТЬЮ остановлен!"
else
    echo "❌ ПРОЦЕССЫ НЕ ОСТАНАВЛИВАЮТСЯ! ($FINAL_COUNT шт.)"
    echo "Оставшиеся процессы:"
    ps aux | grep "i2pd.*daemon" | grep -v "grep"
fi

echo "✅ Радикальная остановка завершена!"
