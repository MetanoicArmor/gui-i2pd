#!/bin/bash
set -e

echo "🚀 Создание релиза с версией i2pd"
echo "================================="

# Определяем версию i2pd
VERSION_OUTPUT=$(./i2pd --version 2>&1)
I2PD_VERSION=$(echo "$VERSION_OUTPUT" | grep -o "i2pd version [0-9]\+\.[0-9]\+\.[0-9]\+" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1)

if [ -z "$I2PD_VERSION" ]; then
    echo "❌ Не удалось определить версию i2pd"
    exit 1
fi

echo "✅ Версия i2pd: $I2PD_VERSION"

# Проверяем текущий статус git
if [ -n "$(git status --porcelain)" ]; then
    echo "📝 Есть незакоммиченные изменения..."
    echo "🔍 Что изменилось:"
    git status --short
    
    read -p "❓ Коммитить изменения? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add .
        git commit -m "🔄 Обновление для релиза v$I2PD_VERSION"
    else
        echo "⚠️ Нужно закоммитить изменения перед созданием релиза"
        exit 1
    fi
fi

# Пушим изменения
echo "📤 Отправка изменений в GitHub..."
git push origin main

# Проверяем существует ли тег с этой версией
if git tag -l | grep -q "^v$I2PD_VERSION$"; then
    echo "⚠️ Тег v$I2PD_VERSION уже существует!"
    read -p "❓ Удалить существующий тег и релиз? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Удаляем релиз на GitHub
        gh release delete v$I2PD_VERSION --yes || echo "Релиз не найден"
        
        # Удаляем локальный тег
        git tag -d v$I2PD_VERSION
        git push origin --delete v$I2PD_VERSION || echo "Удаленный тег не найден"
        
        echo "✅ Старый тег и релиз удалены"
    else
        echo "❌ Отменено"
        exit 1
    fi
fi

# Создаем тег
echo "🏷️ Создание тега v$I2PD_VERSION..."
git tag v$I2PD_VERSION
git push origin v$I2PD_VERSION

# Собираем приложение
echo "🔨 Сборка приложения..."
./build-app-simple.sh

# Архивируем приложение
APP_FILE="I2P-GUI-v$I2PD_VERSION.app.zip"
echo "📦 Архивирование: $APP_FILE"
zip -r "$APP_FILE" I2P-GUI.app/

# Создаем релиз на GitHub
echo "📋 Создание релиза..."
RELEASE_NOTES="🎉 Релиз v$I2PD_VERSION

## 📋 Версия соответствует i2pd $I2PD_VERSION

**Новые возможности:**
- 📱 Полная интеграция с системным треем macOS
- ⚙️ Настройки открываются из главного окна
- 🚀 Управление daemon из трея (запуск/остановка/перезапуск)
- ⌨️ Горячие клавиши: Cmd+H (трей), Cmd+, (настройки)
- 🔗 Синхронизация статуса между окнами

**Технические улучшения:**
- Поэтапная остановка daemon (SIGINT → SIGKILL)
- Реальное время обновления статуса
- Стабильная работа в фоне

## 📁 Установка
Скачайте \`$APP_FILE\` и запустите приложение.

Версия автоматически синхронизирована с i2pd v$I2PD_VERSION"

gh release create v$I2PD_VERSION --title "$APP_FILE" --notes "$RELEASE_NOTES" --latest

# Загружаем файл
echo "📎 Загрузка архива в релиз..."
gh release upload v$I2PD_VERSION "$APP_FILE"

echo ""
echo "🎉 Релиз v$I2PD_VERSION создан успешно!"
echo "🔗 Ссылка: https://github.com/MetanoicArmor/gui-i2pd/releases/tag/v$I2PD_VERSION"
echo "📱 Версия приложения синхронизирована с i2pd v$I2PD_VERSION"
