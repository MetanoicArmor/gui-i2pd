# Xcode Development Guide

## 🚀 Запуск проекта

```bash
# 1. Генерировать проект из изменений в project.yml
xcodegen generate

# 2. Открыть в Xcode  
open I2P-Daemon-GUI.xcodeproj

# 3. Или запустить из командной строки
open I2P-Daemon-GUI.xcodeproj
```

## 🔧 Настройки проекта

**Target:** i2pd-gui  
**Scheme:** i2pd-gui  
**Configuration:** 
- **Debug** - для разработки и отладки
- **Release** - для финальной сборки

**macOS Deployment Target:** 14.0+

## 📝 Отладка

### Консоль и логи
- **Debug Navigator** → **Console**
- Логи Swift: `print()` statements
- Логи i2pd демона: проверка через `pgrep i2pd`

### Точки останова (Breakpoints)
- Клик на номер линии в редакторе
- Условные точки: клик правой кнопкой на точке
- Логи points: вместо остановки пишут в консоль

### Variables View
- Просмотр значений переменных
- Возможность изменить значения в рантайме

## 🔍 Частые проблемы

### "No scheme found"
```bash
xcodegen generate
# Затем в Xcode: Product → Scheme → Manage Schemes
```

### Build errors
```bash
# Очистить build
⌘ + Shift + K

# Clean build folder
Product → Clean Build Folder
```

### i2pd binary not found
- Проверить: Bundle Resources содержит ли файл `i2pd`
- Путь в коде: `Bundle.main.resourceURL?.appendingPathComponent("i2pd")`

## 🛠️ Полезные сочетания клавиш

- **⌘ + R** - Build and Run
- **⌘ + Shift + K** - Clean
- **⌘ + Shift + O** - Open Quickly  
- **⌘ + ** - Show/hide Navigator
- **⌘ + Option + ** - Show/hide Inspector
- **⌘ + Shift + Y** - Show/hide Debug area

## 📱 Тестирование

### GUI отладка
1. Запуск через **⌘ + R**
2. Проверка в Debug Console
3. Использование Variables View для состояния

### Демон отладка  
```bash
# Проверить процесс
ps aux | grep i2pd

# Остановить демон
killall i2pd

# Проверить конфиг
cat ~/.i2pd/i2pd.conf
```

## 🎯 Готово!

Теперь у вас полноценная среда разработки в Xcode для работы с I2P Daemon GUI!
