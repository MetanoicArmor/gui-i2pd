#!/bin/bash

echo "🖼️ Создание иконки приложения I2P GUI"
echo "===================================="

# Проверяем наличие исходного файла
if [ ! -f "ico.png" ]; then
    echo "❌ Файл ico.png не найден!"
    echo "📋 Добавьте файл ico.png с изображением иконки"
    exit 1
fi

echo "📐 Создание размеров иконок..."
sips -z 16 16 ico.png --out ico-16.png > /dev/null
sips -z 32 32 ico.png --out ico-32.png > /dev/null
sips -z 64 64 ico.png --out ico-64.png > /dev/null
sips -z 128 128 ico.png --out ico-128.png > /dev/null
sips -z 256 256 ico.png --out ico-256.png > /dev/null
sips -z 512 512 ico.png --out ico-512.png > /dev/null

echo "📁 Создание структуры icon.iconset..."
mkdir -p icon.iconset
cp ico-16.png icon.iconset/icon_16x16.png
cp ico-32.png icon.iconset/icon_16x16@2x.png
cp ico-32.png icon.iconset/icon_32x32.png
cp ico-64.png icon.iconset/icon_32x32@2x.png
cp ico-128.png icon.iconset/icon_128x128.png
cp ico-256.png icon.iconset/icon_128x128@2x.png
cp ico-256.png icon.iconset/icon_256x256.png
cp ico-512.png icon.iconset/icon_256x256@2x.png
cp ico-512.png icon.iconset/icon_512x512.png

echo "🔧 Создание .icns файла..."
iconutil -c icns icon.iconset -o I2P-GUI.icns

echo "🧹 Очистка временных файлов..."
rm -f ico-*.png
rm -rf icon.iconset

echo ""
echo "✅ Иконка I2P-GUI.icns создана успешно!"
echo "📊 Размер: $(ls -lh I2P-GUI.icns | awk '{print $5}')"
echo ""
echo "🚀 Теперь создайте приложение: ./build-app-simple.sh"
