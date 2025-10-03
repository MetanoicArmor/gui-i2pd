#!/bin/bash

FILE="Sources/i2pd-gui/AppCore.swift"

# Создаём бэкап
cp "$FILE" "$FILE.log_backup"

# Локализуем логи с русским текстом
perl -i -pe 's/addLog\(\.debug, "🔧 Инициализация I2pdManager"\)/addLog(.debug, L("🔧 Инициализация I2pdManager"))/g' "$FILE"
perl -i -pe 's/addLog\(\.debug, "📍 Bundle path:/addLog(.debug, L("📍 Bundle path:") + " /g' "$FILE"
perl -i -pe 's/addLog\(\.debug, "🎯 Ресурсный путь:/addLog(.debug, L("🎯 Ресурсный путь:") + " /g' "$FILE"
perl -i -pe 's/addLog\(\.debug, "✅ Финальный путь:/addLog(.debug, L("✅ Финальный путь:") + " /g' "$FILE"
perl -i -pe 's/"🔍 Файл существует:/"🔍 " + L("Файл существует:") + " /g' "$FILE"
perl -i -pe 's/"✅ да"/"✅ " + L("да")/g' "$FILE"
perl -i -pe 's/"❌ нет"/"❌ " + L("нет")/g' "$FILE"
perl -i -pe 's/addLog\(\.info, "📱 Daemon запущен из трея - обновляем статус"\)/addLog(.info, L("📱 Daemon запущен из трея - обновляем статус"))/g' "$FILE"
perl -i -pe 's/addLog\(\.info, "📱 Daemon остановлен из трея - обновляем статус"\)/addLog(.info, L("📱 Daemon остановлен из трея - обновляем статус"))/g' "$FILE"
perl -i -pe 's/addLog\(\.info, "📱 Статус обновлен из трея"\)/addLog(.info, L("📱 Статус обновлен из трея"))/g' "$FILE"
perl -i -pe 's/addLog\(\.warn, "Операция уже выполняется, пропускаем\.\.\."\)/addLog(.warn, L("Операция уже выполняется, пропускаем..."))/g' "$FILE"
perl -i -pe 's/addLog\(\.info, "Запуск I2P daemon\.\.\."\)/addLog(.info, L("Запуск I2P daemon..."))/g' "$FILE"
perl -i -pe 's/addLog\(\.debug, "🔄 Пытаемся запустить daemon\.\.\."\)/addLog(.debug, L("🔄 Пытаемся запустить daemon..."))/g' "$FILE"
perl -i -pe 's/addLog\(\.debug, "📍 Путь к бинарнику:/addLog(.debug, L("📍 Путь к бинарнику:") + " /g' "$FILE"
perl -i -pe 's/addLog\(\.debug, "🔍 Проверка существования:/addLog(.debug, L("🔍 Проверка существования:") + " /g' "$FILE"
perl -i -pe 's/addLog\(\.warn, "I2P daemon уже запущен"\)/addLog(.warn, L("I2P daemon уже запущен"))/g' "$FILE"
perl -i -pe 's/addLog\(\.info, "🚫 ОСТАНОВКА ДЕМОНА ИЗ I2pdManager НАЧАТА!"\)/addLog(.info, L("🚫 ОСТАНОВКА ДЕМОНА ИЗ I2pdManager НАЧАТА!"))/g' "$FILE"
perl -i -pe 's/addLog\(\.info, "🛑 Остановка I2P daemon через kill -s INT\.\.\."\)/addLog(.info, L("🛑 Остановка I2P daemon через kill -s INT..."))/g' "$FILE"
perl -i -pe 's/addLog\(\.info, "✅ Демон остановлен"\)/addLog(.info, L("✅ Демон остановлен"))/g' "$FILE"
perl -i -pe 's/addLog\(\.info, "Проверка статуса\.\.\."\)/addLog(.info, L("Проверка статуса..."))/g' "$FILE"
perl -i -pe 's/addLog\(\.info, "Логи очищены"\)/addLog(.info, L("Логи очищены"))/g' "$FILE"
perl -i -pe 's/addLog\(\.info, "📊 Статистика сброшена \(daemon остановлен\)"\)/addLog(.info, L("📊 Статистика сброшена (daemon остановлен)"))/g' "$FILE"
perl -i -pe 's/addLog\(\.info, "📊 Расширенная статистика обновлена"\)/addLog(.info, L("📊 Расширенная статистика обновлена"))/g' "$FILE"
perl -i -pe 's/addLog\(\.info, "Daemon остановлен"\)/addLog(.info, L("Daemon остановлен"))/g' "$FILE"

echo "✅ Локализация логов завершена"

