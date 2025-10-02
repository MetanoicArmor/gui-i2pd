#!/bin/bash

echo "🍎 Создание macOS .app через Swift Package Manager"
echo "================================================"

# Переменные
APP_NAME="I2P-GUI"
APP_VERSION="2.58.0" 
BUNDLE_ID="com.example.i2pd-gui"

echo "📦 Используем Swift Package Manager..."

# Собираем проект
echo "🔨 Сборка проекта..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Ошибка сборки"
    exit 1
fi

echo "✅ Проект собран успешно"

# Проверяем путь к собранному файлу
SWIFT_BUILD_DIR=".build/release"
EXECUTABLE_NAME="i2pd-gui"

if [ ! -f "${SWIFT_BUILD_DIR}/${EXECUTABLE_NAME}" ]; then
    echo "❌ Исполняемый файл не найден: ${SWIFT_BUILD_DIR}/${EXECUTABLE_NAME}"
    exit 1
fi

echo "📍 Найден исполняемый файл: ${SWIFT_BUILD_DIR}/${EXECUTABLE_NAME}"

# Создаем .app структуру
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📁 Создание структуры .app..."

rm -rf ${APP_DIR}
mkdir -p ${MACOS_DIR}
mkdir -p ${RESOURCES_DIR}

# Копируем исполняемый файл
cp ${SWIFT_BUILD_DIR}/${EXECUTABLE_NAME} ${MACOS_DIR}/${APP_NAME}

# Копируем бинарник i2pd
if [ -f "i2pd" ]; then
    cp "i2pd" ${RESOURCES_DIR}/i2pd
    echo "✅ Бинарник i2pd скопирован"
else
    echo "⚠️  Бинарник i2pd не найден"
    touch ${RESOURCES_DIR}/i2pd
fi

# Копируем иконку приложения
if [ -f "I2P-GUI.icns" ]; then
    cp "I2P-GUI.icns" ${RESOURCES_DIR}/I2P-GUI.icns
    echo "✅ Иконка приложения скопирована"
else
    echo "⚠️  Иконка I2P-GUI.icns не найдена"
fi

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
    <string>2580</string>
    <key>CFBundleSignature</key>
    <string>I2PD</string>
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
    <key>CFBundleIconFile</key>
    <string>I2P-GUI</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Устанавливаем права доступа
chmod +x ${MACOS_DIR}/${APP_NAME}
chmod +x ${RESOURCES_DIR}/i2pd

echo "✅ Права доступа установлены"

# Показываем информацию о созданном приложении
echo ""
echo "🎉 Приложение .app создано успешно!"
echo ""
echo "📊 Информация:"
echo "   📍 Путь: $(pwd)/${APP_DIR}"
echo "   📦 Размер: $(du -sh ${APP_DIR} | cut -f1)"
echo "   🔧 Исполняемый файл: $(du -sh ${MACOS_DIR}/${APP_NAME} | cut -f1)"
echo "   📋 ID: ${BUNDLE_ID}"
echo "   📱 Версия: ${APP_VERSION}"
echo ""
echo "🚀 Способы запуска:"
echo "   Двойной клик на: ${APP_DIR}"
echo "   Команда: open ${APP_DIR}"
echo "   Перетаскивание в Applications"
echo ""
echo "✅ Готово к использованию!"
