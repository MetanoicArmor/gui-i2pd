#!/bin/bash
set -e

# Скрипт для извлечения версии из бинарника i2pd
# Использование: ./extract-version.sh [путь_к_бинарнику]

BINARY_PATH=${1:-./Sources/i2pd-gui/../i2pd}

echo "🔍 Проверка версии бинарника: $BINARY_PATH"

if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Бинарник не найден: $BINARY_PATH"
    exit 1
fi

# Извлекаем версию из вывода --version
VERSION_OUTPUT=$("$BINARY_PATH" --version 2>&1)
echo "📋 Вывод бинарника:"
echo "$VERSION_OUTPUT"

# Ищем строку с версией (формат: i2pd version x.x.x)
VERSION=$(echo "$VERSION_OUTPUT" | grep -o "i2pd version [0-9]\+\.[0-9]\+\.[0-9]\+" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)

if [ -z "$VERSION" ]; then
    echo "❌ Не удалось извлечь версию из бинарника"
    exit 1
fi

echo "✅ Найдена версия: $VERSION"

# Записываем версию в файл для использования в сборке
echo "$VERSION" > .i2pd-version
echo "📝 Версия записана в .i2pd-version"

# Обновляем Info.plist если он существует
if [ -f "Info.plist" ]; then
    echo "🔧 Обновление Info.plist с версией $VERSION"
    # Используем plutil для обновления версии в Info.plist
    plutil -replace CFBundleShortVersionString -string "$VERSION" Info.plist
    plutil -replace CFBundleVersion -string "$VERSION" Info.plist
    echo "✅ Info.plist обновлен"
else
    echo "⚠️ Info.plist не найден, создание не требуется"
fi

echo "🎉 Версия определена и обновлена: $VERSION"
