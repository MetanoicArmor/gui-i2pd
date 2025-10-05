#!/bin/bash
set -e

echo "🍎 Создание DMG образа для I2P Daemon GUI"
echo "=========================================="

# Переменные
APP_NAME="I2P Daemon GUI"
DMG_NAME="I2P-Daemon-GUI-v2.58.0"
VOLUME_NAME="I2P Daemon GUI"
DMG_SIZE="50m"

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

# Создаем DMG образ
echo "🔨 Создание DMG образа..."

hdiutil create -srcfolder "${DMG_DIR}" -volname "${VOLUME_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${DMG_SIZE} "${DMG_NAME}_temp.dmg"

echo "✅ Временный DMG создан"

# Монтируем DMG для настройки
echo "📱 Монтирование DMG для настройки..."

MOUNT_DIR="/Volumes/${VOLUME_NAME}"
hdiutil attach "${DMG_NAME}_temp.dmg" -readwrite -noverify -noautoopen

# Настраиваем внешний вид
echo "🎨 Настройка внешнего вида DMG..."

# Устанавливаем иконку для папки Applications
if [ -d "${MOUNT_DIR}/Applications" ]; then
    # Копируем иконку приложения
    if [ -f "${APP_NAME}.app/Contents/Resources/I2P-GUI.icns" ]; then
        cp "${APP_NAME}.app/Contents/Resources/I2P-GUI.icns" "${MOUNT_DIR}/Applications.icns"
    fi
fi

# Настраиваем позиции элементов (если возможно)
osascript << EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 400}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        
        -- Позиционируем элементы
        set position of item "${APP_NAME}.app" of container window to {150, 150}
        set position of item "Applications" of container window to {350, 150}
        set position of item "README.txt" of container window to {150, 300}
        
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

echo "✅ Внешний вид настроен"

# Размонтируем DMG
echo "📤 Размонтирование DMG..."
hdiutil detach "${MOUNT_DIR}"

# Конвертируем в финальный формат
echo "🔄 Конвертация в финальный формат..."
hdiutil convert "${DMG_NAME}_temp.dmg" -format UDZO -imagekey zlib-level=9 -o "${DMG_NAME}.dmg"

# Очищаем временные файлы
echo "🧹 Очистка временных файлов..."
rm -f "${DMG_NAME}_temp.dmg"
rm -rf "${TEMP_DIR}"

# Подписываем DMG (если возможно)
echo "🔐 Подпись DMG..."
codesign --force --sign - "${DMG_NAME}.dmg" 2>/dev/null || {
    echo "⚠️ Автоматическая подпись недоступна"
}

echo "✅ Подпись завершена"

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
