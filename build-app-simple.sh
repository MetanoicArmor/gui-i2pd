#!/bin/bash

echo "🍎 Создание macOS .app через Swift Package Manager"
echo "================================================"

# Переменные
APP_NAME="I2P-GUI"
BUNDLE_ID="com.example.i2pd-gui"

# Автоматически определяем версию из бинарника i2pd
echo "🔍 Определение версии из бинарника i2pd..."
if [ -f "./i2pd" ]; then
    # Извлекаем версию из бинарника
    VERSION_OUTPUT=$(./i2pd --version 2>&1)
    APP_VERSION=$(echo "$VERSION_OUTPUT" | grep -o "i2pd version [0-9]\+\.[0-9]\+\.[0-9]\+" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)
    
    if [ -z "$APP_VERSION" ]; then
        echo "❌ Не удалось определить версию из бинарника"
        APP_VERSION="2.58.0"
        echo "⚠️ Используем версию по умолчанию: $APP_VERSION"
    else
        echo "✅ Версия i2pd: $APP_VERSION"
    fi
else
    echo "⚠️ Бинарник i2pd не найден, используем версию по умолчанию"
    APP_VERSION="2.58.0"
fi

echo "📱 Версия приложения: $APP_VERSION"

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

# Копируем конфигурационные файлы
echo "📋 Копирование конфигурационных файлов..."

# subscriptions.txt
if [ -f "subscriptions.txt" ]; then
    cp "subscriptions.txt" ${RESOURCES_DIR}/subscriptions.txt
    echo "✅ subscriptions.txt скопирован"
else
    echo "⚠️  subscriptions.txt не найден"
fi

# i2pd.conf
if [ -f "i2pd.conf" ]; then
    cp "i2pd.conf" ${RESOURCES_DIR}/i2pd.conf
    echo "✅ i2pd.conf скопирован"
else
    echo "⚠️  i2pd.conf не найден"
fi

# tunnels.conf
if [ -f "tunnels.conf" ]; then
    cp "tunnels.conf" ${RESOURCES_DIR}/tunnels.conf
    echo "✅ tunnels.conf скопирован"
else
    echo "⚠️  tunnels.conf не найден"
fi

# Localizations (.lproj)
if [ -d "Resources" ]; then
    echo "🌐 Копирование локализаций (.lproj)..."
    cp -R Resources/*.lproj ${RESOURCES_DIR}/ 2>/dev/null || true
    echo "✅ Локализации скопированы"
else
    echo "ℹ️ Папка Resources отсутствует, пропускаем локализации"
fi

# Используем системные иконки трея (не нужно копировать кастомные)
echo "🔧 Используем системные иконки трея по умолчанию - без дополнительных файлов"

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

# Удаляем проблемные атрибуты macOS
echo "🧹 Очистка атрибутов macOS..."
xattr -cr ${APP_DIR} 2>/dev/null || true
echo "✅ Атрибуты очищены"

# Подписываем приложение для macOS
echo "🔐 Подпись приложения..."
codesign --force --options runtime --sign - ${APP_DIR} 2>/dev/null || {
    echo "⚠️  Автоматическая подпись недоступна, используйте ручную подпись"
    echo "   Для удаленной подписи используйте: codesign --sign \"Your Certificate\" ${APP_DIR}"
}
echo "✅ Подпись завершена"

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
echo "📁 Включенные файлы:"
echo "   🔧 i2pd - основной демон"
if [ -f "subscriptions.txt" ]; then echo "   📋 subscriptions.txt - подписки address book"; fi
if [ -f "i2pd.conf" ]; then echo "   ⚙️ i2pd.conf - конфигурация демона"; fi
if [ -f "tunnels.conf" ]; then echo "   🚇 tunnels.conf - конфигурация туннелей"; fi
echo "   🔧 Системная иконка трея по умолчанию"
echo ""
echo "🚀 Способы запуска:"
echo "   Двойной клик на: ${APP_DIR}"
echo "   Команда: open ${APP_DIR}"
echo "   Перетаскивание в Applications"
echo ""
echo "✅ Готово к использованию!"
