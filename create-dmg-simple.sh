#!/bin/bash
set -e

echo "🍎 Создание DMG образа для I2P Daemon GUI"
echo "=========================================="

# Переменные
APP_NAME="I2P Daemon GUI"
DMG_NAME="I2P-Daemon-GUI-v2.58.0"
VOLUME_NAME="I2P Daemon GUI"

# Определяем версию i2pd
VERSION_OUTPUT=$(./i2pd --version 2>&1)
I2PD_VERSION=$(echo "$VERSION_OUTPUT" | grep -o "i2pd version [0-9]\+\.[0-9]\+\.[0-9]\+" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)

if [ -z "$I2PD_VERSION" ]; then
    echo "❌ Не удалось определить версию i2pd"
    I2PD_VERSION="2.58.0"
    echo "⚠️ Используем версию по умолчанию: $I2PD_VERSION"
fi

echo "✅ Версия i2pd: $I2PD_VERSION"
echo "📱 Версия приложения: $I2PD_VERSION"

# Проверяем существование .app файла
if [ ! -d "${APP_NAME}.app" ]; then
    echo "❌ Приложение ${APP_NAME}.app не найдено"
    echo "🔨 Создаем приложение..."
    ./build-app-simple.sh
fi

echo "✅ Приложение найдено: ${APP_NAME}.app"

# Создаем временную папку для DMG
TEMP_DIR="temp_dmg"
DMG_DIR="${TEMP_DIR}/dmg"

echo "📁 Создание временной структуры DMG..."

# Очищаем предыдущие файлы
rm -rf "${TEMP_DIR}"
rm -f "${DMG_NAME}.dmg"

# Создаем структуру
mkdir -p "${DMG_DIR}"

# Копируем приложение
cp -R "${APP_NAME}.app" "${DMG_DIR}/"

# Создаем символическую ссылку на Applications
ln -s /Applications "${DMG_DIR}/Applications"

# Создаем README файл
cat > "${DMG_DIR}/README.txt" << EOF
I2P Daemon GUI v${I2PD_VERSION}
===============================

Установка:
1. Перетащите "I2P Daemon GUI.app" в папку Applications
2. Запустите приложение из папки Applications

Системные требования:
- macOS 14.0 или новее
- Intel x64 или Apple Silicon (M1/M2/M3/M4)

Дополнительная информация:
https://github.com/MetanoicArmor/gui-i2pd

Спасибо за использование I2P Daemon GUI!
EOF

echo "✅ Структура DMG создана"

# Создаем DMG образ напрямую
echo "🔨 Создание DMG образа..."

hdiutil create -srcfolder "${DMG_DIR}" -volname "${VOLUME_NAME}" -fs HFS+ -format UDZO -imagekey zlib-level=9 "${DMG_NAME}.dmg"

echo "✅ DMG образ создан"

# Подписываем DMG (если возможно)
echo "🔐 Подпись DMG..."
codesign --force --sign - "${DMG_NAME}.dmg" 2>/dev/null || {
    echo "⚠️ Автоматическая подпись недоступна"
}

echo "✅ Подпись завершена"

# Очищаем временные файлы
echo "🧹 Очистка временных файлов..."
rm -rf "${TEMP_DIR}"

# Показываем информацию о созданном DMG
echo ""
echo "🎉 DMG образ создан успешно!"
echo ""
echo "📊 Информация:"
echo "   📍 Путь: $(pwd)/${DMG_NAME}.dmg"
echo "   📦 Размер: $(du -sh "${DMG_NAME}.dmg" | cut -f1)"
echo "   📱 Версия: ${I2PD_VERSION}"
echo "   🏷️ Название тома: ${VOLUME_NAME}"
echo ""
echo "📁 Содержимое DMG:"
echo "   📱 ${APP_NAME}.app - основное приложение"
echo "   📁 Applications - ссылка на папку приложений"
echo "   📄 README.txt - инструкция по установке"
echo ""
echo "🚀 Способы использования:"
echo "   Двойной клик на: ${DMG_NAME}.dmg"
echo "   Команда: open ${DMG_NAME}.dmg"
echo "   Перетаскивание в Applications"
echo ""
echo "✅ Готово к распространению!"
