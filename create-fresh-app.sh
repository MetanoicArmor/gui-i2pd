#!/bin/bash

# Новый сборочный скрипт с полной пересборкой
APP_NAME="I2P-GUI-Fresh"
APP_DISPLAY_NAME="I2P Network Daemon GUI"
BUNDLE_ID="com.i2pd.gui.fresh"
VERSION="2.0"
TARGET_VERSION="14.0"

echo "🔄 Полная пересборка I2P-GUI приложения"
echo "======================================="

# Очищаем все артефакты предыдущих сборок
echo "🧹 Очистка предыдущих сборок..."
rm -rf .build
rm -rf "${APP_NAME}.app"
rm -rf "I2P-GUI.app"

# Чистая сборка проекта
echo "📦 Swift Package Manager - полная сборка..."
swift build -c release --verbose
if [ $? -ne 0 ]; then
    echo "❌ Ошибка сборки: FAILED"
    exit 1
fi

echo "✅ Проект собран успешно"

# Проверяем что у нас есть исполняемый файл
EXECUTABLE_PATH=".build/release/i2pd-gui"
if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "❌ Исполняемый файл не найден: $EXECUTABLE_PATH"
    echo "📂 Содержимое .build/release/:"
    ls -la .build/release/ || echo "Директория не существует"
    exit 1
fi

echo "📍 Исполняемый файл найден: $(du -sh "$EXECUTABLE_PATH" | awk '{print $1}')"

# Проверяем что бинарник i2pd существует
if [ ! -f "i2pd" ]; then
    echo "❌ Бинарник i2pd не найден в текущей директории"
    exit 1
fi

echo "✅ Бинарник i2pd найден: $(du -sh i2pd | awk '{print $1}')"

# Создаем структуру .app
echo "📁 Создание структуры приложения..."
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Копируем исполняемый файл
cp "$EXECUTABLE_PATH" "${MACOS_DIR}/${APP_NAME}"
echo "✅ Исполняемый файл скопирован"

# Копируем бинарник i2pd
cp i2pd "${RESOURCES_DIR}/"
echo "✅ Бинарник i2pd скопирован в Resources"

# Создаем улучшенный Info.plist
echo "📋 Создание Info.plist с улучшенными метаданными..."
cat > "${CONTENTS_DIR}/Info.plist" << EOF
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
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${TARGET_VERSION}</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.networking</string>
    <key>NSHumanReadableCopyright</key>
    <string>I2P Network Management Tool</string>
</dict>
</plist>
EOF

# Устанавливаем права доступа
chmod +x "${MACOS_DIR}/${APP_NAME}"
echo "✅ Права доступа установлены"

# Проверяем размеры
APP_SIZE=$(du -sh "${APP_DIR}" | awk '{print $1}')
EXEC_SIZE=$(du -sh "${MACOS_DIR}/${APP_NAME}" | awk '{print $1}')
BINARY_SIZE=$(du -sh "${RESOURCES_DIR}/i2pd" | awk '{print $1}')

echo ""
echo "🎉 Полностью новое приложение создано!"
echo "===================================="
echo "📱 Название: ${APP_DISPLAY_NAME}"
echo "📍 Путь: $(pwd)/${APP_DIR}"
echo "📦 Общий размер: $APP_SIZE"
echo "⚡ Исполняемый файл: $EXEC_SIZE"  
echo "🔧 Бинарник i2pd: $BINARY_SIZE"
echo "🆔 Bundle ID: ${BUNDLE_ID}"
echo "📊 Версия: ${VERSION}"
echo ""
echo "🚀 Способы запуска:"
echo "   📱 Двойной клик: ${APP_NAME}.app"
echo "   🔧 Команда: open ${APP_NAME}.app"
echo "   📂 Finder: Перетащите в Applications"
echo ""
echo "✨ Особенности этой сборки:"
echo "   🔧 Исправленная логика остановки daemon"
echo "   📝 Улучшенное логирование процесса"
echo "   🎯 Точный поиск процессов через ps + awk"
echo "   💥 Принудительная остановка если нужно"
echo ""
echo "✅ Готово к тестированию!"

# Создаем краткий отчет
echo "📋 Файлы в сборке:"
echo "   📁 ${MACOS_DIR}/${APP_NAME}"
echo "   📁 ${RESOURCES_DIR}/i2pd"
echo "   📁 ${CONTENTS_DIR}/Info.plist"
echo ""
echo "🔍 Для проверки содержимого:"
echo "   open ${APP_DIR}/Contents/Resources/"
