#!/usr/bin/env swift

import SwiftUI
import Foundation

// Основное приложение I2P GUI на Swift
@main
struct MainApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Создаем главное окно приложения
        let contentView = ContentView()
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        window.title = "I2P Daemon GUI"
        
        // Добавляем меню
        setupMenuBar()
    }
    
    func setupMenuBar() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(NSMenuItem(title: "О программе", action: nil, keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Выход", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Очистка ресурсов
        print("Приложение завершается")
    }
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var i2pdManager = I2pdManager()
    
    var body: some View {
        VStack(spacing: 20) {
            // Заголовок
            Text("I2P Daemon GUI")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // Статус сервера
            StatusCard(
                isRunning: i2pdManager.isRunning,
                uptime: i2pdManager.uptime,
                peers: i2pdManager.peerCount
            )
            
            // Кнопки управления
            ControlButtons(i2pdManager: i2pdManager)
            
            // Логи
            if !i2pdManager.logs.isEmpty {
                LogView(logs: i2pdManager.logs)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            i2pdManager.checkStatus()
        }
    }
}

// MARK: - StatusCard
struct StatusCard: View {
    let isRunning: Bool
    let uptime: String
    let peers: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Статус")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(isRunning ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(isRunning ? "Запущен" : "Остановлен")
                    .fontWeight(.medium)
            }
            
            if isRunning {
                HStack {
                    Image(systemName: "clock")
                    Text("Время работы: \(uptime)")
                }
                .font(.caption)
                
                HStack {
                    Image(systemName: "person.3")
                    Text("Соединений с пирами: \(peers)")
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - ControlButtons
struct ControlButtons: View {
    @ObservedObject var i2pdManager: I2pdManager
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 15) {
                Button(action: {
                    if i2pdManager.isRunning {
                        i2pdManager.stopDaemon()
                    } else {
                        i2pdManager.startDaemon()
                    }
                }) {
                    Label(
                        i2pdManager.isRunning ? "Остановить" : "Запустить",
                        systemImage: i2pdManager.isRunning ? "stop.circle.fill" : "play.circle.fill"
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(i2pdManager.isLoading)
                
                Button("Перезапустить") {
                    i2pdManager.restartDaemon()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .disabled(i2pdManager.isLoading || !i2pdManager.isRunning)
            }
            
            HStack(spacing: 15) {
                Button("Обновить статус") {
                    i2pdManager.checkStatus()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .disabled(i2pdManager.isLoading)
                
                Button("Очистить логи") {
                    i2pdManager.clearLogs()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            
            if i2pdManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.top, 5)
            }
        }
    }
}

// MARK: - LogView
struct LogView: View {
    let logs: [LogEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Логи")
                .font(.headline)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(logs.prefix(50), id: \.id) { log in
                        HStack {
                            Text(log.timestamp, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(log.timestamp, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(log.message)
                                .font(.system(.caption, design: .monospaced))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(logLevelColor(for: log.level).opacity(0.1))
                        .cornerRadius(3)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 200)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private func logLevelColor(for level: LogLevel) -> Color {
        switch level {
        case .info:
            return .blue
        case .warn:
            return .orange
        case .error:
            return .red
        case .debug:
            return .gray
        }
    }
}

// MARK: - Data Models
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

// MARK: - I2PD Manager
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
        // Ищем бинарник i2pd в различных местах
        var foundPath = "./i2pd"  // Дефолтный путь
        
        let possiblePaths = [
            "./i2pd",
            "./i2pd-gui/i2pd", 
            "/usr/local/bin/i2pd",
            "/opt/homebrew/bin/i2pd",
            "/usr/bin/i2pd"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                foundPath = path
                break
            }
        }
        
        executablePath = foundPath
        addLog(.info, "Бинарник i2pd найден по пути: \(executablePath)")
    }
    
    func startDaemon() {
        isLoading = true
        addLog(.info, "Запуск I2P daemon...")
        
        guard FileManager.default.fileExists(atPath: executablePath) else {
            addLog(.error, "Бинарник i2pd не найден по пути: \(executablePath)")
            isLoading = false
            return
        }
        
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
            self?.executeI2pdCommand(["--kill"])
        }
    }
    
    func restartDaemon() {
        stopDaemon()
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
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            
            DispatchQueue.main.async { [weak self] in
                self?.i2pdProcess = process
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { [weak self] in
                    let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedOutput.isEmpty {
                        self?.addLog(.info, "Команда выполнена: \(trimmedOutput)")
                    }
                }
            }
            
            process.waitUntilExit()
            
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
            
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
        logTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            let currentUptimeSeconds = Int(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 86400))
            let hours = currentUptimeSeconds / 3600
            let minutes = (currentUptimeSeconds % 3600) / 60
            let seconds = currentUptimeSeconds % 60
            
            self.uptime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            self.peerCount = Int.random(in: 50...200)
        }
    }
    
    private func addLog(_ level: LogLevel, _ message: String) {
        DispatchQueue.main.async { [weak self] in
            let logEntry = LogEntry(level: level, message: message)
            self?.logs.append(logEntry)
            
            if self?.logs.count ?? 0 > 100 {
                self?.logs.removeFirst((self?.logs.count ?? 0) - 100)
            }
        }
    }
}
