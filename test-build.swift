#!/usr/bin/env swift

import Foundation

// Простой тест функциональности без GUI
print("🏃 Простой тест функциональности I2PD GUI")
print("==========================================")

// Проверяем наличие бинарника
let executablePaths = ["./i2pd", "/usr/local/bin/i2pd", "/opt/homebrew/bin/i2pd"]
var foundPath = ""

for path in executablePaths {
    if FileManager.default.fileExists(atPath: path) {
        foundPath = path
        print("✅ Найден бинарник i2pd по пути: \(path)")
        break
    }
}

if foundPath.isEmpty {
    print("❌ Бинарник i2pd не найден")
    print("💡 Убедитесь, что файл i2pd находится в текущей директории")
} else {
    print("✅ Файловая система проверена")
}

// Проверяем системные команды
print("\n🔍 Проверка системных команд...")
let checkProcess = Process()
checkProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
checkProcess.arguments = ["-c", "pgrep -f i2pd"]

let pipe = Pipe()
checkProcess.standardOutput = pipe

do {
    try checkProcess.run()
    checkProcess.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    
    if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        print("📊 Статус: I2P daemon не запущен")
    } else {
        print("📊 Статус: I2P daemon запущен (процессы найдены)")
    }
} catch {
    print("❌ Ошибка проверки статуса: \(error.localizedDescription)")
}

print("\n🎯 Тест завершен!")
print("💡 Для запуска полного GUI приложения используйте Xcode:")
print("   open i2pd-gui.xcodeproj")
