#!/bin/bash

# 🎨 Создание профессионального DMG с красивым дизайном
# ========================================================

# Определяем версию из бинарника i2pd
I2PD_VERSION=$(./i2pd --version 2>&1 | grep -o 'i2pd version [0-9]\+\.[0-9]\+\.[0-9]\+' | cut -d' ' -f3)
APP_VERSION=$I2PD_VERSION
APP_NAME="I2P Daemon GUI"
DMG_NAME="I2P-Daemon-GUI-v${I2PD_VERSION}"

echo "🍎 Создание профессионального DMG с красивым дизайном"
echo "========================================================"
echo "✅ Версия i2pd: $I2PD_VERSION"
echo "📱 Версия приложения: $APP_VERSION"

# Проверяем наличие приложения
if [ ! -d "${APP_NAME}.app" ]; then
    echo "🔨 Приложение не найдено, собираем..."
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

# Создаем папку .background ДО копирования файлов
mkdir -p "${DMG_DIR}/.background"

echo "✅ Структура DMG создана"

# Создаем красивое фоновое изображение через Python
echo "🎨 Создание фонового изображения с интерфейсом..."

python3 << EOF
from PIL import Image, ImageDraw, ImageFont
import os
import math

# Создаем изображение 800x600 с современным дизайном
width, height = 800, 600
image = Image.new('RGB', (width, height), color='#ffffff')
draw = ImageDraw.Draw(image)

# Создаем красивый градиентный фон от темно-синего к светло-голубому
for y in range(height):
    # Градиент от #1e3a8a к #dbeafe
    r = int(30 + (219 - 30) * (y / height))
    g = int(58 + (234 - 58) * (y / height))
    b = int(138 + (254 - 138) * (y / height))
    draw.line([(0, y), (width, y)], fill=(r, g, b))

# Добавляем декоративные облака сверху
for i in range(4):
    cloud_x = 50 + i * 180
    cloud_y = 40
    # Облако состоит из нескольких кругов
    draw.ellipse([cloud_x, cloud_y, cloud_x + 40, cloud_y + 20], 
                fill=(255, 255, 255, 80))
    draw.ellipse([cloud_x + 15, cloud_y - 5, cloud_x + 55, cloud_y + 15], 
                fill=(255, 255, 255, 80))
    draw.ellipse([cloud_x + 30, cloud_y + 5, cloud_x + 70, cloud_y + 25], 
                fill=(255, 255, 255, 80))

# Убираем лишние области - оставляем только чистый фон

# Добавляем красивую стрелку точно по центру между иконками
arrow_start_x = width // 2
arrow_start_y = 300  # Точное позиционирование между иконками

# Тень стрелки
shadow_points = [
    (arrow_start_x + 2, arrow_start_y + 22),
    (arrow_start_x - 13, arrow_start_y + 2),
    (arrow_start_x + 17, arrow_start_y + 2)
]
draw.polygon(shadow_points, fill='#000000')

# Основная стрелка с градиентом
arrow_points = [
    (arrow_start_x, arrow_start_y + 20),
    (arrow_start_x - 15, arrow_start_y),
    (arrow_start_x + 15, arrow_start_y)
]
draw.polygon(arrow_points, fill='#007AFF')

# Добавляем декоративные элементы
# Маленькие звездочки вокруг
stars = [
    (100, 80), (200, 60), (300, 90), (400, 70), (500, 85), (600, 75), (700, 95)
]
for star_x, star_y in stars:
    draw.text((star_x, star_y), "✦", fill=(255, 255, 255, 120))

# Добавляем текст с лучшими шрифтами
try:
    title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
    subtitle_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
    instruction_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
except:
    try:
        title_font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 28)
        subtitle_font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 18)
        instruction_font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 16)
    except:
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()
        instruction_font = ImageFont.load_default()

# Текст для Applications с тенью (убираем, так как он будет под иконкой)

# Добавляем красивую инструкцию внизу
instruction_text = "Перетащите приложение в папку Applications"
bbox = draw.textbbox((0, 0), instruction_text, font=instruction_font)
text_width = bbox[2] - bbox[0]

# Тень инструкции
draw.text((width//2 - text_width//2 + 2, height - 40 + 2), 
          instruction_text, fill='#000000', font=instruction_font)

# Основная инструкция
draw.text((width//2 - text_width//2, height - 40), 
          instruction_text, fill='#ffffff', font=instruction_font)

# Добавляем декоративную рамку по краям
draw.rectangle([10, 10, width-10, height-10], outline='#ffffff', width=2)

image.save('${DMG_DIR}/.background/background.png')
print("✅ Фоновое изображение с интерфейсом создано")
EOF

echo "✅ Фоновое изображение создано"

# Копируем приложение
echo "📱 Копирование приложения..."
cp -R "${APP_NAME}.app" "${DMG_DIR}/"

# Создаем ссылку на Applications
echo "📁 Создание ссылки на Applications..."
ln -s /Applications "${DMG_DIR}/Applications"

echo "🔨 Создание DMG образа..."
hdiutil create -srcfolder "${DMG_DIR}" -volname "${APP_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 100m "${DMG_NAME}_temp.dmg"

echo "✅ Временный DMG создан"

# Монтируем DMG для настройки
echo "📱 Монтирование DMG для настройки..."
hdiutil attach "${DMG_NAME}_temp.dmg" -readwrite -noverify -noautoopen

# Настраиваем визуальный интерфейс
echo "🎨 Настройка визуального интерфейса DMG..."

# Используем AppleScript для настройки внешнего вида
osascript << EOF
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 900, 700}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set background picture of theViewOptions to file ".background:background.png"
        
        -- Позиционируем иконку приложения точно по центру сверху
        set position of item "${APP_NAME}.app" of container window to {400, 120}
        
        -- Позиционируем Applications точно по центру снизу
        set position of item "Applications" of container window to {400, 420}
        
        -- Обновляем вид
        update without registering applications
        delay 2
    end tell
end tell
EOF

echo "✅ Визуальный интерфейс настроен"

# Размонтируем DMG
echo "📤 Размонтирование DMG..."
hdiutil detach "/Volumes/${APP_NAME}" -force
sleep 2

# Конвертируем в финальный формат
echo "🔄 Конвертация в финальный формат..."
hdiutil convert "${DMG_NAME}_temp.dmg" -format UDZO -imagekey zlib-level=9 -o "${DMG_NAME}.dmg"

echo "🧹 Очистка временных файлов..."
rm -rf "${TEMP_DIR}"
rm -f "${DMG_NAME}_temp.dmg"

# Подписываем DMG
echo "🔐 Подпись DMG..."

# Создаем сертификат для подписи (если не существует)
if ! security find-identity -v -p codesigning | grep -q "I2P Daemon GUI"; then
    echo "🔨 Создаем сертификат для подписи..."
    
    # Создаем ключ
    security create-keypair -a rsa -s 2048 -f /tmp/i2pd.key
    
    # Создаем сертификат
    security create-certificate -k /tmp/i2pd.key -c "I2P Daemon GUI" -t codesigning -d 3650 /tmp/i2pd.crt
    
    # Импортируем в keychain
    security import /tmp/i2pd.key -k ~/Library/Keychains/login.keychain
    security import /tmp/i2pd.crt -k ~/Library/Keychains/login.keychain
    
    echo "✅ Сертификат создан"
fi

# Подписываем DMG
codesign --force --sign "I2P Daemon GUI" "${DMG_NAME}.dmg"

# Проверяем подпись
codesign --verify --verbose "${DMG_NAME}.dmg"

if [ $? -eq 0 ]; then
    echo "✅ DMG подписан базовой подписью"
    echo "✅ Подпись валидна"
else
    echo "⚠️ Подпись не удалась, но DMG создан"
fi

echo ""
echo "🎉 Профессиональный DMG с красивым дизайном создан!"
echo ""
echo "📊 Информация:"
echo "   📍 Путь: $(pwd)/${DMG_NAME}.dmg"
echo "   📦 Размер: $(du -h "${DMG_NAME}.dmg" | cut -f1)"
echo "   📱 Версия: ${APP_VERSION}"
echo "   🏷️ Название тома: ${APP_NAME}"
echo ""
echo "🎨 Визуальные особенности:"
echo "   📱 Большая иконка приложения сверху"
echo "   📁 Папка Applications снизу"
echo "   ⬇️ Стрелка между элементами"
echo "   🌈 Красивый градиентный фон"
echo "   ☁️ Декоративные облака"
echo "   ✦ Звездочки для украшения"
echo "   📝 Инструкция по установке"
echo "   🎨 Современный дизайн"
echo ""
echo "🚀 Способы использования:"
echo "   Двойной клик на: ${DMG_NAME}.dmg"
echo "   Команда: open ${DMG_NAME}.dmg"
echo "   Перетаскивание в Applications"
echo ""
echo "✅ Готово к профессиональному распространению!"