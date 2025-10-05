#!/bin/bash
set -e

echo "🍎 Создание профессионального DMG с визуальным интерфейсом"
echo "========================================================"

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

echo "✅ Структура DMG создана"

# Создаем фоновое изображение с визуальными элементами
echo "🎨 Создание фонового изображения с интерфейсом..."

BACKGROUND_DIR="${DMG_DIR}/.background"
mkdir -p "${BACKGROUND_DIR}"

# Создаем красивое фоновое изображение через Python
python3 << EOF
from PIL import Image, ImageDraw, ImageFont
import os

# Создаем изображение 800x600
width, height = 800, 600
image = Image.new('RGB', (width, height), color='#f8f9fa')
draw = ImageDraw.Draw(image)

# Рисуем градиентный фон
for y in range(height):
    color_value = int(248 - (y / height) * 20)
    color = (color_value, color_value, color_value)
    draw.line([(0, y), (width, y)], fill=color)

# Добавляем декоративные элементы
# Тонкая рамка
draw.rectangle([5, 5, width-5, height-5], outline='#e9ecef', width=1)

# Центральная область для приложения (верх)
app_area_y = 150
app_area_height = 200

# Область для Applications (низ)
apps_area_y = 400
apps_area_height = 150

# Рисуем область для приложения
draw.rectangle([width//2-100, app_area_y-20, width//2+100, app_area_y+app_area_height-20], 
               outline='#007AFF', width=2, fill='#f0f8ff')

# Рисуем область для Applications
draw.rectangle([width//2-80, apps_area_y-20, width//2+80, apps_area_y+apps_area_height-20], 
               outline='#28a745', width=2, fill='#f0fff4')

# Добавляем большую стрелку между областями
arrow_start_x = width // 2
arrow_start_y = app_area_y + app_area_height - 20
arrow_end_y = apps_area_y - 20

# Рисуем стрелку
arrow_points = [
    (arrow_start_x, arrow_start_y),
    (arrow_start_x - 15, arrow_start_y + 20),
    (arrow_start_x + 15, arrow_start_y + 20)
]
draw.polygon(arrow_points, fill='#6c757d')

# Добавляем текст
try:
    title_font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 20)
    subtitle_font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 14)
except:
    title_font = ImageFont.load_default()
    subtitle_font = ImageFont.load_default()

# Текст для приложения
app_text = "I2P Daemon GUI"
bbox = draw.textbbox((0, 0), app_text, font=title_font)
text_width = bbox[2] - bbox[0]
draw.text((width//2 - text_width//2, app_area_y + 20), 
          app_text, fill='#007AFF', font=title_font)

# Текст для Applications
apps_text = "Applications"
bbox = draw.textbbox((0, 0), apps_text, font=subtitle_font)
text_width = bbox[2] - bbox[0]
draw.text((width//2 - text_width//2, apps_area_y + 10), 
          apps_text, fill='#28a745', font=subtitle_font)

# Инструкция
instruction_text = "Перетащите приложение в папку Applications"
bbox = draw.textbbox((0, 0), instruction_text, font=subtitle_font)
text_width = bbox[2] - bbox[0]
draw.text((width//2 - text_width//2, height - 50), 
          instruction_text, fill='#6c757d', font=subtitle_font)

# Сохраняем изображение
image.save('${BACKGROUND_DIR}/background.png')
print("✅ Фоновое изображение с интерфейсом создано")
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
echo "🎨 Настройка визуального интерфейса DMG..."

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
        set the bounds of container window to {300, 100, 1100, 700}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        
        -- Устанавливаем фоновое изображение
        try
            set background picture of theViewOptions to file ".background:background.png"
        end try
        
        -- Позиционируем элементы как в Chrome installer
        -- Приложение сверху
        set position of item "${APP_NAME}.app" of container window to {400, 200}
        
        -- Applications снизу
        set position of item "Applications" of container window to {400, 450}
        
        -- Обновляем окно
        close
        open
        update without registering applications
        delay 3
    end tell
end tell
EOF

echo "✅ Визуальный интерфейс настроен"

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

# Подписываем DMG
echo "🔐 Подпись DMG..."

# Создаем самоподписанный сертификат для подписи
if ! security find-identity -v -p codesigning | grep -q "I2P Daemon GUI"; then
    echo "🔨 Создаем сертификат для подписи..."
    
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

    openssl req -x509 -newkey rsa:2048 -keyout /tmp/dmg_key.pem -out /tmp/dmg_cert.pem -days 365 -nodes -config /tmp/dmg_cert.conf 2>/dev/null
    
    security import /tmp/dmg_key.pem -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign 2>/dev/null || true
    security import /tmp/dmg_cert.pem -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign 2>/dev/null || true
    security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db /tmp/dmg_cert.pem 2>/dev/null || true
    
    rm -f /tmp/dmg_cert.conf /tmp/dmg_key.pem /tmp/dmg_cert.pem
fi

# Подписываем DMG
if security find-identity -v -p codesigning | grep -q "I2P Daemon GUI"; then
    codesign --force --sign "I2P Daemon GUI" "${DMG_NAME}.dmg" 2>/dev/null && echo "✅ DMG подписан сертификатом"
elif security find-identity -v -p codesigning | grep -q "Developer ID"; then
    DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    codesign --force --sign "$DEVELOPER_ID" "${DMG_NAME}.dmg" 2>/dev/null && echo "✅ DMG подписан Developer ID"
else
    codesign --force --sign - "${DMG_NAME}.dmg" 2>/dev/null && echo "✅ DMG подписан базовой подписью"
fi

# Проверяем подпись
codesign -v "${DMG_NAME}.dmg" 2>/dev/null && echo "✅ Подпись валидна" || echo "⚠️ Проблемы с подписью"

# Показываем информацию о созданном DMG
echo ""
echo "🎉 Профессиональный DMG с визуальным интерфейсом создан!"
echo ""
echo "📊 Информация:"
echo "   📍 Путь: $(pwd)/${DMG_NAME}.dmg"
echo "   📦 Размер: $(du -sh "${DMG_NAME}.dmg" | cut -f1)"
echo "   📱 Версия: ${I2PD_VERSION}"
echo "   🏷️ Название тома: ${VOLUME_NAME}"
echo ""
echo "🎨 Визуальные особенности:"
echo "   📱 Большая иконка приложения сверху"
echo "   📁 Папка Applications снизу"
echo "   ⬇️ Стрелка между элементами"
echo "   🎨 Градиентный фон"
echo "   📝 Инструкция по установке"
echo ""
echo "🚀 Способы использования:"
echo "   Двойной клик на: ${DMG_NAME}.dmg"
echo "   Команда: open ${DMG_NAME}.dmg"
echo "   Перетаскивание в Applications"
echo ""
echo "✅ Готово к профессиональному распространению!"
