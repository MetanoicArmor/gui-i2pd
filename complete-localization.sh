#!/bin/bash

FILE="Sources/i2pd-gui/AppCore.swift"

# Создаём бэкап
cp "$FILE" "$FILE.bak2"

# About screen
perl -i -pe 's/Text\("Современный GUI для управления I2P Daemon"\)/Text(L("Современный GUI для управления I2P Daemon"))/g' "$FILE"
perl -i -pe 's/Text\("• Радикальная остановка daemon"\)/Text(L("• Радикальная остановка daemon"))/g' "$FILE"
perl -i -pe 's/Text\("• Мониторинг в реальном времени"\)/Text(L("• Мониторинг в реальном времени"))/g' "$FILE"
perl -i -pe 's/Text\("• Подвижное и масштабируемое окно"\)/Text(L("• Подвижное и масштабируемое окно"))/g' "$FILE"
perl -i -pe 's/Text\("• Тёмный интерфейс"\)/Text(L("• Тёмный интерфейс"))/g' "$FILE"
perl -i -pe 's/Text\("Разработано на SwiftUI"\)/Text(L("Разработано на SwiftUI"))/g' "$FILE"
perl -i -pe 's/Text\("Swift 5\.7\+ • macOS 14\.0\+"\)/Text(L("Swift 5.7+ • macOS 14.0+"))/g' "$FILE"

# Stats section
perl -i -pe 's/Text\("📊 Сетевая статистика"\)/Text(L("📊 Сетевая статистика"))/g' "$FILE"
perl -i -pe 's/Text\("Время работы"\)/Text(L("Время работы"))/g' "$FILE"
perl -i -pe 's/Text\("Подключения"\)/Text(L("Подключения"))/g' "$FILE"

# Logs section
perl -i -pe 's/Text\("📋 Логи системы"\)/Text(L("📋 Логи системы"))/g' "$FILE"
perl -i -pe 's/Text\("Система готова к работе"\)/Text(L("Система готова к работе"))/g' "$FILE"
perl -i -pe 's/Text\("Логи появятся при запуске демона"\)/Text(L("Логи появятся при запуске демона"))/g' "$FILE"

# Settings title
perl -i -pe 's/Text\("⚙️ Настройки"\)/Text(L("⚙️ Настройки"))/g' "$FILE"
perl -i -pe 's/Text\("Esc для закрытия"\)/Text(L("Esc для закрытия"))/g' "$FILE"

# Bandwidth
perl -i -pe 's/Text\("Пропускная способность"\)/Text(L("Пропускная способность"))/g' "$FILE"

# Dock hide message
perl -i -pe 's/Text\("При включении приложение скроется из Dock и станет доступно только через трей\. ✅ Настройка восстанавливается при перезапуске\."\)/Text(L("При включении приложение скроется из Dock и станет доступно только через трей\. ✅ Настройка восстанавливается при перезапуске\."))/g' "$FILE"

# Address book intervals
perl -i -pe 's/Text\("Каждые 6 часов"\)/Text(L("Каждые 6 часов"))/g' "$FILE"
perl -i -pe 's/Text\("Ежедневно"\)/Text(L("Ежедневно"))/g' "$FILE"
perl -i -pe 's/Text\("Каждые 3 дня"\)/Text(L("Каждые 3 дня"))/g' "$FILE"
perl -i -pe 's/Text\("Еженедельно"\)/Text(L("Еженедельно"))/g' "$FILE"

# Address book subscriptions
perl -i -pe 's/Text\("• reg\.i2p - Основной реестр адресов"\)/Text(L("• reg.i2p - Основной реестр адресов"))/g' "$FILE"
perl -i -pe 's/Text\("• identiguy\.i2p - Альтернативный источник"\)/Text(L("• identiguy.i2p - Альтернативный источник"))/g' "$FILE"
perl -i -pe 's/Text\("• stats\.i2p - Статистика сети"\)/Text(L("• stats.i2p - Статистика сети"))/g' "$FILE"
perl -i -pe 's/Text\("• i2p-projekt\.i2p - Проектный источник"\)/Text(L("• i2p-projekt.i2p - Проектный источник"))/g' "$FILE"

# Reset confirmation
perl -i -pe 's/Text\("Все настройки будут сброшены к значениям по умолчанию\. Вы уверены\?"\)/Text(L("Все настройки будут сброшены к значениям по умолчанию\. Вы уверены\?"))/g' "$FILE"

# Status messages
perl -i -pe 's/Text\("Пропускная способность изменена и сохранена в конфиг: \\$\(displayBandwidth\)"\)/Text(String(format: L("Пропускная способность изменена и сохранена в конфиг: %@"), displayBandwidth))/g' "$FILE"
perl -i -pe 's/Text\("HTTP порт изменен и сохранен в конфиг: \\$\(displayDaemonPort\)"\)/Text(String(format: L("HTTP порт изменен и сохранен в конфиг: %@"), displayDaemonPort))/g' "$FILE"
perl -i -pe 's/Text\("SOCKS порт изменен и сохранен в конфиг: \\$\(displaySocksPort\)"\)/Text(String(format: L("SOCKS порт изменен и сохранен в конфиг: %@"), displaySocksPort))/g' "$FILE"

# Buttons in existing strings
perl -i -pe 's/Button\("Изменить"\)/Button(L("Изменить"))/g' "$FILE"

echo "✅ Полная локализация применена"

