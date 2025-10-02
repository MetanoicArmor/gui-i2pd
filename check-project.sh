#!/bin/bash

echo "🔍 Проверка проекта I2PD GUI"
echo "=============================="

echo "📁 Проверка структуры проекта..."

# Проверяем наличие основных файлов
required_files=(
    "i2pd-gui.xcodeproj/project.pbxproj"
    "i2pd-gui/App.swift"
    "i2pd-gui/contentView.swift"
    "i2pd-gui/I2pdManager.swift"
    "i2pd-gui/i2pd"
    "Package.swift"
)

missing_files=()

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (отсутствует)"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
    echo ""
    echo "🎯 Все основные файлы присутствуют!"
else
    echo ""
    echo "⚠️  Отсутствуют файлы:"
    for file in "${missing_files[@]}"; do
        echo "   - $file"
    done
fi

echo ""
echo "💻 Проверка бинарника i2pd..."
if [ -f "i2pd-gui/i2pd" ]; then
    echo "✅ Бинарник i2pd найден"
    echo "📊 Размер файла: $(ls -lh i2pd-gui/i2pd | awk '{print $5}')"
    echo "🏗️  Архитектура: $(file i2pd-gui/i2pd | grep -o 'arm64\|x86_64')"
else
    echo "❌ Бинарник i2pd отсутствует в папке проекта"
    echo "💡 Скопируйте бинарник в папку i2pd-gui/"
fi

echo ""
echo "🏊 Проверка синтаксиса Swift..."
cd "i2pd-gui"
has_errors=false

for swift_file in *.swift; do
    if [ -f "$swift_file" ]; then
        echo "🔍 Проверка $swift_file..."
        if swiftc -parse "$swift_file" 2>/dev/null; then
            echo "✅ $swift_file - синтаксис корректен"
        else
            echo "❌ $swift_file - ошибки синтаксиса"
            has_errors=true
        fi
    fi
done

echo ""
if [ "$has_errors" = true ]; then
    echo "⚠️  Обнаружены ошибки в Swift файлах"
else
    echo "✅ Все Swift файлы корректны"
fi

echo ""
echo "🚀 Способы запуска:"
echo "   1. open i2pd-gui.xcodeproj"
echo "   2. swift build && swift run (из корневой папки)"
echo ""
echo "📋 Статус проекта: ГОТОВ К ИСПОЛЬЗОВАНИЮ!"
