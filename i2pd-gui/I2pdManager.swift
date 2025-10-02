import SwiftUI
import Foundation

// Модели данных
enum LogLevel: String, CaseIterable {
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
    case debug = "DEBUG"
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    
    init(level: LogLevel, message: String) {
        self.timestamp = Date()
        self.level = level
        self.message = message
    }
}

// Основной менеджер для I2P daemon
class I2pdManager: ObservableObject {
    @Published var isRunning = false
    @Published var isLoading = false
    @Published var uptime = "00:00:00"
    @Published var peerCount = 0
    @Published var logs: [LogEntry] = []
    
    private var i2pdProcess: Process?
    private var logTimer: Timer?
    
    private let executablePath: String
    
    init() {
        // Получаем путь к бинарнику i2pd внутри сборки приложения
        let bundlePath = Bundle.main.resourceURL?.path ?? ""
        var foundPath = "\(bundlePath)/i2pd"
        
        // Пытаемся найти i2pd в системных путях как fallback
        let systemPaths = [
            "./i2pd-gui/i2pd",     // Путь в папке проекта Xcode
            "./i2pd",              // Текущая директория
            "/Users/vade/GitHub/gui-i2pd/i2pd-gui/i2pd", // Абсолютный путь к нашему бинарнику
            "/Users/vade/GitHub/gui-i2pd/i2pd",          // Альтернативный путь
            "/usr/local/bin/i2pd", 
            "/opt/homebrew/bin/i2pd", 
            "/usr/bin/i2pd"
        ]
        
        for path in systemPaths {
            if FileManager.default.fileExists(atPath: path) {
                foundPath = path
                break
            }
        }
        
        executablePath = foundPath
        
        // Добавим лог о найденном пути для отладки
        DispatchQueue.main.async { [weak self] in
            self?.addLog(.debug, "Бинарник i2pd найден по пути: \(foundPath)")
            self?.addLog(.debug, "Проверка существования файла: \(FileManager.default.fileExists(atPath: foundPath) ? "✅ найден" : "❌ не найден")")
        }
    }
    
    func startDaemon() {
        isLoading = true
        addLog(.info, "Запуск I2P daemon...")
        
        guard FileManager.default.fileExists(atPath: executablePath) else {
            addLog(.error, "Бинарник i2pd не найден по пути: \(executablePath)")
            isLoading = false
            return
        }
        
        // Проверяем, не запущен ли уже процесс
        if isRunning {
            addLog(.warn, "I2P daemon уже запущен")
            isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.executeI2pdCommand(["--daemon"])
        }
    }
    
    func stopDaemon() {
        isLoading = true
        addLog(.info, "Остановка I2P daemon...")
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.stopDaemonProcess()
        }
    }
    
    private func stopDaemonProcess() {
        // Упрощенная и эффективная команда остановки
        let stopCommand = """
        echo "🔍 Остановка i2pd daemon..." &&
        
        # Простая и эффективная остановка всех процессов i2pd daemon
        DAEMON_PIDS=$(ps aux | awk '/i2pd.*daemon/ && !/I2P-GUI/ {print $2}') &&
        
        if [ -n "$DAEMON_PIDS" ]; then
            echo "📍 Найдены процессы i2pd daemon: $DAEMON_PIDS" &&
            for PID in $DAEMON_PIDS; do
                echo "🛑 Отправляем SIGTERM процессу $PID..." &&
                kill -TERM $PID 2>/dev/null &&
                sleep 1
            done &&
            sleep 2 &&
            
            # Проверяем какие процессы все еще работают
            REMAINING_PIDS=$(ps aux | awk '/i2pd.*daemon/ && !/I2P-GUI/ {print $2}') &&
            if [ -n "$REMAINING_PIDS" ]; then
                echo "⚠️ Используем SIGKILL для оставшихся процессов: $REMAINING_PIDS" &&
                for PID in $REMAINING_PIDS; do
                    kill -KILL $PID 2>/dev/null &&
                    echo "💥 Принудительная остановка $PID"
                done &&
                sleep 1
            fi
        else
            echo "ℹ️ Процессы i2pd daemon не найдены"
        fi &&
        
        # Финальная проверка
        FINAL_PIDS=$(ps aux | awk '/i2pd.*daemon/ && !/I2P-GUI/ {print $2}') &&
        if [ -z "$FINAL_PIDS" ]; then
            echo "✅ i2pd daemon полностью остановлен"
        else
            echo "❌ Процессы все еще работают: $FINAL_PIDS"
        fi
        """
        
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        killProcess.arguments = ["-c", stopCommand]
        
        let pipe = Pipe()
        killProcess.standardOutput = pipe
        killProcess.standardError = pipe
        
        do {
            try killProcess.run()
            killProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            DispatchQueue.main.async { [weak self] in
                let outputLines = output.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                
                if !outputLines.isEmpty {
                    for line in outputLines {
                        self?.addLog(.info, line)
                    }
                } else {
                    self?.addLog(.info, "Daemon остановлен")
                }
                
                // Принудительно устанавливаем статус как остановленный
                self?.isRunning = false
                self?.isLoading = false
                
                // Повторная проверка через несколько секунд
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.checkDaemonStatus()
                }
            }
            
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.addLog(.error, "Ошибка остановки daemon: \(error.localizedDescription)")
                self?.isLoading = false
            }
        }
    }
    
    func restartDaemon() {
        stopDaemon()
        
        // Ждем немного перед перезапуском
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.startDaemon()
        }
    }
    
    func checkStatus() {
        isLoading = true
        addLog(.info, "Проверка статуса...")
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.checkDaemonStatus()
        }
    }
    
    func clearLogs() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.addLog(.info, "Логи очищены")
        }
    }
    
    private func executeI2pdCommand(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        
        addLog(.info, "Выполняется команда: \(executablePath) \(arguments.joined(separator: " "))")
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            
            DispatchQueue.main.async { [weak self] in
                self?.i2pdProcess = process
                self?.updateStatus()
            }
            
            // Читаем вывод команды
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { [weak self] in
                    self?.addLog(.info, "Команда выполнена: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
            
            process.waitUntilExit()
            
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
            
            // Проверяем статус после выполнения команды
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.checkDaemonStatus()
            }
            
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.addLog(.error, "Ошибка выполнения команды: \(error.localizedDescription)")
                self?.isLoading = false
            }
        }
    }
    
    private func checkDaemonStatus() {
        // Проверяем, запущен ли процесс через pgrep или аналогичную команду
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        checkProcess.arguments = ["-c", "ps aux | awk '/i2pd.*daemon/ && !/I2P-GUI/ {print $2}' | wc -l"]
        
        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            DispatchQueue.main.async { [weak self] in
                let wasRunning = self?.isRunning ?? false
                self?.isRunning = !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                
                if self?.isRunning != wasRunning {
                    let status = self?.isRunning == true ? "запустился" : "остановился"
                    self?.addLog(.info, "Daemon \(status)")
                }
                
                self?.isLoading = false
                
                if self?.isRunning == true {
                    self?.startStatusMonitoring()
                } else {
                    self?.stopStatusMonitoring()
                }
            }
            
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.addLog(.error, "Ошибка проверки статуса: \(error.localizedDescription)")
                self?.isLoading = false
            }
        }
    }
    
    private func startStatusMonitoring() {
        // Обновляем статистику каждые 5 секунд
        logTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
        
        // Обновляем статистику сразу
        updateStatus()
    }
    
    private func stopStatusMonitoring() {
        logTimer?.invalidate()
        logTimer = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.uptime = "00:00:00"
            self?.peerCount = 0
        }
    }
    
    private func updateStatus() {
        // Симуляция получения статистики
        // В реальном приложении здесь должен быть запрос к веб-интерфейсу i2pd
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            // Простая симуляция времени работы
            let currentUptimeSeconds = Int(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 86400))
            let hours = currentUptimeSeconds / 3600
            let minutes = (currentUptimeSeconds % 3600) / 60
            let seconds = currentUptimeSeconds % 60
            
            self.uptime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            
            // Симуляция количества пиров
            self.peerCount = Int.random(in: 50...200)
        }
    }
    
    private func addLog(_ level: LogLevel, _ message: String) {
        DispatchQueue.main.async { [weak self] in
            let logEntry = LogEntry(level: level, message: message)
            self?.logs.append(logEntry)
            
            // Ограничиваем количество логов
            if self?.logs.count ?? 0 > 100 {
                self?.logs.removeFirst((self?.logs.count ?? 0) - 100)
            }
        }
    }
}
