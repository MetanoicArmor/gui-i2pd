#!/bin/bash

echo "🍎 Создание macOS .app приложения I2P GUI"
echo "=========================================="

# Переменные
APP_NAME="I2P-GUI"
APP_VERSION="1.0"
BUNDLE_ID="com.example.i2pd-gui"
APP_DIR="${APP_NAME}.app"
BUILD_DIR="build-app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Проверка зависимостей
echo "🔍 Проверка зависимостей..."

if ! command -v swiftc &> /dev/null; then
    echo "❌ Swift компилятор не найден"
    exit 1
fi

if ! command -v cp &> /dev/null; then
    echo "❌ cp утилита не найдена"
    exit 1
fi

echo "✅ Все зависимости найдены"

# Очистка и создание структуры
echo "📁 Создание структуры приложения..."

rm -rf ${APP_DIR}
mkdir -p ${MACOS_DIR}
mkdir -p ${RESOURCES_DIR}

echo "✅ Структура создана"

# Компиляция приложения
echo "🔨 Компиляция Swift приложения..."

# Найдем основной файл приложения  
if [ -f "main.swift" ]; then
    MAIN_FILE="main.swift"
    echo "📄 Найден основной файл: $MAIN_FILE"
elif [ -f "Sources/i2pd-gui/AppCore.swift" ]; then
    MAIN_FILE="Sources/i2pd-gui/AppCore.swift"
    echo "📄 Найден основной файл: $MAIN_FILE"
else
    echo "❌ Не найден основной файл приложения"
    echo "💡 Убедитесь что main.swift существует"
    exit 1
fi

# Компилируем
swiftc \
    -o ${MACOS_DIR}/${APP_NAME} \
    ${MAIN_FILE} \
    -framework Cocoa \
    -framework SwiftUI \
    -target arm64-apple-macos14.0

if [ $? -ne 0 ]; then
    echo "❌ Ошибка компиляции"
    exit 1
fi

echo "✅ Приложение скомпилировано"

# Копируем бинарник i2pd
echo "📦 Копирование ресурсов..."

if [ -f "i2pd-gui/i2pd" ]; then
    cp "i2pd-gui/i2pd" ${RESOURCES_DIR}/i2pd
    echo "✅ Бинарник i2pd скопирован"
else
    echo "⚠️  Бинарник i2pd не найден в i2pd-gui/i2pd"
    echo "💡 Будет создан пустой файл для тестирования"
    touch ${RESOURCES_DIR}/i2pd
fi

# Копируем иконку если есть
if [ -f "icon.png" ]; then
    cp icon.png ${RESOURCES_DIR}/icon.png
    echo "✅ Иконка скопирована"
fi

echo "✅ Ресурсы скопированы"

# Создаем Info.plist
echo "📋 Создание Info.plist..."

cat > ${CONTENTS_DIR}/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2025 I2P GUI Project</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.networking</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMainNibFile</key>
    <string>MainMenu</string>
</dict>
</plist>
EOF

echo "✅ Info.plist создан"

# Создаем PkgInfo
echo "📄 Создание PkgInfo..."

echo "APPL????" > ${CONTENTS_DIR}/PkgInfo

echo "✅ PkgInfo создан"

# Проверяем размер и права
echo "📊 Информация о приложении..."

chmod +x ${MACOS_DIR}/${APP_NAME}
chmod +x ${RESOURCES_DIR}/i2pd

echo "📍 Расположение: $(pwd)/${APP_DIR}"
echo "📦 Размер приложения: $(du -sh ${APP_DIR} | cut -f1)"
echo "🔧 Размер исполняемого файла: $(du -sh ${MACOS_DIR}/${APP_NAME} | cut -f1)"
echo "📋 Размер ресурсов: $(du -sh ${RESOURCES_DIR} | cut -f1)"

echo ""
echo "🎉 .app приложение создано успешно!"
echo ""
echo "🚀 Способы запуска:"
echo "   Двойной клик на ${APP_DIR}"
echo "   open ${APP_DIR}"
echo ""
echo "📋 Информация о приложении:"
echo "   Название: ${APP_NAME}"
echo "   Версия: ${APP_VERSION}"
echo "   Bundle ID: ${BUNDLE_ID}"
echo "   Минимальная версия macOS: 14.0"
echo ""
echo "✅ Готово к распространению!"
