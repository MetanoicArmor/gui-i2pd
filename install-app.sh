#!/bin/bash

echo "📌 Установка I2P GUI в Applications"
echo "================================="

APP_NAME="I2P-GUI.app"
APPLICATIONS_DIR="/Applications"

if [ ! -d "${APP_NAME}" ]; then
    echo "❌ Приложение ${APP_NAME} не найдено в текущей директории"
    echo "💡 Запустите сначала build-app-simple.sh"
    exit 1
fi

echo "📦 Найдено приложение: ${APP_NAME}"
echo "📊 Размер: $(du -sh ${APP_NAME} | cut -f1)"

# Удаляем старую версию если есть
if [ -d "${APPLICATIONS_DIR}/${APP_NAME}" ]; then
    echo "🗑️  Удаляем старую версию..."
    rm -rf "${APPLICATIONS_DIR}/${APP_NAME}"
    echo "✅ Старая версия удалена"
fi

# Копируем в Applications
echo "📁 Копируем в ${APPLICATIONS_DIR}..."
cp -R "${APP_NAME}" "${APPLICATIONS_DIR}/"

if [ $? -eq 0 ]; then
    echo "✅ Установлено в ${APPLICATIONS_DIR}/${APP_NAME}"
else
    echo "❌ Ошибка установки"
    exit 1
fi

# Проверяем права доступа
chmod +x "${APPLICATIONS_DIR}/${APP_NAME}/Contents/MacOS/"
chmod +x "${APPLICATIONS_DIR}/${APP_NAME}/Contents/Resources/"

echo "🔧 Права доступа настроены"

echo ""
echo "🎉 Установка завершена!"
echo ""
echo "🚀 Теперь доступно:"
echo "   1. ⌘+Space → \"I2P\" → Enter "
echo "   2. Обзор /Applications/I2P-GUI.app"
echo "   3. Перетащите в Dock для быстрого доступа"
echo ""
echo "📋 Информация об установке:"
echo "   📍 Путь: ${APPLICATIONS_DIR}/${APP_NAME}"
echo "   📦 Размер: $(du -sh ${APPLICATIONS_DIR}/${APP_NAME} | cut -f1)"
echo "   🔧 Создано: $(date)"
echo ""

# Показываем содержимое установленного приложения
echo "📋 Содержимое приложения:"
ls -la "${APPLICATIONS_DIR}/${APP_NAME}/Contents/"

echo ""
echo "✅ Готово к использованию!"
