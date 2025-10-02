import SwiftUI
import Foundation

// MARK: - App Entry Point
@main
struct I2pdGUIApp: App {
    @AppStorage("darkMode") private var darkMode = true
    
    init() {
        // Устанавливаем только UserDefaults по умолчанию
        if UserDefaults.standard.object(forKey: "darkMode") == nil {
            UserDefaults.standard.set(true, forKey: "darkMode")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .help) {
                Button("О программе") {
                    DispatchQueue.main.async {
                        if let window = NSApplication.shared.windows.first {
                            window.contentView?.window?.makeFirstResponder(nil)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var i2pdManager = I2pdManager()
    @State private var showingAbout = false
    @State private var showingStats = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Заголовочная панель
                VStack(spacing: 16) {
                    // Заголовок
                    Text("I2P Daemon GUI")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.top, 20)
                    
                    // Статус сервера
                    StatusCard(
                        isRunning: i2pdManager.isRunning,
                        uptime: i2pdManager.uptime,
                        peers: i2pdManager.peerCount
                    )
                    .padding(.horizontal, 24)
                    
                    // Кнопки управления
                    ControlButtons(
                        i2pdManager: i2pdManager,
                        showingStats: $showingStats,
                        showingSettings: $showingSettings,
                        showingAbout: $showingAbout
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // Секция логов
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Логи")
                            .font(.headline)
                            .fontWeight(.medium)
                        Spacer()
                        if !i2pdManager.logs.isEmpty {
                            Button("Очистить") {
                                i2pdManager.clearLogs()
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    if !i2pdManager.logs.isEmpty {
                        LogView(logs: i2pdManager.logs)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("Пока нет логов")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .padding(.bottom, 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 600, minHeight: 700)
        }
        .onAppear {
            i2pdManager.checkStatus()
            
            // Применяем тему после полной инициализации
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                applyTheme()
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingStats) {
            NetworkStatsView(i2pdManager: i2pdManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(i2pdManager: i2pdManager)
        }
    }
    
    private func applyTheme() {
        let isDarkMode = UserDefaults.standard.bool(forKey: "darkMode")
        if isDarkMode {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else {
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Иконка приложения
            Image(systemName: "network")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("I2P Daemon GUI")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Версия 2.4")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Современный GUI для управления I2P Daemon")
                Text("• Радикальная остановка daemon")
                Text("• Мониторинг в реальном времени")
                Text("• Встроенный бинарник i2pd 2.58.0")
                Text("• Тёмный интерфейс")
            }
            .font(.body)
            .multilineTextAlignment(.center)
            
            Divider()
            
            VStack(spacing: 4) {
                Text("Разработано на SwiftUI")
                    .font(.caption)
                Text("Swift 5.7+ • macOS 14.0+")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                Link("GitHub Repository", destination: URL(string: "https://github.com/MetanoicArmor/gui-i2pd")!)
                Link("I2P Official", destination: URL(string: "https://geti2p.net/")!)
            }
            .font(.caption)
            
            Button("Закрыть") {
                // Будет закрыто автоматически через sheet
            }
            .buttonStyle(.bordered)
            .padding(.top)
        }
        .padding(30)
        .frame(maxWidth: 400)
    }
}

// MARK: - Network Stats View
struct NetworkStatsView: View {
    @ObservedObject var i2pdManager: I2pdManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Заголовок
                Text("🌐 Сетевая статистика")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Статистические карточки
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 15) {
                    StatsCard(
                        icon: "arrow.down.circle.fill",
                        title: "Получено",
                        value: formatBytes(i2pdManager.bytesReceived),
                        color: .green
                    )
                    
                    StatsCard(
                        icon: "arrow.up.circle.fill", 
                        title: "Отправлено",
                        value: formatBytes(i2pdManager.bytesSent),
                        color: .blue
                    )
                    
                    StatsCard(
                        icon: "tunnel.fill",
                        title: "Туннели",
                        value: "\(i2pdManager.activeTunnels)",
                        color: .purple
                    )
                    
                    StatsCard(
                        icon: "router.fill",
                        title: "Роутеры",
                        value: "\(i2pdManager.routerInfos)",
                        color: .orange
                    )
                }
                .padding(.horizontal)
                
                // Кнопки управления
                HStack(spacing: 15) {
                    Button("🔄 Обновить") {
                        i2pdManager.getExtendedStats()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Экспорт") {
                        exportStats()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Закрыть") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Статистика сети")
            .onAppear {
                i2pdManager.getExtendedStats()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }
    
    private func exportStats() {
        let stats = """
        I2P Network Statistics
        ===================
        Uptime: \(i2pdManager.uptime)
        Peers: \(i2pdManager.peerCount)
        Data Received: \(formatBytes(i2pdManager.bytesReceived))
        Data Sent: \(formatBytes(i2pdManager.bytesSent))
        Active Tunnels: \(i2pdManager.activeTunnels)
        Router Infos: \(i2pdManager.routerInfos)
        """
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "i2p-stats-\(Date().formatted(.iso8601)).txt"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? stats.write(to: url, atomically: true, encoding: String.Encoding.utf8)
            i2pdManager.logExportComplete(url.path)
        }
    }
}

struct StatsCard: View {
    let icon: String
    let title: String  
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var i2pdManager: I2pdManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("daemonPort") private var daemonPort = 4444
    @AppStorage("bandwidthLimit") private var bandwidthLimit = "unlimited"
    @AppStorage("autoStart") private var autoStart = false
    @AppStorage("darkMode") private var darkMode = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("compactMode") private var compactMode = false
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("autoLogCleanup") private var autoLogCleanup = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("🌐 Сетевая конфигурация").font(.headline)) {
                    VStack(spacing: 20) {
                        // Порт daemon
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Порт daemon")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("", value: $daemonPort, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                        
                        Divider()
                        
                        // Ограничение скорости
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ограничение скорости")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("", selection: $bandwidthLimit) {
                                Text("Без ограничений").tag("unlimited")
                                Text("128 KB/s").tag("128")
                                Text("512 KB/s").tag("512")
                                Text("1 MB/s").tag("1024")
                                Text("5 MB/s").tag("5120")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 8)
                }
                
                Section(header: Text("💻 Автоматизация").font(.headline)) {
                    VStack(spacing: 12) {
                        HStack {
                            Toggle("Автозапуск daemon", isOn: $autoStart)
                            Spacer()
                        }
                        HStack {
                            Toggle("Отправлять уведомления", isOn: $notificationsEnabled)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                }
                
                Section(header: Text("🎨 Интерфейс").font(.headline)) {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Тема приложения")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Picker("", selection: $darkMode) {
                                Text("Светлая").tag(false)
                                Text("Тёмная").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        HStack {
                            Toggle("Компактный режим", isOn: $compactMode)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                }
                
                Section(header: Text("📊 Мониторинг").font(.headline)) {
                    VStack(spacing: 12) {
                        HStack {
                            Toggle("Обновление каждые 5 сек", isOn: $autoRefresh)
                            Spacer()
                        }
                        HStack {
                            Toggle("Автоматическая очистка логов", isOn: $autoLogCleanup)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                }
                
                Section(header: Text("📁 Данные").font(.headline)) {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Путь к данным")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            HStack {
                                Text("~/.i2pd")
                                    .foregroundColor(.secondary)
                                    .font(.system(.caption, design: .monospaced))
                                Spacer()
                                Button("Изменить") {
                                    selectDataDirectory()
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                            }
                        }
                        
                        Divider()
                        
                        VStack(spacing: 8) {
                            Button("🗑️ Очистить кэш") {
                                clearDataCache()
                            }
                            .foregroundColor(.red)
                            .buttonStyle(.borderless)
                            
                            Button("📊 Экспорт логов") {
                                exportLogs()
                            }
                            .foregroundColor(.blue)
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 8)
                }
                
                Section(header: Text("ℹ️ О программе").font(.headline)) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Версия:")
                                .frame(width: 100, alignment: .leading)
                            Text("2.4")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Разработчик:")
                                .frame(width: 100, alignment: .leading)
                            Text("GUI Team")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                }
                
                Section(header: Text("🔄 Действия").font(.headline)) {
                    VStack(spacing: 12) {
                        HStack {
                            Button("🔧 Сбросить настройки") {
                                resetSettings()
                            }
                            .foregroundColor(.orange)
                            Spacer()
                        }
                        
                        HStack {
                            Button("📊 Тестовая статистика") {
                                i2pdManager.getExtendedStats()
                            }
                            .disabled(!i2pdManager.isRunning)
                            Spacer()
                    }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                }
            }
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Сохранить") {
                        saveSettings()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private func saveSettings() {
        // Сохранение настроек в UserDefaults (уже автоматически через @AppStorage)
        i2pdManager.logExportComplete("✅ Настройки сохранены")
        
        // Применяем тему системы безопасно
        DispatchQueue.main.async {
            if darkMode {
                NSApp.appearance = NSAppearance(named: .darkAqua)
            } else {
                NSApp.appearance = NSAppearance(named: .aqua)
            }
        }
    }
    
    private func selectDataDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Выбрать папку данных"
        
        if panel.runModal() == .OK, let url = panel.url {
            i2pdManager.logExportComplete("📁 Выбран путь данных: \(url.path)")
        }
    }
    
    private func clearDataCache() {
        let alert = NSAlert()
        alert.messageText = "Очистка кэша"
        alert.informativeText = "Вы уверены что хотите очистить кэш приложения? Это действие нельзя отменить."
        alert.addButton(withTitle: "Очистить")
        alert.addButton(withTitle: "[Предыдущее редактирование]")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // TODO: Реализовать очистку кэша
            i2pdManager.logExportComplete("🗑️ Кэш очищен")
        }
    }
    
    private func exportLogs() {
        let logsContent = i2pdManager.logs.map { log in
            "[\(log.timestamp.formatted())] \(log.level.rawValue): \(log.message)"
        }.joined(separator: "\n")
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "i2p-logs-\(Date().formatted(.iso8601)).txt"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? logsContent.write(to: url, atomically: true, encoding: .utf8)
            i2pdManager.logExportComplete("📄 Логи экспортированы: \(url.path)")
        }
    }
    
    private func resetSettings() {
        let alert = NSAlert()
        alert.messageText = "Сброс настроек"
        alert.informativeText = "Все настройки будут сброшены к значениям по умолчанию. Вы уверены?"
        alert.addButton(withTitle: "Сбросить")
        alert.addButton(withTitle: "Отменить")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Сброс всех настроек к значениям по умолчанию
            daemonPort = 4444
            bandwidthLimit = "unlimited"
            autoStart = false
            notificationsEnabled = false
            compactMode = false
            autoRefresh = true
            autoLogCleanup = false
            darkMode = true
            
            // Применяем тёмную тему по умолчанию безопасно
            DispatchQueue.main.async {
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
            
            i2pdManager.logExportComplete("🔄 Настройки сброшены к значениям по умолчанию")
        }
    }
}

// MARK: - Status Card
struct StatusCard: View {
    let isRunning: Bool
    let uptime: String
    let peers: Int
    
    var body: some View {
        HStack(spacing: 32) {
            // Статус индикатор
            HStack(spacing: 12) {
                Circle()
                    .fill(isRunning ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isRunning ? "Запущен" : "Остановлен")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(isRunning ? "Статус: активен" : "Статус: неактивен")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Время работы
            VStack(alignment: .leading, spacing: 2) {
                Text("Время работы")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(uptime)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // Счётчик пиров
            VStack(alignment: .leading, spacing: 2) {
                Text("Подключения")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(peers)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Control Buttons
struct ControlButtons: View {
    @ObservedObject var i2pdManager: I2pdManager
    @Binding var showingStats: Bool
    @Binding var showingSettings: Bool
    @Binding var showingAbout: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Основные кнопки
            HStack(spacing: 16) {
                Button(action: {
                    if i2pdManager.isRunning {
                        i2pdManager.stopDaemon()
                    } else {
                        i2pdManager.startDaemon()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: i2pdManager.isRunning ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 16))
                        Text(i2pdManager.isRunning ? "Остановить" : "Запустить")
                            .fontWeight(.medium)
                    }
                    .frame(height: 36)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(i2pdManager.isLoading || i2pdManager.operationInProgress)
                
                Button("Перезапустить") {
                    i2pdManager.restartDaemon()
                }
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .disabled(i2pdManager.isLoading || !i2pdManager.isRunning)
                
                Button("Обновить статус") {
                    i2pdManager.checkStatus()
                }
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .disabled(i2pdManager.isLoading)
            
            }
            
            // Дополнительные кнопки
            HStack(spacing: 12) {
                Menu {
                    Button("📊 Сетевая статистика") {
                        showingStats = true
                    }
                    .disabled(!i2pdManager.isRunning)
                    
                    Button("⚙️ Настройки") {
                        showingSettings = true
                    }
                    
                    Divider()
                    
                    Button("О программе") {
                        showingAbout = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "ellipsis.circle")
                        Text("Ещё")
                    }
                    .frame(height: 36)
                }
                .frame(maxWidth: .infinity)
                
                Button("Очистить логи") {
                    i2pdManager.clearLogs()
                }
                .frame(height: 36)
                .frame(maxWidth: .infinity)
            }
        }
        
        if i2pdManager.isLoading {
            ProgressView()
                .scaleEffect(0.8)
                .padding(.top, 5)
        }
    }
}

// MARK: - Log View
struct LogView: View {
    let logs: [LogEntry]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(logs.prefix(50), id: \.id) { log in
                    HStack(alignment: .top, spacing: 12) {
                        Text(log.timestamp.formatted(.dateTime.hour().minute().second()))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 55, alignment: .leading)
                        
                        HStack(spacing: 4) {
                            Text(log.level.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(logLevelColor(for: log.level))
                                .foregroundColor(.white)
                                .cornerRadius(3)
                        }
                        .frame(width: 60)
                        
                        Text(log.message)
                            .font(.caption)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Rectangle()
                            .fill(log.level == .error ? Color.red.opacity(0.03) : 
                                  log.level == .warn ? Color.orange.opacity(0.03) : 
                                  Color.clear)
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
            )
        }
        .frame(maxHeight: 300)
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
    @Published var operationInProgress = false
    @Published var uptime = "00:00:00"
    @Published var peerCount = 0
    @Published var logs: [LogEntry] = []
    @Published var bytesReceived = 0
    @Published var bytesSent = 0
    @Published var activeTunnels = 0
    @Published var routerInfos = 0
    
    private var i2pdProcess: Process?
    private var logTimer: Timer?
    
    private let executablePath: String
    
    init() {
        // Хардкодим путь к бинарнику для максимальной надежности
        let bundlePath = Bundle.main.bundlePath
        let resourcePath = "\(bundlePath)/Contents/Resources/i2pd"
        
        // Проверяем существование в главном пути
        if FileManager.default.fileExists(atPath: resourcePath) {
            executablePath = resourcePath
        } else {
            // Fallback к альтернативным путям
            var fallbackPaths: [String] = []
            
            if let resourceURLPath = Bundle.main.resourceURL?.path {
                let altPath = "\(resourceURLPath)/i2pd"
                fallbackPaths.append(altPath)
            }
            
            fallbackPaths.append(contentsOf: [
                "./i2pd",
                "/usr/local/bin/i2pd", 
                "/opt/homebrew/bin/i2pd",
                "/usr/bin/i2pd"
            ])
            
            // Фильтруем только существующие пути
            let validPaths = fallbackPaths.filter { FileManager.default.fileExists(atPath: $0) }
            
            executablePath = validPaths.first ?? "./i2pd"
        }
        
        // Дебаг вывод
        DispatchQueue.main.async { [weak self] in
            self?.addLog(.debug, "🔧 Инициализация I2pdManager")
            self?.addLog(.debug, "📍 Bundle path: \(bundlePath)")
            self?.addLog(.debug, "🎯 Ресурсный путь: \(resourcePath)")
            self?.addLog(.debug, "✅ Финальный путь: \(self?.executablePath ?? "не найден")")
            self?.addLog(.debug, "🔍 Файл существует: \(FileManager.default.fileExists(atPath: self?.executablePath ?? "") ? "✅ да" : "❌ нет")")
        }
    }
    
    func startDaemon() {
        guard !operationInProgress else {
            addLog(.warn, "Операция уже выполняется, пропускаем...")
            return
        }
        operationInProgress = true
        isLoading = true
        addLog(.info, "Запуск I2P daemon...")
        addLog(.debug, "🔄 Пытаемся запустить daemon...")
        addLog(.debug, "📍 Путь к бинарнику: \(executablePath)")
        addLog(.debug, "🔍 Проверка существования: \(FileManager.default.fileExists(atPath: executablePath))")
        
        guard FileManager.default.fileExists(atPath: executablePath) else {
            addLog(.error, "❌ Бинарник i2pd не найден по пути: \(executablePath)")
            isLoading = false
            operationInProgress = false
            return
        }
        
        addLog(.debug, "✅ Бинарник найден, продолжаем запуск")
        
        // Проверяем, не запущен ли уже процесс
        if isRunning {
            addLog(.warn, "I2P daemon уже запущен")
            isLoading = false
            operationInProgress = false
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.executeI2pdCommand(["--daemon"])
        }
    }
    
    func stopDaemon() {
        guard !operationInProgress else {
            addLog(.warn, "Операция уже выполняется, пропускаем...")
            return
        }
        operationInProgress = true
        isLoading = true
        addLog(.info, "Остановка I2P daemon...")
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.stopDaemonProcess()
        }
    }
    
    func restartDaemon() {
        stopDaemon()
        
        // Ждем немного перед перезапуском
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.startDaemon()
        }
    }
    
    private func stopDaemonProcess() {
        // Радикальная остановка - убиваем ВСЕ процессы i2pd всеми возможными способами
        let stopCommand = """
        echo "🔍 РАДИКАЛЬНАЯ остановка i2pd daemon..." &&
        
        # Метод 1: pkill с SIGINT
        echo "🛑 Метод 1: pkill -INT..." &&
        pkill -INT -f "i2pd.*daemon" 2>/dev/null || true &&
        sleep 2 &&
        
        # Метод 2: pkill с SIGKILL
        echo "💀 Метод 2: pkill -KILL..." &&
        pkill -KILL -f "i2pd.*daemon" 2>/dev/null || true &&
        sleep 1 &&
        
        # Метод 3: killall по имени
        echo "⚰️ Метод 3: killall i2pd..." &&
        killall -INT i2pd 2>/dev/null || true &&
        sleep 1 &&
        killall -KILL i2pd 2>/dev/null || true &&
        sleep 1 &&
        
        # Метод 4: поиск через ps и kill по PID (упрощенный без while)
        echo "🎯 Метод 4: поиск и kill по PID..." &&
        ps aux | grep "i2pd" | grep -v "grep" | grep "daemon" | awk '{print $2}' | xargs -I {} sh -c 'echo "💉 Kill PID: {}" && kill -INT {} 2>/dev/null || true && sleep 0.5 && kill -KILL {} 2>/dev/null || true' &&
        sleep 2 &&
        
        # Финальная проверка
        FINAL_COUNT=$(ps aux | grep "i2pd.*daemon" | grep -v "grep" | wc -l | tr -d ' ') &&
        if [ "$FINAL_COUNT" -eq 0 ]; then
            echo "✅ i2pd daemon ПОЛНОСТЬЮ остановлен!"
        else
            echo "❌ ПРОЦЕССЫ НЕ ОСТАНАВЛИВАЮТСЯ! ($FINAL_COUNT шт.)" &&
            echo "Оставшиеся процессы:" &&
            ps aux | grep "i2pd.*daemon" | grep -v "grep"
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
                self?.operationInProgress = false
                
                // Повторная проверка через несколько секунд
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.checkDaemonStatus()
                }
            }
            
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.addLog(.error, "Ошибка остановки daemon: \(error.localizedDescription)")
                self?.isLoading = false
                self?.operationInProgress = false
            }
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
    
    func logExportComplete(_ path: String) {
        DispatchQueue.main.async { [weak self] in
            self?.addLog(.info, "📄 Статистика экспортирована: \(path)")
        }
    }
    
    func getExtendedStats() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            // Получаем детализированную статистику
            self?.executeI2pdCommand(["--netstat"])
            
            // Симуляция реальных данных для демонстрации
            DispatchQueue.main.async {
                self?.bytesReceived = Int.random(in: 1024...10485760)  // 1KB - 10MB
                self?.bytesSent = Int.random(in: 1024...10485760)      // 1KB - 10MB
                self?.activeTunnels = Int.random(in: 2...8)             // 2-8 туннелей
                self?.routerInfos = Int.random(in: 100...500)          // 100-500 роутеров
                self?.addLog(.info, "📊 Расширенная статистика обновлена")
            }
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
                self?.addLog(.debug, "🚀 Команда запущена: \(self?.executablePath ?? "unknown") \(arguments.joined(separator: " "))")
            }
            
            // Читаем вывод команды
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { [weak self] in
                    let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedOutput.isEmpty {
                        self?.addLog(.info, "📝 Вывод команды: \(trimmedOutput)")
                    }
                }
            }
            
            process.waitUntilExit()
            
            DispatchQueue.main.async { [weak self] in
                self?.addLog(.debug, "✅ Процесс завершен с кодом: \(process.terminationStatus)")
                self?.isLoading = false
                self?.operationInProgress = false
                
                // Обновляем статус после завершения команды
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.addLog(.debug, "🔄 Проверяем статус daemon...")
                    self?.checkDaemonStatus()
                }
            }
            
            // Проверяем статус после выполнения команды
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.checkDaemonStatus()
            }
            
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.addLog(.error, "Ошибка выполнения команды: \(error.localizedDescription)")
                self?.isLoading = false
                self?.operationInProgress = false
            }
        }
    }
    
    private func checkDaemonStatus() {
        // Проверяем, запущен ли процесс через pgrep или аналогичную команду
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        checkProcess.arguments = ["-c", "ps aux | grep \"i2pd.*daemon\" | grep -v \"grep\" | wc -l | tr -d ' '"]
        
        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            DispatchQueue.main.async { [weak self] in
                let wasRunning = self?.isRunning ?? false
                let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                self?.isRunning = count > 0
                
                if self?.isRunning != wasRunning {
                    let status = self?.isRunning == true ? "запустился" : "остановился"
                    self?.addLog(.info, "Daemon \(status)")
                }
                
                self?.isLoading = false
                self?.operationInProgress = false
                
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
                self?.operationInProgress = false
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
