#!/bin/bash

echo "🍎 Создание macOS .app для Intel (x86_64) через Swift Package Manager"
echo "===================================================================="

# Переменные — отдельное приложение для Intel
APP_NAME="I2P Daemon GUI"
APP_DIR_NAME="I2P Daemon GUI-Intel"
BUNDLE_ID="com.i2pd.daemon-gui"
INTEL_DIR="intel"
VERSION_FILE="VERSION"
DEFAULT_APP_VERSION="2.60"

# Проверяем наличие папки intel с бинарниками
if [ ! -d "$INTEL_DIR" ]; then
    echo "❌ Папка $INTEL_DIR не найдена. Положите туда бинарники для x86_64: i2pd, i2p-tools."
    exit 1
fi

if [ ! -f "${INTEL_DIR}/i2pd" ]; then
    echo "❌ Бинарник ${INTEL_DIR}/i2pd не найден"
    exit 1
fi

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
    if [ ! -f "${INTEL_DIR}/i2pd" ]; then
        echo "❌ Бинарник ${INTEL_DIR}/i2pd не найден"
        return 1
    fi

    echo "🔍 Определение версии из бинарника intel/i2pd..."
    VERSION_OUTPUT=$("${INTEL_DIR}/i2pd" --version 2>&1 || true)
    APP_VERSION=$(echo "$VERSION_OUTPUT" | grep -oE '[0-9]+(\.[0-9]+){1,2}' | head -1)

    if is_valid_version "$APP_VERSION"; then
        echo "✅ Версия i2pd (Intel): $APP_VERSION"
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
echo "📦 Сборка под архитектуру: x86_64 (Intel)"

# Сборка Swift под x86_64 (отдельная папка, чтобы не затирать ARM-сборку)
SWIFT_BUILD_DIR=".build-x86_64/release"
echo "🔨 Сборка проекта (x86_64)..."
if [ "$(uname -m)" = "arm64" ]; then
    arch -x86_64 swift build -c release --scratch-path .build-x86_64
else
    swift build -c release --scratch-path .build-x86_64
fi

if [ $? -ne 0 ]; then
    echo "❌ Ошибка сборки"
    exit 1
fi

echo "✅ Проект собран успешно"
EXECUTABLE_NAME="i2pd-gui"

if [ ! -f "${SWIFT_BUILD_DIR}/${EXECUTABLE_NAME}" ]; then
    echo "❌ Исполняемый файл не найден: ${SWIFT_BUILD_DIR}/${EXECUTABLE_NAME}"
    exit 1
fi

echo "📍 Найден исполняемый файл: ${SWIFT_BUILD_DIR}/${EXECUTABLE_NAME}"

# Структура .app — отдельное имя для Intel-сборки
APP_DIR="${APP_DIR_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📁 Создание структуры .app (Intel)..."

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Копируем исполняемый файл GUI
cp "${SWIFT_BUILD_DIR}/${EXECUTABLE_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Копируем бинарник i2pd из intel/
cp "${INTEL_DIR}/i2pd" "${RESOURCES_DIR}/i2pd"
chmod +x "${RESOURCES_DIR}/i2pd"
echo "✅ Бинарник i2pd (Intel) скопирован"

# Иконка
if [ -f "I2P-GUI.icns" ]; then
    cp "I2P-GUI.icns" "${RESOURCES_DIR}/I2P-GUI.icns"
    echo "✅ Иконка приложения скопирована"
else
    echo "⚠️  Иконка I2P-GUI.icns не найдена"
fi

# Конфигурационные файлы (из корня репозитория)
echo "📋 Копирование конфигурационных файлов..."
for f in subscriptions.txt i2pd.conf tunnels.conf; do
    if [ -f "$f" ]; then
        cp "$f" "${RESOURCES_DIR}/$f"
        echo "✅ $f скопирован"
    else
        echo "⚠️  $f не найден"
    fi
done

# Локализации
if [ -d "Resources" ]; then
    echo "🌐 Копирование локализаций (.lproj)..."
    cp -R Resources/*.lproj "${RESOURCES_DIR}/" 2>/dev/null || true
    echo "✅ Локализации скопированы"
fi

# Формируем tools из intel/: i2p-tools (всё кроме i2pd)
echo "🔧 Копирование утилит из ${INTEL_DIR}/ в tools..."
TOOLS_INTEL="${RESOURCES_DIR}/tools"
mkdir -p "${TOOLS_INTEL}"
for bin in b33address famtool i2pbase64 keygen keyinfo offlinekeys regaddr regaddr_3ld regaddralias routerinfo vain verifyhost x25519; do
    if [ -f "${INTEL_DIR}/${bin}" ]; then
        cp "${INTEL_DIR}/${bin}" "${TOOLS_INTEL}/${bin}"
        chmod +x "${TOOLS_INTEL}/${bin}"
    fi
done
echo "✅ Утилиты tools (Intel) скопированы"

# Info.plist
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

chmod +x "${MACOS_DIR}/${APP_NAME}"

echo "✅ Права доступа установлены"

echo "🧹 Очистка атрибутов macOS..."
xattr -cr "${APP_DIR}" 2>/dev/null || true
echo "✅ Атрибуты очищены"

echo "🔐 Подпись приложения..."
codesign --force --options runtime --sign - "${APP_DIR}" 2>/dev/null || {
    echo "⚠️  Автоматическая подпись недоступна, используйте ручную подпись"
    echo "   codesign --sign \"Your Certificate\" \"${APP_DIR}\""
}
echo "✅ Подпись завершена"

echo ""
echo "🎉 Приложение для Intel (x86_64) создано успешно!"
echo ""
echo "📊 Информация:"
echo "   📍 Путь: $(pwd)/${APP_DIR}"
echo "   📦 Размер: $(du -sh "${APP_DIR}" | cut -f1)"
echo "   📋 ID: ${BUNDLE_ID}"
echo "   📱 Версия: ${APP_VERSION}"
echo "   🖥️  Архитектура: x86_64 (Intel)"
echo ""
echo "📁 Включены: i2pd, tools (i2p-tools) из папки intel/"
echo ""
echo "🚀 Запуск: open ${APP_DIR}"
echo "✅ Готово!"
