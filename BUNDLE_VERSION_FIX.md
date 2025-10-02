# Bundle Version Fix Explained

## 🚨 Проблема
Приложение крашится с ошибкой:
```
-[__NSCFNumber _getCString:maxLength:encoding:]: unrecognized selector
```

## 🔍 Причина
В Info.plist неправильные типы данных:
```xml
<!-- НЕПРАВИЛЬНО (вызывает краш): -->
<key>CFBundleVersion</key>
<real>1</real>

<!-- ПРАВИЛЬНО: -->
<key>CFBundleVersion</key>
<string>1</string>
```

## ✅ Исправление
1. `CFBundleShortVersionString` → `<string>1.0</string>`
2. `CFBundleVersion` → `<string>1</string>`
3. В project.yml тоже строки: `CFBundleVersion: "1"`

## 📱 Результат
✅ Приложение запускается без крашей
✅ Совместимость с macOS 14+
✅ Правильная работа Bundle ID
✅ Ручное управление демоном работает

## 🎮 Тестирование
```bash
open I2P-GUI.app        # Запуск GUI
# Использовать кнопки "Запустить"/"Остановить"
# Демон НЕ запускается автоматически
```
