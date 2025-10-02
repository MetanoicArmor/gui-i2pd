#!/usr/bin/env swift

import Foundation

// Простой CLI интерфейс для управления i2pd
print("🔧 I2PD GUI - Командная строка версия")
print("=====================================")

// Поиск бинарника i2pd
func findI2pdBinary() -> String? {
    let possiblePaths = [
        "./i2pd",
        "./i2pd-gui/i2pd",
        "/usr/local/bin/i2pd",
        "/opt/homebrew/bin/i2pd",
        "/usr/bin/i2pd"
    ]
    
    for path in possiblePaths {
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
    }
    return nil
}

// Проверка статуса daemon
func checkDaemonStatus() -> Bool {
    defer { print("") }
    
    print("🔍 Проверка статуса I2P daemon...")
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", "pgrep -f i2pd"]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("📊 Статус: ОСТАНОВЛЕН ❌")
            return false
        } else {
            print("📊 Статус: ЗАПУЩЕН ✅")
            return true
        }
    } catch {
        print("❌ Ошибка проверки статуса: \(error.localizedDescription)")
        return false
    }
}

// Выполнение команды i2pd
func executeI2pdCommand(_ arguments: [String]) -> Bool {
    guard let binaryPath = findI2pdBinary() else {
        print("❌ Бинарник i2pd не найден!")
        print("💡 Проверьте пути:")
        print("   ./i2pd, ./i2pd-gui/i2pd, /usr/local/bin/i2pd")
        return false
    }
    
    print("🔧 Используем бинарник: \(binaryPath)")
    print("⚡ Выполняем команду: \(arguments.joined(separator: " "))")
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: binaryPath)
    process.arguments = arguments
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8), !output.isEmpty {
            print("📄 Вывод: \(output)")
        }
        
        print("✅ Команда выполнена")
        return true
    } catch {
        print("❌ Ошибка выполнения: \(error.localizedDescription)")
        return false
    }
}

// Показ меню команд
func showMenu() {
    print("\n📋 Доступные команды:")
    print("   1 - Статус daemon")
    print("   2 - Запустить daemon")
    print("   3 - Остановить daemon")
    print("   4 - Перезапустить daemon")
    print("   5 - Показать информацию")
    print("   0 - Выход")
    print("\n💡 Введите номер команды:")
}

// Главный цикл приложения
func main() {
    print("\n🎯 Добро пожаловать в I2PD CLI Manager!")
    print("🔄 Проверяем текущий статус...")
    
    let isRunning = checkDaemonStatus()
    
    while true {
        showMenu()
        
        if let input = readLine(), let choice = Int(input) {
            switch choice {
            case 1:
                print("\n📊 Проверка статуса daemon...")
                _ = checkDaemonStatus()
                
            case 2:
                if !checkDaemonStatus() {
                    print("\n🚀 Запуск I2P daemon...")
                    if executeI2pdCommand(["--daemon"]) {
                        Thread.sleep(forTimeInterval: 2)
                        _ = checkDaemonStatus()
                    }
                } else {
                    print("⚠️ Daemon уже запущен!")
                }
                
            case 3:
                if checkDaemonStatus() {
                    print("\n🛑 Остановка I2P daemon...")
                    if executeI2pdCommand(["--kill"]) {
                        Thread.sleep(forTimeInterval: 2)
                        _ = checkDaemonStatus()
                    }
                } else {
                    print("⚠️ Daemon уже остановлен!")
                }
                
            case 4:
                print("\n🔄 Перезапуск I2P daemon...")
                if checkDaemonStatus() {
                    _ = executeI2pdCommand(["--kill"])
                    Thread.sleep(forTimeInterval: 2)
                }
                _ = executeI2pdCommand(["--daemon"])
                Thread.sleep(forTimeInterval: 2)
                _ = checkDaemonStatus()
                
            case 5:
                print("\n📋 Информация о проекте:")
                print("   Название: I2PD GUI Manager")
                print("   Версия: 1.0")
                print("   Платформа: macOS")
                print("   Архитектура: ARM64")
                print("   Тип: CLI интерфейс")
                print("\n🔧 Для полного GUI используйте:")
                print("   swift build && swift run (Swift Package Manager)")
                
            case 0:
                print("\n👋 До свидания!")
                exit(0)
                
            default:
                print("❌ Неверный выбор. Попробуйте снова.")
            }
        } else {
            print("❌ Введите корректный номер команды.")
        }
    }
}

// Запуск приложения
main()
