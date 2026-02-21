#!/bin/bash

echo "🍎 Создание macOS .app через Swift Package Manager"
echo "================================================"

# Переменные
APP_NAME="I2P Daemon GUI"
BUNDLE_ID="com.i2pd.daemon-gui"

# Автоматически определяем версию из бинарника i2pd
echo "🔍 Определение версии из бинарника i2pd..."
if [ -f "./i2pd" ]; then
    # Извлекаем версию из бинарника (формат: `i2pd version 2.59.0 (0.9.68)`)
    VERSION_OUTPUT=$(./i2pd --version 2>&1 || true)
    # Универсальный парсер: просто берем первую подстроку вида X.Y.Z
    APP_VERSION=$(echo "$VERSION_OUTPUT" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [ -z "$APP_VERSION" ]; then
        echo "❌ Не удалось определить версию из бинарника, используем запасную 2.59.0"
        APP_VERSION="2.59.0"
    else
        echo "✅ Версия i2pd: $APP_VERSION"
    fi
else
    echo "⚠️ Бинарник i2pd не найден, используем версию по умолчанию 2.59.0"
    APP_VERSION="2.59.0"
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

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Копируем исполняемый файл
cp "${SWIFT_BUILD_DIR}/${EXECUTABLE_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Копируем бинарник i2pd
if [ -f "i2pd" ]; then
    cp "i2pd" "${RESOURCES_DIR}/i2pd"
    echo "✅ Бинарник i2pd скопирован"
else
    echo "⚠️  Бинарник i2pd не найден"
    touch "${RESOURCES_DIR}/i2pd"
fi

# Копируем иконку приложения
if [ -f "I2P-GUI.icns" ]; then
    cp "I2P-GUI.icns" "${RESOURCES_DIR}/I2P-GUI.icns"
    echo "✅ Иконка приложения скопирована"
else
    echo "⚠️  Иконка I2P-GUI.icns не найдена"
fi

# Копируем конфигурационные файлы
echo "📋 Копирование конфигурационных файлов..."

# subscriptions.txt
if [ -f "subscriptions.txt" ]; then
    cp "subscriptions.txt" "${RESOURCES_DIR}/subscriptions.txt"
    echo "✅ subscriptions.txt скопирован"
else
    echo "⚠️  subscriptions.txt не найден"
fi

# i2pd.conf
if [ -f "i2pd.conf" ]; then
    cp "i2pd.conf" "${RESOURCES_DIR}/i2pd.conf"
    echo "✅ i2pd.conf скопирован"
else
    echo "⚠️  i2pd.conf не найден"
fi

# tunnels.conf
if [ -f "tunnels.conf" ]; then
    cp "tunnels.conf" "${RESOURCES_DIR}/tunnels.conf"
    echo "✅ tunnels.conf скопирован"
else
    echo "⚠️  tunnels.conf не найден"
fi

# Localizations (.lproj)
if [ -d "Resources" ]; then
    echo "🌐 Копирование локализаций (.lproj)..."
    cp -R Resources/*.lproj "${RESOURCES_DIR}/" 2>/dev/null || true
    echo "✅ Локализации скопированы"
else
    echo "ℹ️ Папка Resources отсутствует, пропускаем локализации"
fi

# Сборка и копирование termchat-i2p в tools
TERMCHAT_BINARY=""
if [ -d "termchat-i2p" ]; then
    echo "💬 Сборка termchat-i2p..."
    ( cd termchat-i2p/libsam3 && make build 2>/dev/null ) && \
    ( cd termchat-i2p && make 2>/dev/null ) && \
    [ -f "termchat-i2p/termchat-i2p" ] && TERMCHAT_BINARY="termchat-i2p/termchat-i2p"
    if [ -n "$TERMCHAT_BINARY" ]; then
        mkdir -p tools
        cp "$TERMCHAT_BINARY" tools/termchat-i2p
        chmod +x tools/termchat-i2p
        echo "✅ termchat-i2p собран и добавлен в tools"
    else
        echo "ℹ️ termchat-i2p не собран (нет libsam3 или ошибка сборки), пропускаем"
    fi
fi

# Копирование утилит tools
if [ -d "tools" ]; then
    echo "🔧 Копирование утилит tools..."
    cp -R tools "${RESOURCES_DIR}/" 2>/dev/null || true
    echo "✅ Утилиты tools скопированы"
else
    echo "ℹ️ Папка tools отсутствует, пропускаем утилиты"
fi

# Используем системные иконки трея (не нужно копировать кастомные)
echo "🔧 Используем системные иконки трея по умолчанию - без дополнительных файлов"

# Создаем Info.plist
echo "📋 Создание Info.plist..."

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
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleSignature</key>
    <string>I2PD</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 Vade</string>
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
chmod +x "${MACOS_DIR}/${APP_NAME}"
chmod +x "${RESOURCES_DIR}/i2pd"

echo "✅ Права доступа установлены"

# Удаляем проблемные атрибуты macOS
echo "🧹 Очистка атрибутов macOS..."
xattr -cr "${APP_DIR}" 2>/dev/null || true
echo "✅ Атрибуты очищены"

# Подписываем приложение для macOS
echo "🔐 Подпись приложения..."
codesign --force --options runtime --sign - "${APP_DIR}" 2>/dev/null || {
    echo "⚠️  Автоматическая подпись недоступна, используйте ручную подпись"
    echo "   Для удаленной подписи используйте: codesign --sign \"Your Certificate\" \"${APP_DIR}\""
}
echo "✅ Подпись завершена"

# Показываем информацию о созданном приложении
echo ""
echo "🎉 Приложение .app создано успешно!"
echo ""
echo "📊 Информация:"
echo "   📍 Путь: $(pwd)/${APP_DIR}"
echo "   📦 Размер: $(du -sh \"${APP_DIR}\" | cut -f1)"
echo "   🔧 Исполняемый файл: $(du -sh \"${MACOS_DIR}/${APP_NAME}\" | cut -f1)"
echo "   📋 ID: ${BUNDLE_ID}"
echo "   📱 Версия: ${APP_VERSION}"
echo ""
echo "📁 Включенные файлы:"
echo "   🔧 i2pd - основной демон"
if [ -f "subscriptions.txt" ]; then echo "   📋 subscriptions.txt - подписки address book"; fi
if [ -f "i2pd.conf" ]; then echo "   ⚙️ i2pd.conf - конфигурация демона"; fi
if [ -f "tunnels.conf" ]; then echo "   🚇 tunnels.conf - конфигурация туннелей"; fi
if [ -f "tools/termchat-i2p" ]; then echo "   💬 termchat-i2p - P2P чат I2P (в tools)"; fi
echo "   🔧 Системная иконка трея по умолчанию"
echo ""
echo "🚀 Способы запуска:"
echo "   Двойной клик на: ${APP_DIR}"
echo "   Команда: open ${APP_DIR}"
echo "   Перетаскивание в Applications"
echo ""
echo "✅ Готово к использованию!"
