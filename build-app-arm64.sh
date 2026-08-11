#!/bin/bash

echo "🍎 Создание macOS .app через Swift Package Manager"
echo "================================================"

# Переменные
APP_NAME="I2P Daemon GUI"
BUNDLE_ID="com.i2pd.daemon-gui"
VERSION_FILE="VERSION"
DEFAULT_APP_VERSION="2.61"

is_valid_version() {
    [[ "$1" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]
}

read_version_file() {
    if [ ! -f "$VERSION_FILE" ]; then
        return 1
    fi

    APP_VERSION=$(head -n 1 "$VERSION_FILE" | tr -d '[:space:]')
    if is_valid_version "$APP_VERSION"; then
        echo "✅ Версия из ${VERSION_FILE}: $APP_VERSION"
        return 0
    fi

    echo "⚠️ ${VERSION_FILE} содержит некорректную версию: ${APP_VERSION}"
    APP_VERSION=""
    return 1
}

read_binary_version() {
    if [ ! -f "./i2pd" ]; then
        echo "⚠️ Бинарник i2pd не найден"
        return 1
    fi

    echo "🔍 Определение версии из бинарника i2pd..."
    VERSION_OUTPUT=$(./i2pd --version 2>&1 || true)
    APP_VERSION=$(echo "$VERSION_OUTPUT" | grep -oE '[0-9]+(\.[0-9]+){1,2}' | head -1)

    if is_valid_version "$APP_VERSION"; then
        echo "✅ Версия i2pd: $APP_VERSION"
        return 0
    fi

    echo "❌ Не удалось определить версию из бинарника"
    APP_VERSION=""
    return 1
}

if ! read_version_file && ! read_binary_version; then
    echo "⚠️ Используем версию по умолчанию ${DEFAULT_APP_VERSION}"
    APP_VERSION="$DEFAULT_APP_VERSION"
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

# Ресурсы SwiftPM (иконки трея) — рядом с исполняемым файлом
if [ -d "${SWIFT_BUILD_DIR}/i2pd-gui_i2pd-gui.bundle" ]; then
    rm -rf "${MACOS_DIR}/i2pd-gui_i2pd-gui.bundle"
    cp -R "${SWIFT_BUILD_DIR}/i2pd-gui_i2pd-gui.bundle" "${MACOS_DIR}/"
    # SPM кладёт PNG в корень .bundle без Info.plist — codesign --deep отклоняет такой «бандл».
    TRAY_BUNDLE="${MACOS_DIR}/i2pd-gui_i2pd-gui.bundle"
    TRAY_TMP="${TRAY_BUNDLE}.repack.$$"
    mkdir -p "${TRAY_TMP}/Contents/Resources"
    for png in "${TRAY_BUNDLE}"/*.png; do
        [ -e "$png" ] || continue
        mv "$png" "${TRAY_TMP}/Contents/Resources/"
    done
    cat > "${TRAY_TMP}/Contents/Info.plist" << 'TRAYPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>com.i2pd.gui.tray-assets</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
	<key>CFBundleVersion</key>
	<string>1</string>
</dict>
</plist>
TRAYPLIST
    rm -rf "${TRAY_BUNDLE}"
    mv "${TRAY_TMP}" "${TRAY_BUNDLE}"
    echo "✅ Пакет i2pd-gui_i2pd-gui.bundle (иконки трея) скопирован в MacOS"
else
    echo "⚠️  i2pd-gui_i2pd-gui.bundle не найден — трей будет без кастомных PNG"
fi

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

# Копирование утилит tools
if [ -d "tools" ]; then
    echo "🔧 Копирование утилит tools..."
    cp -R tools "${RESOURCES_DIR}/" 2>/dev/null || true
    echo "✅ Утилиты tools скопированы"
else
    echo "ℹ️ Папка tools отсутствует, пропускаем утилиты"
fi

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

# Ad-hoc подпись (-) не заменяет Developer ID, но часто даёт более мягкий Gatekeeper,
# чем полностью неподписанный бандл. --deep — tray .bundle, i2pd и утилиты в Resources.
echo "🔐 Ad-hoc codesign (--deep, без hardened runtime)..."
if codesign --force --deep --sign - "${APP_DIR}"; then
    echo "✅ Ad-hoc подпись применена"
else
    echo "⚠️  codesign не выполнен — установите Xcode Command Line Tools или подпишите вручную"
fi

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
echo "   🎭 Иконки трея: theatermasks / theatermask.fill (в i2pd-gui_i2pd-gui.bundle)"
echo ""
echo "🚀 Способы запуска:"
echo "   Двойной клик на: ${APP_DIR}"
echo "   Команда: open ${APP_DIR}"
echo "   Перетаскивание в Applications"
echo ""
echo "✅ Готово к использованию!"
