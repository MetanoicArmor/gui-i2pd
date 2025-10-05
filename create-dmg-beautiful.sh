#!/bin/bash
set -e

echo "🍎 Создание профессионального DMG образа для I2P Daemon GUI"
echo "========================================================="

# Переменные
APP_NAME="I2P Daemon GUI"
DMG_NAME="I2P-Daemon-GUI-v2.58.0"
VOLUME_NAME="I2P Daemon GUI"

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

# Создаем красивый README файл
cat > "${DMG_DIR}/README.txt" << EOF
┌─────────────────────────────────────────────────────────────┐
│                    I2P Daemon GUI v${I2PD_VERSION}                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  🚀 Современный GUI для управления I2P daemon на macOS     │
│                                                             │
│  📋 Установка:                                              │
│     1. Перетащите "I2P Daemon GUI.app" в папку Applications │
│     2. Запустите приложение из папки Applications          │
│                                                             │
│  📋 Системные требования:                                   │
│     • macOS 14.0 или новее                                 │
│     • Intel x64 или Apple Silicon (M1/M2/M3/M4)            │
│                                                             │
│  🌐 Дополнительная информация:                              │
│     https://github.com/MetanoicArmor/gui-i2pd              │
│                                                             │
│  ✨ Особенности:                                            │
│     • Полная интеграция с системным треем macOS            │
│     • Локализация интерфейса (RU/EN)                       │
│     • Умный перезапуск при смене языка                     │
│     • Стандартный путь конфигурации macOS                  │
│                                                             │
│  Спасибо за использование I2P Daemon GUI! 🎉              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
EOF

echo "✅ Структура DMG создана"

# Создаем DMG образ напрямую
echo "🔨 Создание DMG образа..."

hdiutil create -srcfolder "${DMG_DIR}" -volname "${VOLUME_NAME}" -fs HFS+ -format UDZO -imagekey zlib-level=9 "${DMG_NAME}.dmg"

echo "✅ DMG образ создан"

# Создаем самоподписанный сертификат для подписи
echo "🔐 Создание сертификата для подписи..."

# Проверяем, есть ли уже сертификат
if security find-identity -v -p codesigning | grep -q "I2P Daemon GUI"; then
    echo "✅ Сертификат уже существует"
else
    echo "🔨 Создаем новый сертификат..."
    
    # Создаем конфигурацию для сертификата
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

    # Генерируем ключ и сертификат
    openssl req -x509 -newkey rsa:2048 -keyout /tmp/dmg_key.pem -out /tmp/dmg_cert.pem -days 365 -nodes -config /tmp/dmg_cert.conf 2>/dev/null
    
    # Импортируем в keychain
    security import /tmp/dmg_key.pem -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign 2>/dev/null || true
    security import /tmp/dmg_cert.pem -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign 2>/dev/null || true
    
    # Настраиваем доверие
    security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db /tmp/dmg_cert.pem 2>/dev/null || true
    
    echo "✅ Сертификат создан"
fi

# Подписываем DMG
echo "🔐 Подпись DMG..."

# Пробуем разные варианты подписи
if security find-identity -v -p codesigning | grep -q "I2P Daemon GUI"; then
    codesign --force --sign "I2P Daemon GUI" "${DMG_NAME}.dmg" 2>/dev/null && echo "✅ DMG подписан сертификатом 'I2P Daemon GUI'"
elif security find-identity -v -p codesigning | grep -q "Developer ID"; then
    DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    codesign --force --sign "$DEVELOPER_ID" "${DMG_NAME}.dmg" 2>/dev/null && echo "✅ DMG подписан Developer ID сертификатом"
else
    codesign --force --sign - "${DMG_NAME}.dmg" 2>/dev/null && echo "✅ DMG подписан базовой подписью"
fi

# Проверяем подпись
echo "🔍 Проверка подписи..."
if codesign -v "${DMG_NAME}.dmg" 2>/dev/null; then
    echo "✅ Подпись валидна"
    SIGNATURE_INFO=$(codesign -dv "${DMG_NAME}.dmg" 2>&1 | grep -o 'Authority=[^)]*' || echo "Базовая подпись")
    echo "📋 Информация о подписи: $SIGNATURE_INFO"
else
    echo "⚠️ Проблемы с подписью, но DMG создан"
fi

# Очищаем временные файлы
echo "🧹 Очистка временных файлов..."
rm -rf "${TEMP_DIR}"
rm -f /tmp/dmg_cert.conf /tmp/dmg_key.pem /tmp/dmg_cert.pem

# Показываем информацию о созданном DMG
echo ""
echo "🎉 Профессиональный DMG образ создан успешно!"
echo ""
echo "📊 Информация:"
echo "   📍 Путь: $(pwd)/${DMG_NAME}.dmg"
echo "   📦 Размер: $(du -sh "${DMG_NAME}.dmg" | cut -f1)"
echo "   📱 Версия: ${I2PD_VERSION}"
echo "   🏷️ Название тома: ${VOLUME_NAME}"
echo ""
echo "📁 Содержимое DMG:"
echo "   📱 ${APP_NAME}.app - основное приложение"
echo "   📁 Applications - ссылка на папку приложений"
echo "   📄 README.txt - красивая инструкция по установке"
echo ""
echo "🚀 Способы использования:"
echo "   Двойной клик на: ${DMG_NAME}.dmg"
echo "   Команда: open ${DMG_NAME}.dmg"
echo "   Перетаскивание в Applications"
echo ""
echo "🔐 Безопасность:"
echo "   DMG подписан для уменьшения предупреждений macOS"
echo "   При первом запуске может потребоваться разрешение в настройках безопасности"
echo ""
echo "✅ Готово к профессиональному распространению!"
