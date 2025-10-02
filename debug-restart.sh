#!/bin/bash

echo "🔍 Диагностика проблемы автоперезапуска daemon"
echo "=============================================="

# Проверяем процессы каждые 2 секунды в течение 20 секунд
for i in {1..10}; do
    echo "[$i] Проверка процессов ($(date +"%H:%M:%S")):"
    
    # Процессы daemon
    DAEMON_COUNT=$(ps aux | awk '/i2pd.*daemon/ && !/MacOS/ {print "#"}' | wc -l | tr -d ' ')
    echo "   🔧 Daemon процессов: $DAEMON_COUNT"
    
    # Процессы GUI
    GUI_COUNT=$(ps aux | awk '/I2P-GUI.*MacOS/ {print "#"}' | wc -l | tr -d ' ')
    echo "   🖥️  GUI процессов: $GUI_COUNT"
    
    # Детали процессов
    if [ "$DAEMON_COUNT" -gt 0 ]; then
        echo "   📋 Daemon процессы:"
        ps aux | awk '/i2pd.*daemon/ && !/MacOS/ {print "     PID", $2, "-", substr($0, index($0,$11))}' | sed 's/.*\/\([^\/]*\)$/\1/'
    fi
    
    echo ""
    sleep 2
done

echo "✅ Мониторинг завершен"
