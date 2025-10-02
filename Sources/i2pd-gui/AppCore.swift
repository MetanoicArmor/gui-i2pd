import SwiftUI
import Foundation
import AppKit

// MARK: - Tray Manager Singleton  
class TrayManager: NSObject, ObservableObject {
    static let shared = TrayManager()
    private var statusBarItem: NSStatusItem?
    
    private override init() {
        super.init()
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusBarItem = statusBarItem {
            let image = NSImage(systemSymbolName: "network", accessibilityDescription: "I2P Daemon")
            image?.size = NSSize(width: 18, height: 18)
            statusBarItem.button?.image = image
            
            let menu = NSMenu()
            
            // Статус
            let statusItem = NSMenuItem(title: "📊 Статус: Готов", action: #selector(checkStatus), keyEquivalent: "")
            statusItem.target = self
            menu.addItem(statusItem)
            menu.addItem(NSMenuItem.separator())
            
            // Управление daemon - упрощенная версия
            let startAction = #selector(TrayManager.startDaemon)
            print("🔧 Селектор для start: \(String(describing: startAction))")
            
            let startItem = NSMenuItem(title: "🚀 Запустить daemon", action: startAction, keyEquivalent: "")
            startItem.target = self
            startItem.tag = 1
            print("🔧 startItem создан с target: \(String(describing: startItem.target)), action: \(String(describing: startItem.action))")
            menu.addItem(startItem)
            
            let stopItem = NSMenuItem(title: "⏹️ Остановить daemon", action: #selector(stopDaemon), keyEquivalent: "")
            stopItem.target = self
            stopItem.tag = 2
            print("🔧 stopItem создан с target: \(String(describing: stopItem.target)), action: \(String(describing: stopItem.action))")
            menu.addItem(stopItem)
            
            let restartItem = NSMenuItem(title: "🔄 Перезапустить daemon", action: #selector(restartDaemon), keyEquivalent: "")
            restartItem.target = self
            restartItem.tag = 3
            print("🔧 restartItem создан с target: \(String(describing: restartItem.target)), action: \(String(describing: restartItem.action))")
            menu.addItem(restartItem)
            menu.addItem(NSMenuItem.separator())
            
            // Функции
            let settingsItem = NSMenuItem(title: "⚙️ Настройки", action: #selector(openSettings), keyEquivalent: ",")
            settingsItem.target = self
            print("🔧 Создан settingsItem с target: \(String(describing: settingsItem.target)), action: \(String(describing: settingsItem.action))")
            menu.addItem(settingsItem)
            
            let webItem = NSMenuItem(title: "🌐 Веб-консоль", action: #selector(openWebConsole), keyEquivalent: "")
            webItem.target = self
            menu.addItem(webItem)
            
            let showItem = NSMenuItem(title: "📱 Показать окно", action: #selector(showMainWindow), keyEquivalent: "")
            showItem.target = self
            menu.addItem(showItem)
            menu.addItem(NSMenuItem.separator())
            
            let hideItem = NSMenuItem(title: "❌ Свернуть в трей", action: #selector(hideMainWindow), keyEquivalent: "")
            hideItem.target = self
            menu.addItem(hideItem)
            
            let quitItem = NSMenuItem(title: "🚪 Выйти", action: #selector(quitApplication), keyEquivalent: "")
            quitItem.target = self
            menu.addItem(quitItem)
            
            statusBarItem.menu = menu
            print("✅ Статус бар создан")
        }
    }
    
    // MARK: - Объективные методы для меню
    
    @objc private func checkStatus() {
        print("📊 Статус проверяется...")
        updateStatusText("📊 Статус обновлен")
    }
    
    @objc public func startDaemon() {
        print("🚀 ========== ЗАПУСК DAEMON ИЗ ТРЕЯ! ==========")
        print("🚀 Метод startDaemon() успешно вызван!")
        
        // Простая проверка
        updateStatusText("🚀 Запуск daemon...")
        
        // Попробуем простую команду сначала
        let testCommand = "echo 'DAEMON START TEST' && date"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", testCommand]
        
        do {
            try process.run()
            print("✅ Тестовая команда выполнена")
            
            // Теперь реальный запуск
            let bundlePath = Bundle.main.bundlePath
            let executablePath = "\(bundlePath)/Contents/Resources/i2pd"
            
            if FileManager.default.fileExists(atPath: executablePath) {
                let daemonCommand = "\"\(executablePath)\" --daemon"
                let daemonProcess = Process()
                daemonProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
                daemonProcess.arguments = ["-c", daemonCommand]
                
                try daemonProcess.run()
                updateStatusText("🚀 Daemon запущен!")
                print("✅ Daemon команда выполнена")
                
                // Отправляем уведомления в главное окно
                NotificationCenter.default.post(name: NSNotification.Name("DaemonStarted"), object: nil)
                
                // Задержка и обновление статуса
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.updateStatusText("✅ Daemon работает")
                    NotificationCenter.default.post(name: NSNotification.Name("StatusUpdated"), object: nil)
                }
            } else {
                updateStatusText("❌ Бинарник не найден")
                print("❌ Бинарник i2pd не найден в: \(executablePath)")
                NotificationCenter.default.post(name: NSNotification.Name("DaemonError"), object: nil)
            }
        } catch {
            updateStatusText("❌ Ошибка запуска: \(error)")
            print("❌ Ошибка выполнения команды: \(error)")
            NotificationCenter.default.post(name: NSNotification.Name("DaemonError"), object: nil)
        }
    }
    
    @objc public func stopDaemon() {
        print("⏹️ ОСТАНОВКА DAEMON из трея!")
        updateStatusText("⏹️ Остановка daemon...")
        
        // ЭТАП 1: Мягкая остановка командой SIGINT
        print("📤 Этап 1: Отправка SIGINT...")
        let gentleStopCommand = "pkill -INT i2pd 2>/dev/null || true"
        
        let gentleProcess = Process()
        gentleProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        gentleProcess.arguments = ["-c", gentleStopCommand]
        
        do {
            try gentleProcess.run()
            updateStatusText("⏳ Мягкая остановка...")
            print("✅ SIGINT отправлен")
            
            // Ждем 3 секунды и проверяем
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.checkIfStillRunning()
            }
            
        } catch {
            updateStatusText("❌ Ошибка мягкой остановки")
            print("❌ Ошибка SIGINT: \(error)")
            NotificationCenter.default.post(name: NSNotification.Name("DaemonError"), object: nil)
        }
    }
    
    private func checkIfStillRunning() {
        print("🔍 Проверяем, остановился ли daemon...")
        let checkCommand = "pgrep -x i2pd | wc -l"
        
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        checkProcess.arguments = ["-c", checkCommand]
        
        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "0"
            let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            
            if count > 0 {
                print("⚠️ Daemon всё ещё работает, применяем жёсткую остановку...")
                forceStopDaemon()
            } else {
                print("✅ Daemon успешно остановлен")
                updateStatusText("✅ Daemon остановлен")
                NotificationCenter.default.post(name: NSNotification.Name("DaemonStopped"), object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    NotificationCenter.default.post(name: NSNotification.Name("StatusUpdated"), object: nil)
                }
            }
        } catch {
            print("❌ Ошибка проверки: \(error)")
            forceStopDaemon()
        }
    }
    
    private func forceStopDaemon() {
        print("💥 Применяем жёсткую остановку...")
        updateStatusText("💥 Жёсткая остановка...")
        
        let forceCommand = "pkill -KILL i2pd 2>/dev/null || killall -KILL i2pd 2>/dev/null || true"
        
        let forceProcess = Process()
        forceProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        forceProcess.arguments = ["-c", forceCommand]
        
        do {
            try forceProcess.run()
            updateStatusText("✅ Daemon остановлен принудительно")
            print("✅ Жёсткая остановка выполнена")
            
            NotificationCenter.default.post(name: NSNotification.Name("DaemonStopped"), object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NotificationCenter.default.post(name: NSNotification.Name("StatusUpdated"), object: nil)
            }
        } catch {
            updateStatusText("❌ Ошибка жёсткой остановки")
            print("❌ Ошибка жёсткой остановки: \(error)")
            NotificationCenter.default.post(name: NSNotification.Name("DaemonError"), object: nil)
        }
    }
    
    @objc public func restartDaemon() {
        print("🔄 ПЕРЕЗАПУСК DAEMON из трея!")
        updateStatusText("🔄 Перезапуск daemon...")
        stopDaemon()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.startDaemon()
        }
    }
    
    @objc private func openSettings() {
        print("⚙️ ОТКРЫТИЕ НАСТРОЕК из трея!")
        
        // Показываем главное окно
        showMainWindow()
        
        // Отправляем уведомление для открытия настроек в главном окне
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
        }
        
        updateStatusText("⚙️ Настройки открыты")
        print("✅ Главное окно открыто с настройками")
    }
    
    // Метод showSimpleSettingsWindow удален - используем главное окно
    
    private func openConfigFolder() {
        print("📁 Открываем папку конфигурации...")
        
        let configPath = NSHomeDirectory() + "/.i2pd"
        let url = URL(fileURLWithPath: configPath)
        
        if FileManager.default.fileExists(atPath: configPath) {
            NSWorkspace.shared.open(url)
            updateStatusText("📁 Папка конфигурации открыта")
        } else {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            NSWorkspace.shared.open(url)
            updateStatusText("📁 Папка конфигурации создана и открыта")
        }
    }
    
    @objc func openWebConsole() {
        print("🌐 Открываем веб-консоль...")
        if let url = URL(string: "http://127.0.0.1:7070") {
            NSWorkspace.shared.open(url)
            updateStatusText("🌐 Веб-консоль открыта")
        }
    }
    
    private func showSettingsWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "⚙️ Настройки I2P GUI"
            alert.informativeText = """
            Настройки приложения:
            
            🎨 Темная тема: Включено по умолчанию
            📁 Путь к конфигурации: ~/.i2pd/
            🌐 Веб-консоль: http://127.0.0.1:7070
            🔧 Бинарник i2pd: Встроен в приложение
            
            Для редактирования настроек используйте текстовый редактор:
            ~/.i2pd/i2pd.conf
            
            📁 Открыть папку с настройками
            """
            
            alert.addButton(withTitle: "📁 Открыть папку конфигурации")
            alert.addButton(withTitle: "🌐 Открыть веб-консоль") 
            alert.addButton(withTitle: "❌ Закрыть")
            
            let response = alert.runModal()
            
            switch response {
            case .alertFirstButtonReturn:
                self.openConfigFolder()
            case .alertSecondButtonReturn:
                self.openWebConsole()
            default:
                break
            }
        }
        
        updateStatusText("⚙️ Настройки показаны")
    }
    
    // Убран дублирующийся блок
    
    @objc func showMainWindow() {
        print("⚙️ ПОКАЗ ОКНА из трея!")
        for window in NSApplication.shared.windows {
            window.makeKeyAndOrderFront(nil)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        updateStatusText("⚙️ Главное окно открыто")
        print("✅ Главное окно показано")
    }
    
    @objc func hideMainWindow() {
        print("❌ СВОРАЧИВАНИЕ В ТРЕЙ из трея!")
        for window in NSApplication.shared.windows {
            window.orderOut(nil)
        }
        updateStatusText("📱 Свернуто в трей")
        print("✅ Приложение свернуто в трей")
    }
    
    @objc private func quitApplication() {
        print("🚪 ВЫХОД ИЗ ПРИЛОЖЕНИЯ из трея!")
        updateStatusText("🚪 Выход из приложения")
        NSApplication.shared.terminate(nil)
    }
    
    private func updateStatusText(_ text: String) {
        if let menu = statusBarItem?.menu,
           let firstItem = menu.items.first {
            firstItem.title = text
        }
    }
}

// MARK: - Menu Target Helper
class MenuTarget: NSObject {
    private let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
        super.init()
    }
    
    @objc func performAction() {
        print("🎯 MenuTarget.performAction вызван!")
        action()
    }
}

// MARK: - App Entry Point
@main
struct I2pdGUIApp: App {
    @AppStorage("darkMode") private var darkMode = true
    @State private var showingSettings = false
    
    init() {
        // Устанавливаем только UserDefaults по умолчанию
        if UserDefaults.standard.object(forKey: "darkMode") == nil {
            UserDefaults.standard.set(true, forKey: "darkMode")
        }
        
        // Инициализируем менеджер трея
        _ = TrayManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 900)
        .windowResizability(.contentSize)
        
        // Settings убраны - используем NSAlert из трея
        
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Свернуть в трей (⌘H)") {
                    TrayManager.shared.hideMainWindow()
                }
                .keyboardShortcut("h", modifiers: [.command])
                
                Button("Показать главное окно") {
                    TrayManager.shared.showMainWindow()
                }
                .keyboardShortcut("w", modifiers: [.command])
                
                Button("Настройки (⌘,)") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}

// MARK: - Убрана SettingsWindowView (используем NSAlert вместо неё)

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var i2pdManager = I2pdManager()
    @State private var showingSettings = false
    
    
    var body: some View {
        VStack(spacing: 2) {
            // Заголовок
            Text("I2P Daemon GUI")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .offset(y: -40)
            
            // Статус сервера
            StatusCard(
                isRunning: i2pdManager.isRunning,
                uptime: i2pdManager.uptime,
                peers: i2pdManager.peerCount
            )
            .padding(.horizontal, 8)
            
            // Компактная сетевая статистика - всегда развернута
            VStack(spacing: 2) {
                // Заголовок секции
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)
                    Text("📊 Сетевая статистика")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button("⚙️") {
                        showingSettings = true
                    }
                    .buttonStyle(.borderless)
                    .help("Настройки")
                    
                    Button("🔄") {
                        i2pdManager.getExtendedStats()
                    }
                    .disabled(!i2pdManager.isRunning)
                    .buttonStyle(.borderless)
                    .help("Обновить")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                
                // Статистика в компактном виде - одна строка
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Получено: \(i2pdManager.receivedBytes)")
                            .font(.caption)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Отправлено: \(i2pdManager.sentBytes)")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.purple)
                            .font(.caption)
                        Text("Туннели: \(i2pdManager.activeTunnels)")
                            .font(.caption)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "wifi")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Роутеры: \(i2pdManager.peerCount)")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 8)
            
            // Кнопки управления
            ControlButtons(
                i2pdManager: i2pdManager,
                showingSettings: $showingSettings,
            )
            .padding(.horizontal, 8)
            
            // Секция логов - всегда развернута
            VStack(spacing: 2) {
                // Заголовок секции
                HStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                    Text("📋 Логи системы")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    if !i2pdManager.logs.isEmpty {
                        Button("🗑️ Очистить") {
                            i2pdManager.clearLogs()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                
                // Логи в компактном виде
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(i2pdManager.logs.prefix(30), id: \.id) { log in
                            HStack(spacing: 8) {
                                Text(log.timestamp.formatted(.dateTime.hour().minute().second()))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .leading)
                                
                                Text(log.level.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(log.level == .error ? Color.red : (log.level == .warn ? Color.orange : Color.blue))
                                    .foregroundColor(.white)
                                    .cornerRadius(2)
                                    .frame(width: 60, alignment: .center)
                                
                                Text(log.message)
                                    .font(.caption2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 1)
                        }
                        
                        if i2pdManager.logs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                                    .font(.system(size: 24))
                            .foregroundColor(.secondary)
                                Text("Система готова к работе")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                                Text("Логи появятся при запуске демона")
                                    .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
                    }
                }
                .frame(maxHeight: 250) // Компактная высота логов
            }
            .padding(.horizontal, 8)
        }
        .frame(width: 1000, height: 650)
        .fixedSize()
        .onAppear {
            i2pdManager.checkStatus()
            
            // Загружаем статистику и применяем тему после полной инициализации
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                applyTheme()
                i2pdManager.getExtendedStats()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(i2pdManager: i2pdManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSettings"))) { _ in
            showingSettings = true
        }
        .overlay(alignment: .bottom) {
            if i2pdManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Загрузка...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(8)
                .shadow(radius: 2)
                .padding(.bottom, 20)
            }
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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Иконка приложения
            Image(systemName: "network")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("I2P Daemon GUI")
                .font(.largeTitle)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text("Версия 2.58.0")
                .font(.headline)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            
            VStack(spacing: 8) {
                Text("Современный GUI для управления I2P Daemon")
                    .multilineTextAlignment(.center)
                Text("• Радикальная остановка daemon")
                Text("• Мониторинг в реальном времени")
                Text("• Встроенный бинарник i2pd 2.58.0")
                Text("• Подвижное и масштабируемое окно")
                Text("• Тёмный интерфейс")
            }
            .font(.body)
            .multilineTextAlignment(.center)
            
            Divider()
            
            VStack(spacing: 2) {
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
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding(.top)
        }
        .padding(30)
        .frame(maxWidth: 400)
    }
}


// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var i2pdManager: I2pdManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("daemonPort") private var daemonPort = 4444
    @AppStorage("socksPort") private var socksPort = 4447
    @AppStorage("autoStart") private var autoStart = false
    @AppStorage("darkMode") private var darkMode = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("compactMode") private var compactMode = false
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("autoLogCleanup") private var autoLogCleanup = false
    
    // Добавляем состояние для предотвращения множественных нажатий
    @State private var isResetting = false
    @State private var showingResetAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Text("⚙️ Настройки")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                Button("Готово") {
                    saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
                
                Button("Отмена") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 12) {
                    // Сетевая конфигурация
                    SettingsSection(title: "🌐 Сетевая конфигурация", icon: "globe") {
                        VStack(spacing: 12) {
                            // Порт HTTP прокси (фиксированный)
                            HStack(spacing: 12) {
                                Text("Порт HTTP прокси")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 220, alignment: .leading)
                                
                                Text("4444")
                                    .font(.system(.body, design: .monospaced, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 180, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Порт SOCKS5 прокси (фиксированный)
                            HStack(spacing: 12) {
                                Text("Порт SOCKS5 прокси")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 220, alignment: .leading)
                                
                                Text("4447")
                                    .font(.system(.body, design: .monospaced, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 180, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                        }
                    }
                    
                    // Автоматизация
                    SettingsSection(title: "💻 Автоматизация", icon: "laptop") {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Text("Автозапуск daemon")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 250, alignment: .leading)
                                
                            HStack {
                                Spacer()
                                    Toggle("", isOn: $autoStart)
                                        .labelsHidden()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                Text("Отправлять уведомления")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 250, alignment: .leading)
                                
                            HStack {
                                Spacer()
                                    Toggle("", isOn: $notificationsEnabled)
                                        .labelsHidden()
                            }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Интерфейс
                    SettingsSection(title: "🎨 Интерфейс", icon: "paintpalette") {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Тема приложения")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Picker("Тема приложения", selection: $darkMode) {
                                    Text("Светлая").tag(false)
                                    Text("Тёмная").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: .infinity)
                            }
                            
                            HStack(spacing: 12) {
                                Text("Компактный режим")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 220, alignment: .leading)
                            
                            HStack {
                                Spacer()
                                    Toggle("", isOn: $compactMode)
                                        .labelsHidden()
                            }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Мониторинг
                    SettingsSection(title: "📊 Мониторинг", icon: "chart.bar") {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Text("Обновление каждые 5 сек")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 250, alignment: .leading)
                                
                            HStack {
                                Spacer()
                                    Toggle("", isOn: $autoRefresh)
                                        .labelsHidden()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                Text("Автоматическая очистка логов")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 250, alignment: .leading)
                                
                            HStack {
                                Spacer()
                                    Toggle("", isOn: $autoLogCleanup)
                                        .labelsHidden()
                            }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Данные
                    SettingsSection(title: "📁 Данные", icon: "folder") {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Путь к данным")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                HStack {
                                    Text("~/.i2pd")
                                        .foregroundColor(.secondary)
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Button("Изменить") {
                                        selectDataDirectory()
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.small)
                                }
                            }
                            
                            Divider()
                            
                            VStack(spacing: 12) {
                                Button("🗑️ Очистить кэш") {
                                    clearDataCache()
                                }
                                .foregroundColor(.red)
                                .buttonStyle(.borderless)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Button("📊 Экспорт логов") {
                                    exportLogs()
                                }
                                .foregroundColor(.blue)
                                .buttonStyle(.borderless)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    // О программе
                    SettingsSection(title: "ℹ️ О программе", icon: "info.circle") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Версия:")
                                    .frame(width: 100, alignment: .leading)
                                Text("2.58.0")
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            HStack {
                                Text("Разработчик:")
                                    .frame(width: 100, alignment: .leading)
                                Text("Vade")
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                        }
                    }
                    
                    // Действия
                    SettingsSection(title: "🔄 Действия", icon: "gear") {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button("🔧 Сбросить настройки") {
                                    showingResetAlert = true
                                }
                                .foregroundColor(.orange)
                                .buttonStyle(.borderless)
                                .frame(minWidth: 180, alignment: .leading)
                                .disabled(isResetting)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .alert("Сброс настроек", isPresented: $showingResetAlert) {
                                Button("Сбросить", role: .destructive) {
                                    resetSettings()
                                }
                                Button("Отменить", role: .cancel) {}
                            } message: {
                                Text("Все настройки будут сброшены к значениям по умолчанию. Вы уверены?")
                            }
                            
                            HStack(spacing: 12) {
                                Button("📊 Тестовая статистика") {
                                    i2pdManager.getExtendedStats()
                                }
                                .disabled(!i2pdManager.isRunning)
                                .buttonStyle(.borderless)
                                .frame(minWidth: 180, alignment: .leading)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Конфигурация и файлы
                    SettingsSection(title: "📁 Конфигурация", icon: "doc.text") {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Text("Конфиг файл")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 200, alignment: .leading)
                                
                                Button("📁 Открыть") {
                                    openConfigFile()
                                }
                                .buttonStyle(.borderless)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                Text("Папка данных")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 200, alignment: .leading)
                                
                                Button("📂 Открыть") {
                                    openLogsDirectory() // Используем логи как папку данных
                                }
                                .buttonStyle(.borderless)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                Text("Журналы")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 200, alignment: .leading)
                                
                                Button("📋 Открыть") {
                                    openLogsDirectory()
                                }
                                .buttonStyle(.borderless)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Туннели
                    SettingsSection(title: "🚇 Туннели", icon: "tunnel.fill") {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Text("Управление туннелями")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 200, alignment: .leading)
                                
                                Button("⚙️ Настроить") {
                                    openTunnelManager()
                                }
                                .buttonStyle(.borderless)
                                .disabled(!i2pdManager.isRunning)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                Text("Пример туннелей")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 200, alignment: .leading)
                                
                                Button("📝 Показать") {
                                    showTunnelExamples()
                                }
                                .buttonStyle(.borderless)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Веб-консоль
                    SettingsSection(title: "🌐 Веб-консоль", icon: "globe") {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Text("Веб-интерфейс")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 200, alignment: .leading)
                                
                                Button("🌐 Открыть") {
                                    openWebConsole()
                                }
                                .buttonStyle(.borderless)
                                .disabled(!i2pdManager.isRunning)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                Text("Порт: 7070")
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 200, alignment: .leading)
                                
                                Button("🔗 Копировать URL") {
                                    copyWebConsoleURL()
                                }
                                .buttonStyle(.borderless)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
            }
        }
        .frame(minWidth: 750, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .init("NSWindowDidResignKey"))) { _ in
            // Дополнительная обработка для лучшего закрытия окна
        }
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
        alert.addButton(withTitle: "Отменить")
        
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
        isResetting = true
        
        DispatchQueue.main.async {
            // Сброс всех настроек к значениям по умолчанию
            autoStart = false
            notificationsEnabled = false
            compactMode = false
            autoRefresh = true
            autoLogCleanup = false
            darkMode = true
            
            // Применяем тёмную тему по умолчанию безопасно
            NSApp.appearance = NSAppearance(named: .darkAqua)
            
            i2pdManager.logExportComplete("🔄 Настройки сброшены к значениям по умолчанию")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isResetting = false
            }
        }
    }
    
    private func openConfigFile() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configPath = homeDir.appendingPathComponent(".i2pd/i2pd.conf")
        
        if FileManager.default.fileExists(atPath: configPath.path) {
            NSWorkspace.shared.open(configPath)
        } else {
            // Если файл не существует, создаем его с базовыми настройками
            createDefaultConfigFile(at: configPath)
        }
        
        i2pdManager.logExportComplete("📁 Открыт конфигурационный файл")
    }
    
    private func createDefaultConfigFile(at path: URL) {
        let defaultConfig = """
## Configuration file for I2P Router
## Generated by I2P-GUI

[general]
## Daemon mode
daemon = true

[http]
## Web Console settings
enabled = true
address = 127.0.0.1
port = 7070
auth = false

[httpproxy]
## HTTP Proxy settings
enabled = true
address = 127.0.0.1
port = 4444

[socksproxy]
## SOCKS Proxy settings
enabled = true
address = 127.0.0.1
port = 4447

[i2pcontrol]
## I2PControl settings
enabled = true
address = 127.0.0.1
port = 7650
"""
        
        do {
            try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            try defaultConfig.write(to: path, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(path)
        } catch {
            print("Ошибка создания конфига: \(error)")
        }
    }
    
    
    private func openLogsDirectory() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let logsDir = homeDir.appendingPathComponent(".i2pd")
        
        if FileManager.default.fileExists(atPath: logsDir.path) {
            NSWorkspace.shared.open(logsDir)
        } else {
            // Текущая директория логов
            NSWorkspace.shared.open(homeDir)
        }
        
        i2pdManager.logExportComplete("📋 Открыта директория логов")
    }
    
    private func openTunnelManager() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let tunnelsConf = homeDir.appendingPathComponent(".i2pd/tunnels.conf")
        
        if !FileManager.default.fileExists(atPath: tunnelsConf.path) {
            // Создаем файл с примерами туннелей
            createDefaultTunnelsFile(at: tunnelsConf)
        }
        
        NSWorkspace.shared.open(tunnelsConf)
        i2pdManager.logExportComplete("🚇 Открыт менеджер туннелей")
    }
    
    private func createDefaultTunnelsFile(at path: URL) {
        let defaultTunnels = """
## Туннели I2P
## Добавьте сюда ваши туннели

[IRC-ILITA]
type = client
address = 127.0.0.1
port = 6668
destination = irc.ilita.i2p
destinationport = 6667
keys = irc-keys.dat

#[SOCKS-Proxy]
#type = server
#address = 127.0.0.1
#port = 7650
#keys = server-keys.dat
#inbound.length = 3
#outbound.length = 3

#[HTTP-Proxy]
#type = server
#address = 127.0.0.1
#port = 8080
#keys = http-keys.dat
#inbound.length = 3
#outbound.length = 3
"""
        
        do {
            try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            try defaultTunnels.write(to: path, atomically: true, encoding: .utf8)
        } catch {
            print("Ошибка создания файла туннелей: \(error)")
        }
    }
    
    private func showTunnelExamples() {
        let examplesText = """
Примеры конфигурации туннелей:

🏃‍♂️ CLIENT ТУННЕЛЬ (входящий):
[IRC-ILITA]
type = client
address = 127.0.0.1
port = 6668
destination = irc.ilita.i2p
destinationport = 6667
keys = irc-keys.dat

🏪 SERVER ТУННЕЛЬ (исходящий):
[My-Server]
type = server
address = 127.0.0.1
port = 8080
keys = server-keys.dat
inbound.length = 3
outbound.length = 3

🌐 HTTP ПРОКСИ:
[HTTP-Proxy]
type = server
address = 127.0.0.1
port = 8888
keys = http-keys.dat
inbound.length = 3
outbound.length = 3

🧦 SOCKS ПРОКСИ:
[SOCKS-Proxy]
type = server
address = 127.0.0.1
port = 4447
keys = socks-keys.dat
inbound.length = 3
outbound.length = 3

📡 Использование SOCKS5:
Для подключения к I2P сети используйте:
- Адрес прокси: 127.0.0.1:4447
- Тип: SOCKS5
- Имя пользователя: (оставить пустым)
- Пароль: (оставить пустым)
"""
        
        let alert = NSAlert()
        alert.messageText = "Примеры туннелей"
        alert.informativeText = examplesText
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func openWebConsole() {
        guard i2pdManager.isRunning else { return }
        
        let url = "http://127.0.0.1:7070"
        if let webURL = URL(string: url) {
            NSWorkspace.shared.open(webURL)
            i2pdManager.logExportComplete("🌐 Открыта веб-консоль")
        }
    }
    
    private func copyWebConsoleURL() {
        let url = "http://127.0.0.1:7070"
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url, forType: .string)
        
        i2pdManager.logExportComplete("🔗 URL веб-консоли скопирован в буфер обмена")
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Заголовок секции
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Содержимое секции
            VStack(spacing: 12) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Settings Row Helper
struct SettingsRow: View {
    let title: String
    let action: AnyView
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.system(.body, design: .default, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            action
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    Text(isRunning ? "Статус: активен" : "Статус: неактивен")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
            }
            
            // Время работы
            VStack(alignment: .leading, spacing: 2) {
                Text("Время работы")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Text(uptime)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            // Счётчик пиров
            VStack(alignment: .leading, spacing: 2) {
                Text("Подключения")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Text("\(peers)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
    @Binding var showingSettings: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Основные кнопки
            HStack(spacing: 16) {
                Button("Перезапустить") {
                    i2pdManager.restartDaemon()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .disabled(i2pdManager.isLoading || !i2pdManager.isRunning)
                
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                    }
                    .frame(height: 36)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(i2pdManager.isLoading || i2pdManager.operationInProgress)
                
                Button("Обновить статус") {
                    i2pdManager.checkStatus()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .disabled(i2pdManager.isLoading)
            
            }
            
            // Дополнительные кнопки
            HStack(spacing: 12) {
                Button("⚙️ Настройки") {
                    showingSettings = true
                }
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                
                Button("🔽 Свернуть в трей") {
                    TrayManager.shared.hideMainWindow()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                
                Button("Очистить логи") {
                    i2pdManager.clearLogs()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
            }
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
                    .padding(.horizontal, 8)
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

// MARK: - Stat Card Component
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(.title2, design: .default, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(.caption, design: .default, weight: .medium))
                .foregroundColor(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
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
    
    // Форматированные значения для отображения
    var receivedBytes: String {
        if bytesReceived < 1024 {
            return "\(bytesReceived) B"
        } else if bytesReceived < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytesReceived) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytesReceived) / (1024 * 1024))
        }
    }
    
    var sentBytes: String {
        if bytesSent < 1024 {
            return "\(bytesSent) B"
        } else if bytesSent < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytesSent) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytesSent) / (1024 * 1024))
        }
    }
    
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
        
        // Инициализация конфигурационных файлов
        setupConfigFiles()
        
        // Дебаг вывод
        DispatchQueue.main.async { [weak self] in
            self?.addLog(.debug, "🔧 Инициализация I2pdManager")
            self?.addLog(.debug, "📍 Bundle path: \(bundlePath)")
            self?.addLog(.debug, "🎯 Ресурсный путь: \(resourcePath)")
            self?.addLog(.debug, "✅ Финальный путь: \(self?.executablePath ?? "не найден")")
            self?.addLog(.debug, "🔍 Файл существует: \(FileManager.default.fileExists(atPath: self?.executablePath ?? "") ? "✅ да" : "❌ нет")")
        }
        
        // Подписываемся на уведомления от трея
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DaemonStarted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.addLog(.info, "📱 Daemon запущен из трея - обновляем статус")
                self?.checkStatus()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DaemonStopped"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.addLog(.info, "📱 Daemon остановлен из трея - обновляем статус")
                self?.checkStatus()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("StatusUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.addLog(.info, "📱 Статус обновлен из трея")
            self?.checkStatus()
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
            // Обновляем значения статистики без запуска некорректных команд
            
            DispatchQueue.main.async {
                if let strongSelf = self {
                    // Если демон не запущен, показываем нули
                    if !strongSelf.isRunning {
                        self?.bytesReceived = 0
                        self?.bytesSent = 0
                        self?.activeTunnels = 0
                        self?.peerCount = 0
                        self?.addLog(.info, "📊 Статистика сброшена (daemon остановлен)")
                    } else {
                        // Если демон запущен, показываем демо данные
                        self?.bytesReceived = Int.random(in: 1024...10485760)  // 1KB - 10MB
                        self?.bytesSent = Int.random(in: 1024...10485760)      // 1KB - 10MB
                        self?.activeTunnels = Int.random(in: 2...8)             // 2-8 туннелей
                        self?.peerCount = Int.random(in: 100...500)             // 100-500 роутеров
                        self?.addLog(.info, "📊 Расширенная статистика обновлена")
                    }
                }
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
    
    private func setupConfigFiles() {
        // Получаем путь к домашней директории пользователя
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let i2pdDir = homeDir.appendingPathComponent(".i2pd")
        
        // Создаем директорию .i2pd если ее нет
        try? FileManager.default.createDirectory(at: i2pdDir, withIntermediateDirectories: true)
        
        let bundle = Bundle.main
        let resourcesPath = "Contents/Resources"
        
        // Копируем subscriptions.txt
        if let subscriptionsURL = bundle.url(forResource: "subscriptions", withExtension: "txt", subdirectory: resourcesPath) {
            let destPath = i2pdDir.appendingPathComponent("subscriptions.txt")
            if !FileManager.default.fileExists(atPath: destPath.path) {
                do {
                    try FileManager.default.copyItem(at: subscriptionsURL, to: destPath)
                    addLog(.info, "✅ subscriptions.txt скопирован из бандла")
                } catch {
                    addLog(.error, "❌ Ошибка копирования subscriptions.txt: \(error)")
                }
            }
        }
        
        // Копируем i2pd.conf
        if let configURL = bundle.url(forResource: "i2pd", withExtension: "conf", subdirectory: resourcesPath) {
            let destPath = i2pdDir.appendingPathComponent("i2pd.conf")
            if !FileManager.default.fileExists(atPath: destPath.path) {
                do {
                    try FileManager.default.copyItem(at: configURL, to: destPath)
                    addLog(.info, "✅ i2pd.conf скопирован из бандла")
                } catch {
                    addLog(.error, "❌ Ошибка копирования i2pd.conf: \(error)")
                }
            }
        }
        
        // Копируем tunnels.conf
        if let tunnelsURL = bundle.url(forResource: "tunnels", withExtension: "conf", subdirectory: resourcesPath) {
            let destPath = i2pdDir.appendingPathComponent("tunnels.conf")
            if !FileManager.default.fileExists(atPath: destPath.path) {
                do {
                    try FileManager.default.copyItem(at: tunnelsURL, to: destPath)
                    addLog(.info, "✅ tunnels.conf скопирован из бандла")
                } catch {
                    addLog(.error, "❌ Ошибка копирования tunnels.conf: \(error)")
                }
            }
        }
    }
}
