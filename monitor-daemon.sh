#!/bin/bash

echo "📊 МОНИТОРИНГ ДЕМОНА i2pd"
echo "========================"
echo ""

while true; do
    GUI_PID=$(pgrep -f "I2P-GUI.app/Contents/MacOS/I2P-GUI" | head -1)
    I2PD_PID=$(pgrep i2pd | head -1)
    
    echo "$(date '+%H:%M:%S') - GUI: ${GUI_PID:-НЕТ} | i2pd: ${I2PD_PID:-НЕТ}"
    
    if [ -n "$I2PD_PID" ]; then
        echo "   ✅ Демон i2pd запущен (PID: $I2PD_PID)"
        if curl -s --head --fail http://127.0.0.1:7070 > /dev/null 2>&1; then
            echo "   🌐 Веб-консоль доступна"
        else
            echo "   ⚠️ Веб-консоль недоступна"
        fi
    else
        echo "   ❌ Демон остановлен"
    fi
    
    echo ""
    sleep 2
done
