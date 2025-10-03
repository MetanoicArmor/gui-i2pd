#!/bin/bash

# Скрипт для автоматической замены текста на L() хелпер

FILE="Sources/i2pd-gui/AppCore.swift"

# Создаём бэкап
cp "$FILE" "$FILE.backup"

# Заменяем заголовки секций
sed -i '' 's/title: "🌐 Сетевая конфигурация"/title: "🌐 " + L("Сетевая конфигурация")/g' "$FILE"
sed -i '' 's/title: "💻 Автоматизация"/title: "💻 " + L("Автоматизация")/g' "$FILE"
sed -i '' 's/title: "🎨 Интерфейс"/title: "🎨 " + L("Интерфейс")/g' "$FILE"
sed -i '' 's/title: "📊 Мониторинг"/title: "📊 " + L("Мониторинг")/g' "$FILE"
sed -i '' 's/title: "💾 Данные"/title: "💾 " + L("Данные")/g' "$FILE"
sed -i '' 's/title: "🔄 Действия"/title: "🔄 " + L("Действия")/g' "$FILE"
sed -i '' 's/title: "📁 Конфигурация"/title: "📁 " + L("Конфигурация")/g' "$FILE"
sed -i '' 's/title: "🚇 Туннели"/title: "🚇 " + L("Туннели")/g' "$FILE"
sed -i '' 's/title: "🖥️ Веб-консоль"/title: "🖥️ " + L("Веб-консоль")/g' "$FILE"

# Заменяем частые строки
sed -i '' 's/Text("Сохранить")/Text(L("Сохранить"))/g' "$FILE"
sed -i '' 's/Text("Открыть")/Text(L("Открыть"))/g' "$FILE"
sed -i '' 's/Text("Изменить")/Text(L("Изменить"))/g' "$FILE"
sed -i '' 's/Text("Очистить")/Text(L("Очистить"))/g' "$FILE"
sed -i '' 's/Text("Настроить")/Text(L("Настроить"))/g' "$FILE"
sed -i '' 's/Text("Показать")/Text(L("Показать"))/g' "$FILE"
sed -i '' 's/Text("Редактировать")/Text(L("Редактировать"))/g' "$FILE"

# Статусы
sed -i '' 's/Text("Stopped")/Text(L("Stopped"))/g' "$FILE"
sed -i '' 's/Text("Running")/Text(L("Running"))/g' "$FILE"
sed -i '' 's/Text("Работает")/Text(L("Работает"))/g' "$FILE"
sed -i '' 's/Text("Остановлен")/Text(L("Остановлен"))/g' "$FILE"

# Основные элементы
sed -i '' 's/Text("Порт HTTP прокси")/Text(L("Порт HTTP прокси"))/g' "$FILE"
sed -i '' 's/Text("Порт SOCKS5 прокси")/Text(L("Порт SOCKS5 прокси"))/g' "$FILE"
sed -i '' 's/Text("Обновить статус")/Text(L("Обновить статус"))/g' "$FILE"
sed -i '' 's/Text("Сетевая статистика")/Text(L("Сетевая статистика"))/g' "$FILE"
sed -i '' 's/Text("Логи системы")/Text(L("Логи системы"))/g' "$FILE"
sed -i '' 's/Text("Свернуть в трей")/Text(L("Свернуть в трей"))/g' "$FILE"
sed -i '' 's/Text("Очистить логи")/Text(L("Очистить логи"))/g' "$FILE"

# Settings labels
sed -i '' 's/Text("Автозапуск приложения")/Text(L("Автозапуск приложения"))/g' "$FILE"
sed -i '' 's/Text("Автозапуск демона")/Text(L("Автозапуск демона"))/g' "$FILE"
sed -i '' 's/Text("Запускать свернутым")/Text(L("Запускать свернутым"))/g' "$FILE"
sed -i '' 's/Text("Отображение приложения")/Text(L("Отображение приложения"))/g' "$FILE"
sed -i '' 's/Text("Скрыть из Dock")/Text(L("Скрыть из Dock"))/g' "$FILE"
sed -i '' 's/Text("Обновление каждые 5 сек")/Text(L("Обновление каждые 5 сек"))/g' "$FILE"
sed -i '' 's/Text("Автоматическая очистка логов")/Text(L("Автоматическая очистка логов"))/g' "$FILE"
sed -i '' 's/Text("Путь к данным")/Text(L("Путь к данным"))/g' "$FILE"
sed -i '' 's/Text("Очистить кэш")/Text(L("Очистить кэш"))/g' "$FILE"
sed -i '' 's/Text("Экспорт логов")/Text(L("Экспорт логов"))/g' "$FILE"
sed -i '' 's/Text("Сбросить настройки")/Text(L("Сбросить настройки"))/g' "$FILE"
sed -i '' 's/Text("Тестовая статистика")/Text(L("Тестовая статистика"))/g' "$FILE"
sed -i '' 's/Text("Конфиг файл")/Text(L("Конфиг файл"))/g' "$FILE"
sed -i '' 's/Text("Папка данных")/Text(L("Папка данных"))/g' "$FILE"
sed -i '' 's/Text("Журналы")/Text(L("Журналы"))/g' "$FILE"
sed -i '' 's/Text("Управление туннелями")/Text(L("Управление туннелями"))/g' "$FILE"
sed -i '' 's/Text("Пример туннелей")/Text(L("Пример туннелей"))/g' "$FILE"
sed -i '' 's/Text("Подписки adressbook")/Text(L("Подписки adressbook"))/g' "$FILE"
sed -i '' 's/Text("Автообновление:")/Text(L("Автообновление:"))/g' "$FILE"
sed -i '' 's/Text("Интервал обновления:")/Text(L("Интервал обновления:"))/g' "$FILE"
sed -i '' 's/Text("Текущие подписки:")/Text(L("Текущие подписки:"))/g' "$FILE"
sed -i '' 's/Text("Веб-интерфейс")/Text(L("Веб-интерфейс"))/g' "$FILE"
sed -i '' 's/Text("Порт: 7070")/Text(L("Порт: 7070"))/g' "$FILE"
sed -i '' 's/Text("Копировать URL")/Text(L("Копировать URL"))/g' "$FILE"

# Buttons
sed -i '' 's/Button("Отключить автозапуск"/Button(L("Отключить автозапуск")/g' "$FILE"
sed -i '' 's/Button("Включить автозапуск"/Button(L("Включить автозапуск")/g' "$FILE"
sed -i '' 's/Button("Открыть папку"/Button(L("Открыть папку")/g' "$FILE"

# Labels
sed -i '' 's/Label("Отключить автозапуск"/Label(L("Отключить автозапуск")/g' "$FILE"
sed -i '' 's/Label("Включить автозапуск"/Label(L("Включить автозапуск")/g' "$FILE"
sed -i '' 's/Label("Открыть папку"/Label(L("Открыть папку")/g' "$FILE"

echo "✅ Локализация применена к $FILE"
echo "📁 Бэкап сохранён в $FILE.backup"

