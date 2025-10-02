#!/bin/bash

echo "🧪 ТЕСТ УПРАВЛЕНИЯ ДЕМОНОМ i2pd"
echo "================================="
echo ""

# Проверяем процессы
echo "📊 ТЕКУЩИЕ ПРОЦЕССЫ:"
echo "GUI приложение: $(pgrep -f 'I2P-GUI.app' || echo 'НЕ ЗАПУЩЕНО')"
echo "Демон i2pd: $(pgrep i2pd || echo 'НЕ ЗАПУЩЕНО')"
echo ""

# Проверяем конфиг
echo "⚙️ КОНФИГУРАЦИЯ:"
CONFIG_FILE="$HOME/.i2pd/i2pd.conf"
if [ -f "$CONFIG_FILE" ]; then
    echo "Конфигурация: ✅ Найдена ($CONFIG_FILE)"
    echo "Daemon mode: $(grep -E '^daemon\s*=' "$CONFIG_FILE" || echo 'daemon = true')"
else
    echo "Конфигурация: ❌ Не найдена"
fi
echo ""

echo "🎮 ИНСТРУКЦИИ:"
echo "1. Откройте приложение: open I2P-GUI.app"
echo "2. Нажмите кнопку 'Запустить' для старта демона"
echo "3. Проверьте что демон появился: watch -n 1 'pgrep i2pd || echo НЕТ ДЕМОНА'"
echo "4. Нажмите 'Остановить' для остановки демона"
echo ""

wait
