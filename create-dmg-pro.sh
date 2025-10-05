#!/bin/bash
set -e

echo "🍎 Создание профессионального DMG образа для I2P Daemon GUI"
echo "========================================================="

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
rm -f "${DMG_NAME}_temp.dmg"

# Создаем структуру
mkdir -p "${DMG_DIR}"

# Копируем приложение
cp -R "${APP_NAME}.app" "${DMG_DIR}/"

# Создаем символическую ссылку на Applications
ln -s /Applications "${DMG_DIR}/Applications"

# Создаем красивый README файл
cat > "${DMG_DIR}/README.txt" << EOF
┌─────────────────────────────────────────────────────────────┐
│                    I2P Daemon GUI v${I2PD_VERSION}                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  🚀 Современный GUI для управления I2P daemon на macOS     │
│                                                             │
│  📋 Установка:                                              │
│     1. Перетащите "I2P Daemon GUI.app" в папку Applications │
│     2. Запустите приложение из папки Applications          │
│                                                             │
│  📋 Системные требования:                                   │
│     • macOS 14.0 или новее                                 │
│     • Intel x64 или Apple Silicon (M1/M2/M3/M4)            │
│                                                             │
│  🌐 Дополнительная информация:                              │
│     https://github.com/MetanoicArmor/gui-i2pd              │
│                                                             │
│  ✨ Особенности:                                            │
│     • Полная интеграция с системным треем macOS            │
│     • Локализация интерфейса (RU/EN)                       │
│     • Умный перезапуск при смене языка                     │
│     • Стандартный путь конфигурации macOS                  │
│                                                             │
│  Спасибо за использование I2P Daemon GUI! 🎉              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
EOF

echo "✅ Структура DMG создана"

# Создаем фоновое изображение
echo "🎨 Создание фонового изображения..."
BACKGROUND_DIR="${DMG_DIR}/.background"
mkdir -p "${BACKGROUND_DIR}"

# Создаем простое фоновое изображение через Python
python3 << EOF
from PIL import Image, ImageDraw, ImageFont
import os

# Создаем изображение 800x600
width, height = 800, 600
image = Image.new('RGB', (width, height), color='#f0f0f0')
draw = ImageDraw.Draw(image)

# Рисуем градиентный фон
for y in range(height):
    color_value = int(240 - (y / height) * 40)
    color = (color_value, color_value, color_value)
    draw.line([(0, y), (width, y)], fill=color)

# Добавляем декоративные элементы
# Рамка
draw.rectangle([10, 10, width-10, height-10], outline='#d0d0d0', width=2)

# Центральный круг
center_x, center_y = width // 2, height // 2
draw.ellipse([center_x-100, center_y-100, center_x+100, center_y+100], 
             outline='#007AFF', width=3)

# Текст
try:
    font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 24)
except:
    font = ImageFont.load_default()

text = "I2P Daemon GUI"
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]
draw.text((center_x - text_width//2, center_y - text_height//2), 
          text, fill='#007AFF', font=font)

# Сохраняем изображение
image.save('${BACKGROUND_DIR}/background.png')
print("✅ Фоновое изображение создано")
EOF

echo "✅ Фоновое изображение создано"

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

# Копируем фоновое изображение
if [ -f "${BACKGROUND_DIR}/background.png" ]; then
    mkdir -p "${MOUNT_DIR}/.background"
    cp "${BACKGROUND_DIR}/background.png" "${MOUNT_DIR}/.background/"
fi

# Настраиваем позиции элементов через AppleScript
osascript << EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 1000, 500}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        
        -- Устанавливаем фоновое изображение
        try
            set background picture of theViewOptions to file ".background:background.png"
        end try
        
        -- Позиционируем элементы
        set position of item "${APP_NAME}.app" of container window to {200, 200}
        set position of item "Applications" of container window to {400, 200}
        set position of item "README.txt" of container window to {300, 350}
        
        -- Обновляем окно
        close
        open
        update without registering applications
        delay 3
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

# Подписываем DMG с более детальной подписью
echo "🔐 Подпись DMG..."

# Создаем временный сертификат для подписи (если нет существующего)
if ! security find-identity -v -p codesigning | grep -q "Developer ID"; then
    echo "⚠️ Создаем самоподписанный сертификат для подписи..."
    
    # Создаем временный сертификат
    cat > /tmp/dmg_cert.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = CA
L = San Francisco
O = I2P GUI Project
OU = Development
CN = I2P Daemon GUI

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = codeSigning
EOF

    # Генерируем ключ и сертификат
    openssl req -x509 -newkey rsa:2048 -keyout /tmp/dmg_key.pem -out /tmp/dmg_cert.pem -days 365 -nodes -config /tmp/dmg_cert.conf
    
    # Импортируем в keychain
    security import /tmp/dmg_key.pem -k ~/Library/Keychains/login.keychain-db
    security import /tmp/dmg_cert.pem -k ~/Library/Keychains/login.keychain-db
    
    # Настраиваем доверие
    security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db /tmp/dmg_cert.pem
    
    # Подписываем DMG
    codesign --force --sign "I2P Daemon GUI" "${DMG_NAME}.dmg"
    
    # Очищаем временные файлы
    rm -f /tmp/dmg_cert.conf /tmp/dmg_key.pem /tmp/dmg_cert.pem
    
    echo "✅ DMG подписан самоподписанным сертификатом"
else
    # Используем существующий сертификат
    codesign --force --sign "Developer ID Application: $(whoami)" "${DMG_NAME}.dmg" 2>/dev/null || {
        codesign --force --sign - "${DMG_NAME}.dmg"
        echo "⚠️ Использована базовая подпись"
    }
fi

echo "✅ Подпись завершена"

# Проверяем подпись
echo "🔍 Проверка подписи..."
codesign -v "${DMG_NAME}.dmg" && echo "✅ Подпись валидна" || echo "⚠️ Проблемы с подписью"

# Показываем информацию о созданном DMG
echo ""
echo "🎉 Профессиональный DMG образ создан успешно!"
echo ""
echo "📊 Информация:"
echo "   📍 Путь: $(pwd)/${DMG_NAME}.dmg"
echo "   📦 Размер: $(du -sh "${DMG_NAME}.dmg" | cut -f1)"
echo "   📱 Версия: ${I2PD_VERSION}"
echo "   🏷️ Название тома: ${VOLUME_NAME}"
echo "   🔐 Подпись: $(codesign -dv "${DMG_NAME}.dmg" 2>&1 | grep -o 'Authority=[^)]*' || echo 'Базовая подпись')"
echo ""
echo "📁 Содержимое DMG:"
echo "   📱 ${APP_NAME}.app - основное приложение"
echo "   📁 Applications - ссылка на папку приложений"
echo "   📄 README.txt - красивая инструкция по установке"
echo "   🎨 Фоновое изображение - профессиональный дизайн"
echo ""
echo "🚀 Способы использования:"
echo "   Двойной клик на: ${DMG_NAME}.dmg"
echo "   Команда: open ${DMG_NAME}.dmg"
echo "   Перетаскивание в Applications"
echo ""
echo "✅ Готово к профессиональному распространению!"
