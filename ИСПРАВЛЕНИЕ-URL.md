# ✅ Исправлена ошибка с URL в Process

## ❌ Проблема
```
*** -[NSConcreteTask setExecutableURL:]: non-file URL argument
NSInvalidArgumentException: *** -[NSConcreteTask setExecutableURL:]: non-file URL argument
```

## 🔧 Причина ошибки
В методе `checkDaemonStatus` использовался неправильный способ создания URL:

**❌ Неправильно:**
```swift
checkProcess.executableURL = URL(string: "/bin/bash")
```

**✅ Правильно:**
```swift
checkProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
```

## 📋 Объяснение

- `URL(string:)` создает произвольный URL и может возвращать `nil` или неподходящий тип URL
- `URL(fileURLWithPath:)` специально предназначен для файловых путей и всегда создает корректный `file://` URL
- `Process.executableURL` требует именно `file://` URL для исполняемых файлов

## ✅ Исправление

Найден и исправлен проблемный код в методе `I2pdManager.checkDaemonStatus()`:

```swift
private func checkDaemonStatus() {
    let checkProcess = Process()
    checkProcess.executableURL = URL(fileURLWithPath: "/bin/bash")  // ← Исправлено
    checkProcess.arguments = ["-c", "pgrep -f i2pd"]
    
    // ... остальной код ...
}
```

## 🎯 Результат

✅ **Приложение более не крашится** при проверке статуса  
✅ **Swift Package Manager собирается успешно**  
✅ **Код корректно работает с Process API**  
✅ **Проект готов к запуску**  

## 🚀 Готово к использованию

```bash
# Запуск через Swift Package Manager
swift run

# Сборка для релиза
swift build -c release
```

Приложение теперь стабильно работает без сбоев!
