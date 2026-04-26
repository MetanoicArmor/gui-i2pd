import SwiftUI
import Foundation
import AppKit
import QuartzCore

// MARK: - Localization Helper
func L(_ key: String) -> String {
    return NSLocalizedString(key, comment: "")
}

// MARK: - Configuration Path Helper
func getI2pdConfigDirectory() -> URL {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    return homeDir.appendingPathComponent("Library/Application Support/i2pd")
}

// MARK: - Window Close Delegate для корректного сворачивания в трей
class WindowCloseDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowCloseDelegate()
    
    // Глобальное состояние открытого окна настроек
    static var isSettingsOpen = false
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        print("🚪 Окно пытается закрыться - делегат вызван для: \(sender.title)")
        
        // Проверяем глобальное состояние настроек
        if WindowCloseDelegate.isSettingsOpen {
            print("⚙️ Настройки открыты (через глобальное состояние) - закрываем их")
            NotificationCenter.default.post(name: NSNotification.Name("CloseSettings"), object: nil)
            WindowCloseDelegate.isSettingsOpen = false
            
            // Принудительно завершаем модальное представление если оно не закрывается
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if WindowCloseDelegate.isSettingsOpen {
                    print("⚙️ Принудительное закрытие настроек через NSApp")
                    NotificationCenter.default.post(name: NSNotification.Name("CloseSettings"), object: nil)
                    WindowCloseDelegate.isSettingsOpen = false
                }
            }
            return true
        }
        
        // Проверяем, есть ли активное модальное окно настроек
        if isSettingsModalOpen() {
            print("⚙️ Обнаружено модальное окно настроек - закрываем его")
            NotificationCenter.default.post(name: NSNotification.Name("CloseSettings"), object: nil)
            WindowCloseDelegate.isSettingsOpen = false
            return true
        }
        
        print("🚪 Главное окно закрывается - сворачиваем в трей")
        
        // Только главное окно: сворачиваем в трей, а не закрываем приложение
        TrayManager.shared.hideMainWindow()
        
        // Предотвращаем стандартное закрытие окна - приложение остается работать в трее
        return false
    }
    
    private func isSettingsModalOpen() -> Bool {
        // Проверяем, есть ли активное модальное окно настроек через поиск текущего окна
        let windows = NSApplication.shared.windows
        print("🔍 Проверяем окна: всего \(windows.count)")
        
        // Проверяем есть ли у нас более одного окна (главное + модальное)
        if windows.count > 1 {
            // Ищем модальное окно SwiftUI
            for (index, window) in windows.enumerated() {
                print("🔍 Окно \(index): '\(window.title)', visible: \(window.isVisible), level: \(window.level)")
                
                // Модальные окна SwiftUI часто имеют специальные уровни
                if window !== NSApplication.shared.keyWindow && window.isVisible {
                    print("🔍 Найдено потенциальное модальное окно: \(window.title)")
                    return true
                }
            }
        }
        
        // Проверяем через глобальное состояние приложения
        // Модальное окно SwiftUI часто создает дополнительные окна
        
        // Дополнительная проверка: если есть активное модальное окно, оно будет видно в keyWindow
        if let keyWindow = NSApplication.shared.keyWindow {
            if keyWindow.title.contains("Настройки") || keyWindow.title.contains("Settings") {
                print("🔍 Найдено окно настроек через ключевое окно")
                return true
            }
        }
        
        return false
    }
}

// MARK: - App Delegate для обработки завершения приложения
private enum MainWindowLayout {
    static let logSectionExpandedDefaultsKey = "mainLogSectionExpanded"
    /// Фиксированная ширина окна. Окно не ресайзится по горизонтали, чтобы раскладка
    /// контента (кнопки, сетка статистики) не «прыгала» и снизу не появлялось пустое место.
    static let fixedWindowWidth: CGFloat = 540
    /// Высота панели логов в свёрнутом состоянии (только заголовок).
    static let collapsedLogSectionHeight: CGFloat = 56
    /// Дельта, на которую растёт лог-панель (и, соответственно, окно) при разворачивании.
    static let logExpansionDelta: CGFloat = 224
    /// Высота панели логов в развёрнутом состоянии. Связана с `collapsedLogSectionHeight` через `logExpansionDelta`,
    /// чтобы рассогласований было невозможно создать одной правкой.
    static let expandedLogSectionHeight: CGFloat = collapsedLogSectionHeight + logExpansionDelta
    /// Вертикальный отступ контента от верх/низ окна — равен боковому, чтобы рамка смотрелась симметрично.
    static let contentEdgeInset: CGFloat = LiquidGlassTheme.windowPadding
    /// Расстояние между крупными секциями (статус, сеть, кнопки, логи).
    static let sectionSpacing: CGFloat = 12
    static let logPanelInset: CGFloat = 10
    /// Горизонтальные отступы строки лога: справа меньше — ближе к полосе прокрутки, без смены ширины панели.
    static let logRowHorizontalLeading: CGFloat = 20
    static let logRowHorizontalTrailing: CGFloat = 6
    static let sectionHeaderHeight: CGFloat = 36
    /// Минимальная высота скролла логов внутри развёрнутой панели.
    static let expandedLogViewportMinHeight: CGFloat = 160
    static let animationDuration: TimeInterval = 0.28
    /// Буфер после `animationDuration` при развороте: окно уже финальной высоты,
    /// SwiftUI дорисовывает секцию — до этого момента держим MainWindowSizer выключенным.
    static let logExpandSizerResumeDelay: TimeInterval = 0.05
    /// Прикидка под `.defaultSize` для первого запуска. Дальше окно подгоняется по реальному
    /// natural-размеру контента через `MainWindowSizer`.
    static let estimatedCollapsedWindowHeight: CGFloat = 500
    static var estimatedExpandedWindowHeight: CGFloat { estimatedCollapsedWindowHeight + logExpansionDelta }

    static func logSectionHeight(isLogExpanded: Bool) -> CGFloat {
        isLogExpanded ? expandedLogSectionHeight : collapsedLogSectionHeight
    }

    static func estimatedWindowHeight(isLogExpanded: Bool) -> CGFloat {
        isLogExpanded ? estimatedExpandedWindowHeight : estimatedCollapsedWindowHeight
    }
}

private extension NSWindow {
    /// Меняет размер окна, оставляя верхнюю кромку на месте (origin.y подстраивается).
    func setSizeAnchoringTop(_ size: NSSize) {
        let topY = frame.maxY
        var newFrame = frame
        newFrame.size = size
        newFrame.origin.y = topY - size.height
        setFrame(newFrame, display: true, animate: false)
    }
}

private extension NSView {
    func enclosingNSScrollView() -> NSScrollView? {
        var v: NSView? = self
        while let c = v {
            if let s = c as? NSScrollView { return s }
            v = c.superview
        }
        return nil
    }
}

/// SwiftUI `ScrollView` на macOS по умолчанию использует `NSScrollView` в стиле `.legacy`:
/// вертикальный скроллер в отдельной колонке — заметный зазор до правой рамки панели.
/// `.overlay` рисует скроллер поверх контента у края (как в системных списках).
private struct LogPanelScrollViewTrailingFixer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.frame = .zero
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let scroll = nsView.enclosingNSScrollView() else { return }
            scroll.scrollerStyle = .overlay
            var si = scroll.scrollerInsets
            si.right = 0
            scroll.scrollerInsets = si
            scroll.contentView.automaticallyAdjustsContentInsets = false
            scroll.contentView.contentInsets = .init()
        }
    }
}

/// NSView-зонд, который сидит в `.background` под главным контентом и подгоняет
/// размер РЕАЛЬНОГО `view.window` под натуральную высоту, измеренную через
/// `GeometryReader`. Это надёжнее, чем искать окно через `NSApplication.windows`
/// по title — мы получаем именно тот NSWindow, в который отрендерился ContentView.
struct MainWindowSizer: NSViewRepresentable {
    let measuredHeight: CGFloat
    /// Пока идёт явная анимация окна из `toggleLogSection`, не трогаем frame —
    /// иначе десятки `setFrame` за свайп конфликтуют с `NSAnimationContext` и
    /// съедают плавность.
    var deferResizeToHostAnimation: Bool

    final class Coordinator {
        /// Актуальное значение с родителя; читается внутри `async`, чтобы не
        /// применять устаревший кадр после переключения флага.
        var deferResizeToHostAnimation = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.deferResizeToHostAnimation = deferResizeToHostAnimation
        guard !deferResizeToHostAnimation else { return }
        let height = max(measuredHeight, 1).rounded(.up)
        let target = NSSize(width: MainWindowLayout.fixedWindowWidth, height: height)
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak host = nsView] in
            guard let coordinator, let host, let window = host.window else { return }
            guard !coordinator.deferResizeToHostAnimation else { return }
            Self.apply(target: target, to: window)
        }
    }

    private static func apply(target: NSSize, to window: NSWindow) {
        window.isRestorable = false
        window.setFrameAutosaveName("")

        let relaxedMin = NSSize(width: target.width, height: 1)
        let relaxedMax = NSSize(width: target.width, height: 100_000)
        let needsRelax =
            window.minSize.height > target.height
            || window.maxSize.height < target.height
            || window.minSize.width != target.width
            || window.maxSize.width != target.width
        if needsRelax {
            if window.minSize != relaxedMin { window.minSize = relaxedMin }
            if window.maxSize != relaxedMax { window.maxSize = relaxedMax }
        }

        if window.frame.size != target {
            window.setSizeAnchoringTop(target)
        }

        if window.minSize != target { window.minSize = target }
        if window.maxSize != target { window.maxSize = target }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    // Флаг для отслеживания перезапуска приложения (не останавливать демон)
    static var isRestarting = false
    
    private var windowToggleMonitor: Any?
    
    override init() {
        super.init()
        setupGlobalQuitHandler()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Снимаем restorable-флаг и autosave-имя со всех уже созданных окон.
        // Без этого SwiftUI WindowGroup восстанавливает прежний фрейм быстрее,
        // чем мы успеваем посчитать высоту контента.
        for window in NSApplication.shared.windows {
            window.isRestorable = false
            window.setFrameAutosaveName("")
        }

        // Проверяем настройку "Запускать свернутым"
        let startMinimized = UserDefaults.standard.bool(forKey: "startMinimized")

        if startMinimized {
            print("🔽 Запускаем приложение свернутым в трей")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                TrayManager.shared.hideMainWindow()
            }
        }
        setupWindowToggleShortcut()
    }

    /// Запрещаем macOS пытаться восстанавливать UI-состояние приложения через
    /// secure coding. Восстановленный NSWindow приходит со старым фреймом и
    /// конфликтует с нашим расчётом высоты по контенту.
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
    
    private func setupWindowToggleShortcut() {
        windowToggleMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let isCmdW = event.modifierFlags.contains(.command)
                && (event.characters == "w" || event.charactersIgnoringModifiers == "w" || event.keyCode == 13)
            guard isCmdW else { return event }
            DispatchQueue.main.async {
                TrayManager.shared.toggleMainWindow()
            }
            return nil
        }
    }
    
    private func setupGlobalQuitHandler() {
        // Добавляем обработчик для NSApp (обрабатывает только Ctrl+Q и другие системные запросы завершения)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        // Перехватываем Cmd+Q через меню
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setupQuitMenuItem()
        }
        
        // Устанавливаем делегат окна с небольшой задержкой, чтобы окно успело создаться
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupWindowDelegate()
        }
    }
    
    private func setupQuitMenuItem() {
        // Находим меню "Quit" и заменяем его действие
        if let mainMenu = NSApp.mainMenu {
            for menu in mainMenu.items {
                if let submenu = menu.submenu {
                    for item in submenu.items {
                        if item.action == #selector(NSApplication.terminate(_:)) {
                            print("🔧 Перехватываем Cmd+Q (Quit)")
                            item.action = #selector(self.customQuit(_:))
                            item.target = self
                        }
                    }
                }
            }
        }
    }
    
    @objc private func customQuit(_ sender: Any?) {
        print("🚪 Custom Quit вызван - обрабатываем корректно")
        
        // Если приложение перезапускается, просто выходим
        if AppDelegate.isRestarting {
            print("🔄 Перезапуск - быстрый выход")
            NSApp.terminate(nil)
            return
        }
        
        // Принудительно закрываем все окна (включая настройки)
        print("🚪 Закрываем все окна перед выходом")
        for window in NSApplication.shared.windows {
            window.close()
        }
        
        // Сбрасываем флаг настроек
        WindowCloseDelegate.isSettingsOpen = false
        
        // Даём время окнам закрыться, затем завершаем
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🚪 Завершаем приложение")
            NSApp.terminate(nil)
        }
    }
    
    private func setupWindowDelegate() {
        // Назначаем правильного делегата для обработки закрытия всех окон
        for window in NSApplication.shared.windows {
            if window.delegate == nil || window.delegate is AppDelegate {
                window.delegate = WindowCloseDelegate.shared
                print("✅ Назначен WindowCloseDelegate для окна: \(window.title)")
            }
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("🚪 applicationShouldTerminate вызван")
        
        // Если приложение перезапускается (смена языка), разрешаем выход БЕЗ остановки демона
        if AppDelegate.isRestarting {
            print("🔄 Перезапуск - разрешаем выход без остановки демона")
            return .terminateNow
        }
        
        // При обычном выходе принудительно закрываем все окна (включая настройки)
        print("🚪 Обычный выход - закрываем все окна")
        for window in NSApplication.shared.windows {
            window.close()
        }
        
        // Сбрасываем флаг настроек
        WindowCloseDelegate.isSettingsOpen = false
        
        // Разрешаем завершение - будет вызван applicationWillTerminate
        return .terminateNow
    }
    
    @objc func applicationWillTerminate(_ notification: Notification) {
        print("🚪🚪🚪 AppDelegate.applicationWillTerminate ВЫЗВАН! 🚪🚪🚪")
        
        // Если приложение перезапускается (смена языка), НЕ останавливаем демон
        if AppDelegate.isRestarting {
            print("🔄 Приложение перезапускается - демон НЕ останавливается")
            return
        }
        
        // Уведомляем о завершении процессов Tools
        NotificationCenter.default.post(name: NSNotification.Name("ApplicationWillTerminate"), object: nil)
        Thread.sleep(forTimeInterval: 0.3)
        
        // Вызываем СИНХРОННУЮ остановку демона напрямую (без recursion)
        let findAndKillCommand = """
        DEMON_PID=$(ps aux | grep "i2pd.*daemon" | grep -v grep | awk '{print $2}' | head -1)
        if [ -n "$DEMON_PID" ]; then
            echo "✅ Найден демон с PID: $DEMON_PID"
            kill -s INT $DEMON_PID 2>/dev/null
            echo "✅ Демон остановлен синхронно через AppDelegate"
            sleep 0.3
        else
            echo "ℹ️ Демон не найден"
        fi
        """
        
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        killProcess.arguments = ["-c", findAndKillCommand]
        
        do {
            print("💀 AppDelegate: Выполняем синхронную остановку демона...")
            try killProcess.run()
            killProcess.waitUntilExit()
            print("✅ AppDelegate: Синхронная остановка завершена")
            
        } catch {
            print("❌ AppDelegate: Ошибка остановки демона: \(error)")
        }
        
        print("🚪 AppDelegate завершил работу")
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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("darkMode") private var darkMode = true
    @State private var showingSettings = false
    @State private var showingTools = false
    
    init() {
        // Устанавливаем только UserDefaults по умолчанию
        if UserDefaults.standard.object(forKey: "darkMode") == nil {
            UserDefaults.standard.set(true, forKey: "darkMode")
        }

        // Полностью гасим window state restoration — иначе при следующем запуске
        // NSWindow восстанавливается в прежнем (часто гигантском) фрейме до того,
        // как мы успеваем посчитать реальную высоту контента, и пользователь
        // видит «прыжок» с пустыми чёрными полосами вокруг.
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        // Подчищаем возможный мусор от прошлых запусков, где state ещё писался.
        for key in UserDefaults.standard.dictionaryRepresentation().keys
            where key.hasPrefix("NSWindow Frame ") {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // Применяем сохраненный язык
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ru"
        UserDefaults.standard.set([savedLanguage], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Инициализируем менеджер трея
        _ = TrayManager.shared
        
        // Показываем главное окно при запуске только если не включена настройка "запускать свернутым"
        let startMinimized = UserDefaults.standard.bool(forKey: "startMinimized")
        
        if !startMinimized {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                TrayManager.shared.showMainWindow()
            }
        }
        
        // Проверяем состояние настройки "скрыть из Dock" при запуске (после показа окна)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            I2pdGUIApp.checkAndApplyDockVisibilitySetting()
        }
    }
    
    static func checkAndApplyDockVisibilitySetting() {
        let hideFromDock = UserDefaults.standard.bool(forKey: "hideFromDock")
        
        if hideFromDock {
            // Если настройка включена, применяем политику accessory
            NSApplication.shared.setActivationPolicy(.accessory)
            print("📱 Применена политика accessory (скрытие из Dock) при запуске")
        } else {
            // Если настройка выключена, применяем политику regular
            NSApplication.shared.setActivationPolicy(.regular)
            print("📱 Применена политика regular (показ в Dock) при запуске")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(
            width: MainWindowLayout.fixedWindowWidth,
            height: MainWindowLayout.estimatedWindowHeight(
                isLogExpanded: UserDefaults.standard.bool(forKey: MainWindowLayout.logSectionExpandedDefaultsKey)
            )
        )
        // Намеренно не задаём .windowResizability — оставляем системный default.
        // Реальные min/max окна и его frame пересчитываются в MainWindowSizer на
        // основе natural-высоты контента, измеренной через GeometryReader.
        
        // Settings убраны - используем NSAlert из трея
        
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button(L("Окно (⌘W)")) {
                    TrayManager.shared.toggleMainWindow()
                }
                .keyboardShortcut("w", modifiers: [.command])
                
                Button(L("Настройки (⌘,)")) {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
                
                Button(L("Утилиты (⌘T)")) {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenTools"), object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command])
            }
            
        }
    }
}

// MARK: - Убрана SettingsWindowView (используем NSAlert вместо неё)

// MARK: - Main Content View
struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var i2pdManager = I2pdManager()
    @State private var showingSettings = false
    @State private var showingTools = false
    @AppStorage(MainWindowLayout.logSectionExpandedDefaultsKey) private var isLogSectionExpanded = false
    @AppStorage("autoStartDaemon") private var autoStartDaemon = false
    @State private var manualStop: Bool? = false // Флаг ручной остановки для предотвращения автозапуска
    /// Пока окно анимируется вручную (логи), `MainWindowSizer` не вмешивается.
    @State private var hostWindowAnimatingLogResize = false

    /// Даёт перенос длинных путей в логах (мягкий разрыв после «/»).
    private static func logMessageForWrapping(_ message: String) -> String {
        message.replacingOccurrences(of: "/", with: "/\u{200B}")
    }

    private var logSectionAnimation: Animation {
        .easeInOut(duration: MainWindowLayout.animationDuration)
    }

    private var networkStatColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 84, maximum: 200), spacing: 12, alignment: .leading)]
    }
    
    var body: some View {
        VStack(spacing: MainWindowLayout.sectionSpacing) {
            // Статус сервера
            StatusCard(
                isRunning: i2pdManager.isRunning,
                uptime: i2pdManager.uptime,
                peers: i2pdManager.peerCount,
                daemonVersion: i2pdManager.daemonVersion
            )
            
            // Компактная сетевая статистика - всегда развернута
            VStack(spacing: 8) {
                // Заголовок секции
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)
                    Text(L("Сетевая статистика"))
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .liquidGlassHeader()
                
                LazyVGrid(columns: networkStatColumns, alignment: .leading, spacing: 12) {
                    NetworkStatItem(
                        title: L("Получено"),
                        value: i2pdManager.receivedBytes,
                        icon: "arrow.down.circle.fill",
                        color: .green
                    )
                    NetworkStatItem(
                        title: L("Отправлено"),
                        value: i2pdManager.sentBytes,
                        icon: "arrow.up.circle.fill",
                        color: .blue
                    )
                    NetworkStatItem(
                        title: L("Туннели"),
                        value: "\(i2pdManager.activeTunnels)",
                        icon: "lock.fill",
                        color: .purple
                    )
                    NetworkStatItem(
                        title: L("Успешность"),
                        value: i2pdManager.tunnelCreationSuccessRate,
                        icon: "percent",
                        color: .teal
                    )
                    NetworkStatItem(
                        title: L("Роутеры"),
                        value: "\(i2pdManager.peerCount)",
                        icon: "wifi",
                        color: .orange
                    )
                    NetworkStatItem(
                        title: L("Флудфилы"),
                        value: "\(i2pdManager.floodfills)",
                        icon: "circle.grid.2x2.fill",
                        color: .mint
                    )
                    NetworkStatItem(
                        title: L("LeaseSets"),
                        value: "\(i2pdManager.leaseSets)",
                        icon: "doc.text.magnifyingglass",
                        color: .indigo
                    )
                    NetworkStatItem(
                        title: L("Caps"),
                        value: i2pdManager.routerCaps,
                        icon: "cpu",
                        color: .secondary
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .padding(10)
            .liquidGlassPanel(cornerRadius: 18, material: .regularMaterial)
            
            // Кнопки управления
            ControlButtons(
                i2pdManager: i2pdManager,
                showingSettings: $showingSettings,
                showingTools: $showingTools,
                manualStop: $manualStop
            )
            
            // Секция логов
            ZStack(alignment: .top) {
                if isLogSectionExpanded {
                    ScrollView(.vertical, showsIndicators: true) {
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

                                    Text(Self.logMessageForWrapping(log.message))
                                        .font(.caption2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(nil)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.leading, MainWindowLayout.logRowHorizontalLeading)
                                .padding(.trailing, MainWindowLayout.logRowHorizontalTrailing)
                                .padding(.vertical, 1)
                            }

                            if i2pdManager.logs.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                    Text(L("Система готова к работе"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(L("Логи появятся при запуске демона"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, MainWindowLayout.logRowHorizontalLeading)
                                .padding(.vertical, 40)
                            }

                            // Якорь внутри документа скролла — ищем родительский NSScrollView и поджимаем скроллер к краю.
                            Color.clear
                                .frame(width: 1, height: 1)
                                .accessibilityHidden(true)
                                .background(LogPanelScrollViewTrailingFixer())
                        }
                        .padding(.top, MainWindowLayout.sectionHeaderHeight)
                        .padding(.bottom, 8)
                    }
                    .frame(minHeight: MainWindowLayout.expandedLogViewportMinHeight, maxHeight: .infinity)
                    // При развороте opacity-insert даёт рассинхрон с ростом окна (визуальный «прыжок»).
                    // Сворачивание оставляем мягким через fade-out.
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
                }

                HStack {
                    Button {
                        toggleLogSection()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                            Text(L("Логи системы"))
                                .font(.headline)
                                .fontWeight(.semibold)
                            Image(systemName: isLogSectionExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(isLogSectionExpanded ? L("Свернуть логи") : L("Развернуть логи"))

                    Spacer()
                    if !i2pdManager.logs.isEmpty {
                        Button {
                            i2pdManager.clearLogs()
                        } label: {
                            Label(L("Очистить"), systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: MainWindowLayout.sectionHeaderHeight, alignment: .center)
                // Для macOS 26 возвращаем "жидкую линзу" через glassEffect,
                // как было раньше в этом блоке.
                .liquidGlassSidebarChrome(
                    cornerRadius: 14,
                    tintOpacity: 0.06,
                    surfaceTintOpacity: 0.025,
                    shadowOpacity: 0.025
                )
                .animation(nil, value: isLogSectionExpanded)
                .zIndex(1)
            }
            .compositingGroup()
            .padding(MainWindowLayout.logPanelInset)
            .frame(height: MainWindowLayout.logSectionHeight(isLogExpanded: isLogSectionExpanded))
            .clipped()
            .animation(logSectionAnimation, value: isLogSectionExpanded)
            .liquidGlassPanel(cornerRadius: 18, material: .regularMaterial)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, LiquidGlassTheme.windowPadding)
        .padding(.vertical, MainWindowLayout.contentEdgeInset)
        .frame(width: MainWindowLayout.fixedWindowWidth)
        .background(
            LiquidGlassBackdrop(material: .underWindowBackground)
                .ignoresSafeArea()
        )
        .liquidGlassWindow()
        .background(
            // GeometryReader сообщает natural-высоту контента, MainWindowSizer
            // напрямую тянет за этим РЕАЛЬНЫЙ NSWindow (через nsView.window),
            // не полагаясь на поиск окна по title в NSApp.windows.
            GeometryReader { proxy in
                MainWindowSizer(
                    measuredHeight: proxy.size.height,
                    deferResizeToHostAnimation: hostWindowAnimatingLogResize
                )
                    .frame(width: 0, height: 0)
            }
        )
        .onAppear {
            // Сначала проверяем начальный статус демона для корректного отображения в трее
            TrayManager.shared.checkInitialDaemonStatus()
            
            i2pdManager.checkStatus()
            
            // Инициализируем состояние трея на основе текущего состояния демона
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                TrayManager.shared.updateMenuState(isRunning: i2pdManager.isRunning)
            }
            
            // Проверяем и автоматически запускаем демон если включено и не было ручной остановки
            if autoStartDaemon && !i2pdManager.isRunning && !(manualStop ?? false) {
                print("🚀 Автоматический запуск демона включен - запускаем i2pd")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    i2pdManager.startDaemon()
                }
            }
            
            // Загружаем статистику и применяем тему после полной инициализации
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                applyTheme()
                i2pdManager.getExtendedStats()
            }

            syncMainWindowSizeWithLogState()
            syncMainWindowSizeWithLogState(after: 0.2)
            syncMainWindowSizeWithLogState(after: 0.7)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(i2pdManager: i2pdManager, manualStop: $manualStop)
        }
        .sheet(isPresented: $showingTools) {
            ToolsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSettings"))) { _ in
            showingSettings = true
            WindowCloseDelegate.isSettingsOpen = true
            print("⚙️ Настройки открыты - обновляем глобальное состояние")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseSettings"))) { _ in
            showingSettings = false
            WindowCloseDelegate.isSettingsOpen = false
            print("⚙️ Настройки закрыты - обновляем глобальное состояние")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenTools"))) { _ in
            showingTools = true
            print("🔧 Утилиты открыты")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SyncMainWindowLayout"))) { _ in
            syncMainWindowSizeWithLogState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DaemonStartRequest"))) { _ in
            // Обрабатываем запрос запуска демона из трея
            print("🚀 Получен запрос запуска демона из трея")
            if !i2pdManager.isRunning {
                manualStop = false // Сбрасываем флаг при ручном запуске
                i2pdManager.startDaemon()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DaemonStopRequest"))) { _ in
            // Обрабатываем запрос остановки демона из трея
            print("⏹️ Получен запрос остановки демона из трея")
            if i2pdManager.isRunning {
                manualStop = true // Устанавливаем флаг ручной остановки
                i2pdManager.stopDaemon()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DaemonRestartRequest"))) { _ in
            // Обрабатываем запрос перезапуска демона из трея
            print("🔄 Получен запрос перезапуска демона из трея")
            manualStop = false // Сбрасываем флаг при перезапуске
            i2pdManager.restartDaemon()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DaemonRestarting"))) { _ in
            // Уведомляем трей о начале перезапуска
            print("🔄 Уведомляем трей о начале перезапуска")
            TrayManager.shared.setRestarting(true)
            TrayManager.shared.updateMenuState(isRunning: i2pdManager.isRunning)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DaemonRestartComplete"))) { _ in
            // Уведомляем трей о завершении перезапуска
            print("✅ Уведомляем трей о завершении перезапуска")
            TrayManager.shared.setRestarting(false)
            TrayManager.shared.updateMenuState(isRunning: i2pdManager.isRunning)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NSApplicationWillTerminate"))) { _ in
            UserDefaults.standard.set(isLogSectionExpanded, forKey: MainWindowLayout.logSectionExpandedDefaultsKey)
            // Останавливаем демон при закрытии приложения через I2pdManager
            if i2pdManager.isRunning {
                i2pdManager.stopDaemon()
            }
        }
        .overlay {
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
                .liquidGlassPanel(cornerRadius: 12, material: .thinMaterial, shadowOpacity: 0.12)
                .padding(.bottom, 20)
            }
        }
    }

    /// Совместимость со старыми вызовами `SyncMainWindowLayout`-нотификаций.
    /// Сам resize теперь делает `MainWindowSizer` через `view.window`, поэтому
    /// здесь только сбрасываем restorable-флаг — на случай если окно появилось
    /// уже после init и AppDelegate его не зацепил.
    private func syncMainWindowSizeWithLogState(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            for window in NSApplication.shared.windows {
                window.isRestorable = false
                window.setFrameAutosaveName("")
            }
        }
    }

    private func toggleLogSection() {
        guard !hostWindowAnimatingLogResize else { return }
        let wasExpanded = isLogSectionExpanded
        guard let window = mainContentWindow() else {
            withAnimation(logSectionAnimation) {
                isLogSectionExpanded.toggle()
            }
            return
        }

        let delta = MainWindowLayout.logExpansionDelta
        let newHeight = (window.frame.height + (wasExpanded ? -delta : delta)).rounded(.up)
        let targetSize = NSSize(width: MainWindowLayout.fixedWindowWidth, height: max(newHeight, 1))

        hostWindowAnimatingLogResize = true
        window.isRestorable = false
        window.setFrameAutosaveName("")

        let relaxedMin = NSSize(width: MainWindowLayout.fixedWindowWidth, height: 1)
        let relaxedMax = NSSize(width: MainWindowLayout.fixedWindowWidth, height: 100_000)
        window.minSize = relaxedMin
        window.maxSize = relaxedMax

        var newFrame = window.frame
        newFrame.size = targetSize
        newFrame.origin.y = window.frame.maxY - targetSize.height

        // Анимация секции уже задаётся через `.animation(..., value:)` на блоке логов.
        // Дополнительный withAnimation здесь создаёт второй транзакционный контур
        // параллельно с NSAnimationContext окна и даёт подёргивания всего контента.
        isLogSectionExpanded.toggle()

        if wasExpanded {
            // Сворачивание: нижняя кромка окна плавно подтягивается вверх.
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = MainWindowLayout.animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }, completionHandler: {
                DispatchQueue.main.async {
                    hostWindowAnimatingLogResize = false
                }
            })
        } else {
            // Разворот: две независимые интерполяции (окно + SwiftUI) постоянно
            // рассинхронились и давали «прыжок вверх». Окно сразу финальной высоты;
            // двигается только контент панели логов.
            window.setFrame(newFrame, display: true, animate: false)
            let resumeDelay = MainWindowLayout.animationDuration + MainWindowLayout.logExpandSizerResumeDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + resumeDelay) {
                hostWindowAnimatingLogResize = false
            }
        }
    }

    private func mainContentWindow() -> NSWindow? {
        NSApplication.shared.windows.first { window in
            window.isVisible && window.level == .normal && window.sheetParent == nil
                && window.title == "I2P Daemon GUI"
        } ?? NSApplication.shared.windows.first { window in
            window.isVisible && window.level == .normal && window.sheetParent == nil
                && !window.title.localizedCaseInsensitiveContains("settings")
                && !window.title.localizedCaseInsensitiveContains("настрой")
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

private struct NetworkStatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.leading)

                Text(value)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var i2pdManager: I2pdManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Иконка приложения
            Image(systemName: "network")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text(L("I2P Daemon GUI"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(String(format: NSLocalizedString("Версия %@", comment: "app version in About"), i2pdManager.daemonVersion))
                .font(.headline)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            
            VStack(spacing: 8) {
                Text(L("Современный GUI для управления I2P Daemon"))
                    .multilineTextAlignment(.center)
                Text(L("• Радикальная остановка daemon"))
                Text(L("• Мониторинг в реальном времени"))
                Text(String(format: NSLocalizedString("Встроенный бинарник i2pd %@", comment: "bundled binary"), i2pdManager.daemonVersion))
                Text(L("• Подвижное и масштабируемое окно"))
                Text(L("• Тёмный интерфейс"))
            }
            .font(.body)
            .multilineTextAlignment(.center)
            
            Divider()
            
            VStack(spacing: 2) {
                Text(L("Разработано на SwiftUI"))
                    .font(.caption)
                Text(L("Swift 5.7+ • macOS 14.0+"))
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
    @Binding var manualStop: Bool?
    @Environment(\.dismiss) private var dismiss
    
    init(i2pdManager: I2pdManager, manualStop: Binding<Bool?>? = nil) {
        self.i2pdManager = i2pdManager
        self._manualStop = manualStop ?? .constant(nil)
        
        // Инициализируем значения из конфига при создании view
        let daemonPort = Self.loadDaemonPortFromConfig()
        let socksPort = Self.loadSocksPortFromConfig()
        let bandwidthValue = Self.loadBandwidthFromConfig()
        
        print("📋 DEBUG: SettingsView init - HTTP порт: \(daemonPort), SOCKS порт: \(socksPort), Bandwidth: \(bandwidthValue)")
        
        _displayDaemonPort = State(initialValue: daemonPort)
        _displaySocksPort = State(initialValue: socksPort)
        _displayBandwidth = State(initialValue: bandwidthValue)
    }
    @AppStorage("daemonPort") private var daemonPort = 4444
    @AppStorage("socksPort") private var socksPort = 4447
    @AppStorage("bandwidth") private var bandwidth = "L"
    @State private var displayDaemonPort = 4444
    @State private var displaySocksPort = 4447
    @State private var displayBandwidth = "L"
    @State private var showBandwidthAlert = false
    @State private var showHttpPortAlert = false
    @State private var showSocksPortAlert = false

    
    
    // Статические функции для чтения портов из конфига при инициализации
    static private func loadDaemonPortFromConfig() -> Int {
        return Self.loadPortFromConfigForSection("httpproxy") ?? 4444
    }
    
    static private func loadSocksPortFromConfig() -> Int {
        return Self.loadPortFromConfigForSection("socksproxy") ?? 4447
    }
    
    static private func loadBandwidthFromConfig() -> String {
        return Self.loadBandwidthFromConfigSection("bandwidth") ?? "L"
    }
    
    static private func loadPortFromConfigForSection(_ sectionName: String) -> Int? {
        let configPath = getI2pdConfigDirectory().appendingPathComponent("i2pd.conf")
        
        print("📋 DEBUG: Ищем порт для секции '\(sectionName)' в \(configPath.path)")
        
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            print("⚠️ i2pd.conf не найден для секции \(sectionName)")
            return nil
        }
        
        do {
            let configContent = try String(contentsOf: configPath)
            let lines = configContent.components(separatedBy: .newlines)
            
            var inTargetSection = false
            var currentSection = ""
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                
                // Пропускаем пустые строки
                guard !trimmedLine.isEmpty else { continue }
                
                // Определяем текущую секцию
                if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                    currentSection = trimmedLine.lowercased()
                    // Убираем квадратные скобки для сравнения
                    let sectionNameClean = currentSection.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    
                    inTargetSection = sectionNameClean == sectionName
                    print("📋 DEBUG: Секция '\(sectionNameClean)' - в нашей цели: \(inTargetSection)")
                    
                } else if inTargetSection {
                    // Мы в нужной секции, ищем строку с портом
                    if Self.isPortLine(trimmedLine) {
                        print("📋 DEBUG: Найдена строка с портом '\(trimmedLine)' в секции \(sectionName)")
                        
                        if let port = Self.extractPortFromConfigLine(trimmedLine) {
                            // Проверяем что это не комментарий (раскомментированная строка имеет приоритет)
                            if !trimmedLine.hasPrefix("#") {
                                print("📋 DEBUG: Извлечен активный порт \(port) для секции \(sectionName)")
                                return port
                            } else {
                                // Если это комментарий, сохраняем как резервный вариант
                                print("📋 DEBUG: Найден закомментированный порт \(port) для секции \(sectionName)")
                                // Возвращаем закомментированный порт если активных нет
                                return port
                            }
                        }
                    }
                }
            }
            
            print("⚠️ DEBUG: Порт для секции '\(sectionName)' не найден")
        } catch {
            print("❌ Ошибка чтения конфига для секции \(sectionName): \(error)")
        }
        
        return nil
    }
    
    // Проверяет является ли строка строкой с портом (только стандартные строки)
    static private func isPortLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Убираем комментарии для проверки
        let cleanLine = trimmedLine.hasPrefix("#") ? 
            String(trimmedLine.dropFirst()).trimmingCharacters(in: .whitespaces) : 
            trimmedLine
        
        // Проверяем точный паттерн: строка должна начинаться с "port" и содержать "="
        // Исключаем случаи типа "notaport = 123"
        return cleanLine.hasPrefix("port") && cleanLine.contains("=")
    }
    
    // Извлекает порт из строки конфига (адаптивно к комментариям и пробелам)
    static private func extractPortFromConfigLine(_ line: String) -> Int? {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Убираем символ # в начале если он есть
        let cleanLine = trimmedLine.hasPrefix("#") ? 
            String(trimmedLine.dropFirst()).trimmingCharacters(in: .whitespaces) : 
            trimmedLine
        
        // Разбиваем по "port =" чтобы найти значение
        let components = cleanLine.components(separatedBy: "port =")
        
        guard components.count > 1 else {
            return nil
        }
        
        let portSection = components[1].trimmingCharacters(in: .whitespaces)
        
        // Берем первое слово (до пробела), которое должно быть числом
        let portValue = portSection.components(separatedBy: .whitespaces).first ?? portSection
        
        // Пытаемся преобразовать в число
        return Int(portValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    // Старая функция (legacy)
    static private func extractPortFromLineStatic(_ line: String) -> Int? {
        return extractPortFromConfigLine(line)
    }
    
    // Загружает значение bandwidth из конфига
    static private func loadBandwidthFromConfigSection(_ settingName: String) -> String? {
        let configPath = getI2pdConfigDirectory().appendingPathComponent("i2pd.conf")
        
        print("📋 DEBUG: Ищем bandwidth в \(configPath.path)")
        
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            print("⚠️ i2pd.conf не найден для bandwidth")
            return nil
        }
        
        do {
            let configContent = try String(contentsOf: configPath)
            let lines = configContent.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                
                // Пропускаем пустые строки
                guard !trimmedLine.isEmpty else { continue }
                
                // Ищем строку с bandwidth = 
                if Self.isBandwidthLine(trimmedLine) {
                    print("📋 DEBUG: Найдена строка с bandwidth '\(trimmedLine)'")
                    
                    if let bandwidth = Self.extractBandwidthFromConfigLine(trimmedLine) {
                        print("📋 DEBUG: Извлечен bandwidth \(bandwidth)")
                        return bandwidth
                    }
                }
            }
            
            print("⚠️ DEBUG: Bandwidth не найден в конфиге")
        } catch {
            print("❌ Ошибка чтения конфига для bandwidth: \(error)")
        }
        
        return nil
    }
    
    // Проверяет является ли строка строкой с bandwidth
    static private func isBandwidthLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Убираем комментарии для проверки
        let cleanLine = trimmedLine.hasPrefix("#") ? 
            String(trimmedLine.dropFirst()).trimmingCharacters(in: .whitespaces) : 
            trimmedLine
        
        // Проверяем точный паттерн: строка должна содержать "bandwidth ="
        return cleanLine.lowercased().contains("bandwidth =")
    }
    
    // Извлекает значение bandwidth из строки конфига (адаптивно к комментариям и пробелам)
    static private func extractBandwidthFromConfigLine(_ line: String) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Убираем символ # в начале если он есть
        let cleanLine = trimmedLine.hasPrefix("#") ? 
            String(trimmedLine.dropFirst()).trimmingCharacters(in: .whitespaces) : 
            trimmedLine
        
        // Разбиваем по "bandwidth =" чтобы найти значение (case insensitive)
        let components = cleanLine.lowercased().components(separatedBy: "bandwidth =")
        
        guard components.count > 1 else {
            return nil
        }
        
        let bandwidthSection = components[1].trimmingCharacters(in: .whitespaces)
        
        // Берем первое слово (до пробела), которое должно быть значением L, O, P, X или числом
        let bandwidthValue = bandwidthSection.components(separatedBy: .whitespaces).first ?? bandwidthSection
        
        // Возвращаем значение в верхнем регистре
        return bandwidthValue.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Записывает значение bandwidth в конфиг (раскомментирует строку если необходимо)
    static func writeBandwidthToConfig(_ bandwidth: String) {
        let configPath = getI2pdConfigDirectory().appendingPathComponent("i2pd.conf")
        
        print("📋 DEBUG: Записываем bandwidth '\(bandwidth)' в конфиг")
        
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            print("⚠️ i2pd.conf не найден для записи bandwidth")
            return
        }
        
        do {
            let configContent = try String(contentsOf: configPath)
            let lines = configContent.components(separatedBy: .newlines)
            
            var updatedLines: [String] = []
            var bandwidthUpdated = false
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                
                // Ищем существующую строку с bandwidth (закомментированную или нет)
                if Self.isBandwidthLine(trimmedLine) {
                    // Заменяем строку на новое значение (активное)
                    let newLine = "bandwidth = \(bandwidth)"
                    updatedLines.append(newLine)
                    bandwidthUpdated = true
                    print("📋 DEBUG: Заменена строка bandwidth на: \(newLine)")
                } else {
                    // Оставляем строку без изменений
                    updatedLines.append(line)
                }
            }
            
            // Если строка bandwidth не найдена, добавляем в конец конфига
            if !bandwidthUpdated {
                updatedLines.append("") // Пустая строка для разделения
                updatedLines.append("## Bandwidth configuration")
                updatedLines.append("bandwidth = \(bandwidth)")
                print("📋 DEBUG: Добавлена новая строка bandwidth: bandwidth = \(bandwidth)")
            }
            
            // Записываем обновленный конфиг обратно в файл
            let updatedContent = updatedLines.joined(separator: "\n")
            try updatedContent.write(to: configPath, atomically: true, encoding: .utf8)
            
            print("✅ Bandwidth успешно записан в конфиг: \(bandwidth)")
            
        } catch {
            print("❌ Ошибка записи bandwidth в конфиг: \(error)")
        }
}

    // Записывает значение порта в соответствующую секцию конфига (раскомментирует строку если необходимо)
    static func writePortToConfig(port: Int, service: String) {
        let configPath = getI2pdConfigDirectory().appendingPathComponent("i2pd.conf")
        
        print("📋 DEBUG: Записываем порт \(port) для \(service) в конфиг")
        
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            print("⚠️ i2pd.conf не найден для записи порта \(service)")
            return
        }
        
        do {
            let configContent = try String(contentsOf: configPath)
            let lines = configContent.components(separatedBy: .newlines)
            
            var updatedLines: [String] = []
            var inTargetSection = false
            var currentSection = ""
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                
                // Пропускаем пустые строки
                guard !trimmedLine.isEmpty else {
                    updatedLines.append(line)
                    continue
                }
                
                // Определяем текущую секцию
                if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                    currentSection = trimmedLine.lowercased()
                    let sectionNameClean = currentSection.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    inTargetSection = sectionNameClean == service
                    updatedLines.append(line)
                    continue
                }
                
                // Ищем строку с портом в целевой секции
                if inTargetSection && Self.isPortLine(trimmedLine) {
                    // Заменяем строку на новое значение (активное)
                    let newLine = " port = \(port)"
                    updatedLines.append(newLine)
                    print("📋 DEBUG: Заменена строка порта \(service) на: \(newLine)")
                    print("📋 DEBUG: Исходная строка была: '\(line)'")
                } else {
                    // Оставляем строку без изменений
                    updatedLines.append(line)
                }
            }
            
            // Записываем обновленный конфиг обратно в файл
            let updatedContent = updatedLines.joined(separator: "\n")
            try updatedContent.write(to: configPath, atomically: true, encoding: .utf8)
            
            print("✅ Порт \(port) для \(service) успешно записан в конфиг")
            
        } catch {
            print("❌ Ошибка записи порта \(port) для \(service) в конфиг: \(error)")
        }
    }
    
    // MARK: - LaunchAgent Management
    static func createLaunchAgent() -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let launchAgentsDir = homeDir.appendingPathComponent("Library/LaunchAgents")
        let plistPath = launchAgentsDir.appendingPathComponent("com.i2pd.daemon-gui.plist")
        
        // Получаем путь к исполняемому файлу внутри .app пакета
        let appBundle = Bundle.main.bundlePath
        let executablePath = appBundle + "/Contents/MacOS/I2P Daemon GUI"
        print("📱 DEBUG: Путь к приложению: \(appBundle)")
        print("📱 DEBUG: Путь к исполняемому файлу: \(executablePath)")
        
        // Создаем LaunchAgents директорию если она не существует
        do {
            try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        } catch {
            print("❌ Ошибка создания директории LaunchAgents: \(error)")
            return false
        }
        
        // Создаем содержимое plist файла
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.i2pd.daemon-gui</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """
        
        print("📄 DEBUG: Создаем plist файл по пути: \(plistPath.path)")
        print("📄 DEBUG: Размер содержимого: \(plistContent.utf8.count) байт")
        
        do {
            try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
            print("✅ LaunchAgent создан: \(plistPath.path)")
            return true
        } catch {
            print("❌ Ошибка создания LaunchAgent: \(error)")
            return false
        }
    }
    
    static func removeLaunchAgent() -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let launchAgentsDir = homeDir.appendingPathComponent("Library/LaunchAgents")
        let plistPath = launchAgentsDir.appendingPathComponent("com.i2pd.daemon-gui.plist")
        
        do {
            if FileManager.default.fileExists(atPath: plistPath.path) {
                try FileManager.default.removeItem(at: plistPath)
                print("✅ LaunchAgent удален: \(plistPath.path)")
            } else {
                print("ℹ️ LaunchAgent файл не найден")
            }
            return true
        } catch {
            print("❌ Ошибка удаления LaunchAgent: \(error)")
            return false
        }
    }
    
    static func launchAgentExists() -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let launchAgentsDir = homeDir.appendingPathComponent("Library/LaunchAgents")
        let plistPath = launchAgentsDir.appendingPathComponent("com.i2pd.daemon-gui.plist")
        
        return FileManager.default.fileExists(atPath: plistPath.path)
    }

    // Функция для чтения настроек из реального конфига (для .onAppear)
    private func loadSettingsFromConfig() {
        let configPath = getI2pdConfigDirectory().appendingPathComponent("i2pd.conf")
        
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            print("⚠️ i2pd.conf не найден, используем порты по умолчанию")
            return
        }
        
        do {
            let configContent = try String(contentsOf: configPath)
            let lines = configContent.components(separatedBy: .newlines)
            
            var inHttpSection = false
            var inSocksSection = false
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                
                // Пропускаем пустые строки
                guard !trimmedLine.isEmpty else { continue }
                
                // Определяем текущую секцию
                if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                    let sectionName = trimmedLine.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    inHttpSection = sectionName == "httpproxy"
                    inSocksSection = sectionName == "socksproxy"
                    print("📋 DEBUG: Переход в секцию '\(sectionName)' - HTTP: \(inHttpSection), SOCKS: \(inSocksSection)")
                }
                
                // Ищем порты в соответствующих секциях
                if Self.isPortLine(trimmedLine) {
                    if inHttpSection {
                        if let portValue = Self.extractPortFromConfigLine(trimmedLine) {
                            // Активные порты имеют приоритет над закомментированными
                            if !trimmedLine.hasPrefix("#") {
                                displayDaemonPort = portValue
                                print("✅ HTTP порт загружен из конфига (активный): \(displayDaemonPort)")
                            }
                        }
                    } else if inSocksSection {
                        if let portValue = Self.extractPortFromConfigLine(trimmedLine) {
                            // Активные порты имеют приоритет над закомментированными
                            if !trimmedLine.hasPrefix("#") {
                                displaySocksPort = portValue
                                print("✅ SOCKS порт загружен из конфига (активен): \(displaySocksPort)")
                            }
                        }
                    }
                }
                
                // Ищем bandwidth в любой секции (так как он может быть в корне конфига)
                if Self.isBandwidthLine(trimmedLine) {
                    if let bandwidthValue = Self.extractBandwidthFromConfigLine(trimmedLine) {
                        // Активное значение имеет приоритет над закомментированным
                        if !trimmedLine.hasPrefix("#") {
                            displayBandwidth = bandwidthValue
                            print("✅ Bandwidth загружен из конфига (активный): \(displayBandwidth)")
                        }
                    }
                }
            }
        } catch {
            print("❌ Ошибка чтения конфига: \(error)")
        }
    }
    
    private func extractPortFromLine(_ line: String) -> Int? {
        // Парсим строку вида "port = 4444" или "# port = 4444" или "port = 4444 #комментарий"
        let cleanLine = line.trimmingCharacters(in: .whitespaces)
        
        // Убираем символ # из начала если есть
        let processedLine = cleanLine.hasPrefix("#") ? String(cleanLine.dropFirst()).trimmingCharacters(in: .whitespaces) : cleanLine
        
        let components = processedLine.components(separatedBy: "port =")
        
        if components.count > 1 {
            let portPart = components[1].trimmingCharacters(in: .whitespaces)
            // Берем значение до первого пробела (может быть комментарий)
            let portValue = portPart.components(separatedBy: .whitespaces).first ?? portPart
            return Int(portValue.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }
    @AppStorage("autoStart") private var autoStart = false
    @AppStorage("autoStartDaemon") private var autoStartDaemon = false
    @AppStorage("startMinimized") private var startMinimized = false
    @AppStorage("appLanguage") private var appLanguage = "ru"
    @AppStorage("darkMode") private var darkMode = true
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("autoLogCleanup") private var autoLogCleanup = false
    @AppStorage("hideFromDock") private var hideFromDock = false
    
    var body: some View {
        ZStack(alignment: .top) {
            LiquidGlassBackdrop(material: .underWindowBackground)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    // Сетевая конфигурация
                    SettingsSection(title: L("Сетевая конфигурация"), icon: "globe") {
                        VStack(spacing: 12) {
                            // Порт HTTP прокси (интерактивный)
                            HStack(spacing: 12) {
                                Text(L("Порт HTTP прокси"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 220, alignment: .leading)
                                
                                TextField("Порт", value: $displayDaemonPort, format: .number.grouping(.never))
                                    .textFieldStyle(.plain)
                                    .font(.system(.body, design: .monospaced, weight: .medium))
                                    .frame(width: 120)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                                
                                Button("Сохранить") {
                                    Self.writePortToConfig(port: displayDaemonPort, service: "httpproxy")
                                    showHttpPortAlert = true
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Порт SOCKS5 прокси (интерактивный)
                            HStack(spacing: 12) {
                                Text(L("Порт SOCKS5 прокси"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 220, alignment: .leading)
                                
                                TextField("Порт", value: $displaySocksPort, format: .number.grouping(.never))
                                    .textFieldStyle(.plain)
                                    .font(.system(.body, design: .monospaced, weight: .medium))
                                    .frame(width: 120)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                                
                                Button("Сохранить") {
                                    Self.writePortToConfig(port: displaySocksPort, service: "socksproxy")
                                    showSocksPortAlert = true
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Настройка пропускной способности
                            HStack(spacing: 12) {
                                Text(L("Пропускная способность"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 220, alignment: .leading)
                                
                                HStack {
                                    Menu {
                                        Button("L (32 KB/s) - " + L("Standard")) {
                                            print("🔄 Пользователь выбрал L")
                                            displayBandwidth = "L"
                                            Self.writeBandwidthToConfig("L")
                                            showBandwidthAlert = true
                                        }
                                        Button("O (256 KB/s) - " + L("Medium")) {
                                            print("🔄 Пользователь выбрал O")
                                            displayBandwidth = "O"
                                            Self.writeBandwidthToConfig("O")
                                            showBandwidthAlert = true
                                        }
                                        Button("P (2048 KB/s) - " + L("High (recommended)")) {
                                            print("🔄 Пользователь выбрал P")
                                            displayBandwidth = "P"
                                            Self.writeBandwidthToConfig("P")
                                            showBandwidthAlert = true
                                        }
                                        Button("X (unlimited) - " + L("Maximum")) {
                                            print("🔄 Пользователь выбрал X")
                                            displayBandwidth = "X"
                                            Self.writeBandwidthToConfig("X")
                                            showBandwidthAlert = true
                                        }
                                    } label: {
                                        HStack {
                                            Text("\(displayBandwidth)")
                                                .font(.system(.body, design: .monospaced, weight: .medium))
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                        }
                                            .foregroundColor(.primary)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .liquidGlassPanel(cornerRadius: 8, material: .thinMaterial, shadowOpacity: 0.03)
                                }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                        }
                    }
                    
                    // Автоматизация
                    SettingsSection(title: L("Автоматизация"), icon: "gearshape.2.fill") {
                        VStack(spacing: 16) {
                            // Показываем текущее состояние LaunchAgent
                            HStack(spacing: 12) {
                                Image(systemName: Self.launchAgentExists() ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(Self.launchAgentExists() ? .green : .gray)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L("Автозапуск приложения"))
                                        .font(.system(.body, design: .default, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text(Self.launchAgentExists() ? "Включен - приложение запускается при входе в систему" : "Отключен")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Кнопка управления LaunchAgent
                            LaunchAgentControlsView(autoStart: $autoStart)
                            
                            Divider()
                            
                            // Автозапуск демона при открытии приложения
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L("Автозапуск демона"))
                                        .font(.system(.body, design: .default, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text(autoStartDaemon ? "Демон автоматически запустится при открытии приложения" : "Демон запускается вручную")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $autoStartDaemon)
                                    .labelsHidden()
                                    .onChange(of: autoStartDaemon) { _, newValue in
                                        print("🔄 Настройка автозапуска демона изменена: \(newValue)")
                                        if newValue {
                                            manualStop? = false // Сбрасываем флаг при включении автозапуска
                                        }
                                    }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Divider()
                            
                            // Запускать приложение свернутым
                            HStack(spacing: 12) {
                                Image(systemName: "eye.slash.circle")
                                    .foregroundColor(.purple)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L("Запускать свернутым"))
                                        .font(.system(.body, design: .default, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text(startMinimized ? "Приложение откроется свернутым в трей" : "Приложение откроется с видимым окном")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $startMinimized)
                                    .labelsHidden()
                                    .onChange(of: startMinimized) { _, newValue in
                                        print("🔽 Настройка запуска свернутым изменена: \(newValue)")
                                    }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Интерфейс
                    SettingsSection(title: L("Интерфейс"), icon: "paintpalette.fill") {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L("Язык приложения"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Picker(L("Язык"), selection: $appLanguage) {
                                    Text("🇷🇺 \(NSLocalizedString("Русский", comment: "Russian"))").tag("ru")
                                    Text("🇬🇧 \(NSLocalizedString("English", comment: "English"))").tag("en")
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: .infinity)
                                .onChange(of: appLanguage) { _, newValue in
                                    changeLanguage(to: newValue)
                                }
                                
                                Text(NSLocalizedString("Изменения языка применятся после перезапуска приложения", comment: "Restart required"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("Тема приложения", comment: "App theme"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Picker("Тема приложения", selection: $darkMode) {
                                    Text(NSLocalizedString("Светлая", comment: "Light")).tag(false)
                                    Text(NSLocalizedString("Тёмная", comment: "Dark")).tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: .infinity)
                                .onChange(of: darkMode) { _, newValue in
                                    // Применяем тему сразу при изменении
                                    DispatchQueue.main.async {
                                        if newValue {
                                            NSApp.appearance = NSAppearance(named: .darkAqua)
                                        } else {
                                            NSApp.appearance = NSAppearance(named: .aqua)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L("Отображение приложения"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                HStack(spacing: 12) {
                                    Text(L("Скрыть из Dock"))
                                        .font(.system(.body, design: .default, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(minWidth: 200, alignment: .leading)
                                    
                                    Toggle("", isOn: $hideFromDock)
                                        .labelsHidden()
                                        .onChange(of: hideFromDock) { _, newValue in
                                            toggleDockVisibility(isHidden: newValue)
                                        }
                                    
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(L("При включении приложение скроется из Dock и станет доступно только через трей. ✅ Настройка восстанавливается при перезапуске."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                        }
                    }
                    
                    // Данные
                    SettingsSection(title: L("Данные"), icon: "folder.fill") {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L("Путь к данным"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                HStack {
                                    Text("~/Library/Application Support/i2pd")
                                        .foregroundColor(.secondary)
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Button(L("Изменить")) {
                                        selectDataDirectory()
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.small)
                                }
                            }
                            
                            Divider()
                            
                            VStack(spacing: 12) {
                                Button {
                                    clearDataCache()
                                } label: {
                                    Label(L("Очистить кэш"), systemImage: "trash")
                                }
                                .foregroundColor(.red)
                                .buttonStyle(.borderless)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Button {
                                    exportLogs()
                                } label: {
                                    Label(L("Экспорт логов"), systemImage: "square.and.arrow.up")
                                }
                                .foregroundColor(.blue)
                                .buttonStyle(.borderless)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    // Конфигурация и файлы
                    SettingsSection(title: L("Конфигурация"), icon: "doc.text") {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Text(L("Конфиг файл"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 200, alignment: .leading)
                                
                                Button {
                                    openConfigFile()
                                } label: {
                                    Label(L("Открыть"), systemImage: "folder")
                                }
                                .buttonStyle(.borderless)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                Text(L("Папка данных"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 200, alignment: .leading)
                                
                                Button {
                                    openLogsDirectory() // Используем логи как папку данных
                                } label: {
                                    Label(L("Открыть"), systemImage: "folder")
                                }
                                .buttonStyle(.borderless)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                Text(L("Журналы"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 200, alignment: .leading)
                                
                                Button {
                                    openLogsDirectory()
                                } label: {
                                    Label(L("Открыть"), systemImage: "doc.text")
                                }
                                .buttonStyle(.borderless)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Туннели
                    SettingsSection(title: L("Туннели"), icon: "network") {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Text(L("Управление туннелями"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 200, alignment: .leading)
                                
                                Button {
                                    openTunnelManager()
                                } label: {
                                    Label(L("Настроить"), systemImage: "slider.horizontal.3")
                                }
                                .buttonStyle(.borderless)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                Text(L("Пример туннелей"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 200, alignment: .leading)
                                
                                Button {
                                    showTunnelExamples()
                                } label: {
                                    Label(L("Показать"), systemImage: "doc.text.magnifyingglass")
                                }
                                .buttonStyle(.borderless)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Address Book
                    SettingsSection(title: L("Address Book"), icon: "book.fill") {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Text(L("Подписки adressbook"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 220, alignment: .leading)
                                
                                Button {
                                    openAddressBookSubscriptions()
                                } label: {
                                    Label(L("Редактировать"), systemImage: "pencil")
                                }
                                .buttonStyle(.borderless)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L("Текущие подписки:"))
                                    .font(.system(.body, design: .default, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text(L("• reg.i2p - Основной реестр адресов"))
                                    .font(.system(.caption, design: .default))
                                    .foregroundColor(.secondary)
                                Text(L("• identiguy.i2p - Альтернативный источник"))
                                    .font(.system(.caption, design: .default))
                                    .foregroundColor(.secondary)
                                Text(L("• stats.i2p - Статистика сети"))
                                    .font(.system(.caption, design: .default))
                                    .foregroundColor(.secondary)
                                Text(L("• i2p-projekt.i2p - Проектный источник"))
                                    .font(.system(.caption, design: .default))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Простая ссылка на GitHub
                    HStack {
                        Spacer()
                        Text("GitHub: https://github.com/MetanoicArmor/gui-i2pd")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: 980, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, 18)
                .padding(.top, 78)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.leading, 18)
            .padding(.trailing, 0)
            // Больше воздуха у скруглений окна: короче трек скролла, ползунок не лезет в радиус.
            .padding(.vertical, 14)

            SettingsTopScrollFade()
                .zIndex(0.5)

            HStack {
                Label(L("Настройки"), systemImage: "gearshape")
                    .font(.title)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Button {
                    closeSettings()
                } label: {
                    Text(L("Esc для закрытия"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help(L("Закрыть настройки"))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .liquidGlassSidebarChrome(cornerRadius: 22, tintOpacity: 0.025, shadowOpacity: 0.10)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .zIndex(1)
        }
        .liquidGlassWindow(usesTranslucentSheetChrome: true)
        .frame(minWidth: 750, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
        .onAppear {
            // Загружаем актуальные порты из конфига при открытии настроек
        print("🔄 SettingsView opened - loading ports from config...")
        loadSettingsFromConfig()
        
        // Загружаем состояние автозапуска
        if Self.launchAgentExists() {
            if !autoStart {
                autoStart = true
                print("📋 Автозапуск найден в системе, обновляем UI")
            }
        }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("NSWindowDidResignKey"))) { _ in
            // Дополнительная обработка для лучшего закрытия окна
        }
        .alert(L("Пропускная способность обновлена"), isPresented: $showBandwidthAlert) {
            Button("OK") { }
        } message: {
            Text(String(format: L("Пропускная способность изменена и сохранена в конфиг: %@"), displayBandwidth))
        }
        .alert(L("HTTP порт обновлен"), isPresented: $showHttpPortAlert) {
            Button("OK") { }
        } message: {
            Text(String(format: L("HTTP порт изменен и сохранен в конфиг: %d"), displayDaemonPort))
        }
        .alert(L("SOCKS порт обновлен"), isPresented: $showSocksPortAlert) {
            Button("OK") { }
        } message: {
            Text(String(format: L("SOCKS порт изменен и сохранен в конфиг: %d"), displaySocksPort))
        }
        .onKeyPress { keyPress in
            if keyPress.key == .escape {
                closeSettings()
                return .handled
            }
            return .ignored
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseSettings"))) { _ in
            print("📨 SettingsView получил CloseSettings - закрываем через dismiss()")
            dismiss()
        }
    }

    private func closeSettings() {
        print("🚪 Закрываем настройки")
        WindowCloseDelegate.isSettingsOpen = false
        NotificationCenter.default.post(name: NSNotification.Name("CloseSettings"), object: nil)
        dismiss()
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
        if i2pdManager.isRunning {
            let runningAlert = NSAlert()
            runningAlert.messageText = "Очистка кэша недоступна"
            runningAlert.informativeText = "Остановите i2pd daemon перед очисткой кэша."
            runningAlert.addButton(withTitle: "OK")
            runningAlert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Очистка кэша"
        alert.informativeText = "Вы уверены что хотите очистить кэш приложения? Это действие нельзя отменить."
        alert.addButton(withTitle: "Очистить")
        alert.addButton(withTitle: "Отменить")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let fileManager = FileManager.default
            let dataDir = getI2pdConfigDirectory()

            let cacheDirectories = ["netDb", "peerProfiles"]
            let removableFiles = ["i2pd.log", "i2pd.pid", "i2pd.pid.old", "router.info"]
            var removedItems: [String] = []
            var failedItems: [String] = []

            for directoryName in cacheDirectories {
                let directoryURL = dataDir.appendingPathComponent(directoryName)
                if fileManager.fileExists(atPath: directoryURL.path) {
                    do {
                        try fileManager.removeItem(at: directoryURL)
                        removedItems.append(directoryName)
                    } catch {
                        failedItems.append("\(directoryName): \(error.localizedDescription)")
                    }
                }
            }

            for fileName in removableFiles {
                let fileURL = dataDir.appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: fileURL.path) {
                    do {
                        try fileManager.removeItem(at: fileURL)
                        removedItems.append(fileName)
                    } catch {
                        failedItems.append("\(fileName): \(error.localizedDescription)")
                    }
                }
            }

            if failedItems.isEmpty {
                let summary = removedItems.isEmpty
                    ? "🧹 Кэш уже был пуст (очищать нечего)"
                    : "🧹 Кэш очищен: удалено \(removedItems.count) элементов"
                i2pdManager.logExportComplete(summary)
            } else {
                i2pdManager.logExportComplete("⚠️ Очистка кэша завершена с ошибками: \(failedItems.joined(separator: "; "))")
            }
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
    
    private func changeLanguage(to language: String) {
        print("🌐 Смена языка на: \(language)")
        
        // Сохраняем выбранный язык
        UserDefaults.standard.set(language, forKey: "appLanguage")
        UserDefaults.standard.synchronize()
        
        let languageName = language == "ru" ? "русский 🇷🇺" : "English 🇬🇧"
        i2pdManager.logExportComplete("🌐 " + L("Язык изменён на") + " \(languageName). " + L("Перезапуск приложения..."))
        
        // Умный перезапуск приложения
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.restartApplication()
        }
    }
    
    private func restartApplication() {
        // Закрываем окно настроек перед перезапуском
        if WindowCloseDelegate.isSettingsOpen {
            print("⚙️ Закрываем настройки перед перезапуском")
            NotificationCenter.default.post(name: NSNotification.Name("CloseSettings"), object: nil)
            WindowCloseDelegate.isSettingsOpen = false
            
            // Даём время на закрытие модального окна
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.performRestart()
            }
        } else {
            performRestart()
        }
    }
    
    private func performRestart() {
        // Получаем путь к приложению и PID текущего процесса
        let appPath = Bundle.main.bundlePath
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        // Устанавливаем флаг перезапуска - демон НЕ будет остановлен
        AppDelegate.isRestarting = true
        
        print("🔄 Начинаем перезапуск приложения (PID: \(currentPID))...")
        
        // Принудительно закрываем ВСЕ окна приложения
        for window in NSApplication.shared.windows {
            window.close()
        }
        
        // Создаем bash-скрипт который:
        // 1. Ждёт завершения текущего процесса
        // 2. Перезапускает приложение
        let script = """
        #!/bin/bash
        # Ждём завершения текущего процесса GUI
        while kill -0 \(currentPID) 2>/dev/null; do
            sleep 0.1
        done
        
        # Перезапускаем приложение
        echo "🔄 Перезапуск приложения..."
        open "\(appPath)"
        """
        
        // Сохраняем скрипт во временный файл
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("restart-\(UUID().uuidString).sh")
        
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            
            // Делаем скрипт исполняемым
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            
            // Запускаем скрипт в фоне (он будет ждать завершения приложения)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [scriptURL.path]
            task.standardOutput = nil
            task.standardError = nil
            try task.run()
            
            print("✅ Скрипт перезапуска запущен в фоне")
            
            // Выходим через exit(0) - НЕ вызывает applicationWillTerminate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🚪 Выход через exit(0) - демон останется работать")
                exit(0)
            }
        } catch {
            print("❌ Ошибка перезапуска: \(error)")
            AppDelegate.isRestarting = false
            i2pdManager.logExportComplete("❌ " + L("Ошибка перезапуска:") + " \(error.localizedDescription)")
        }
    }
    
    private func toggleDockVisibility(isHidden: Bool) {
        DispatchQueue.main.async {
            if isHidden {
                // Скрываем из Dock: меняем политику активации на accessory (агент)
                NSApplication.shared.setActivationPolicy(.accessory)
                
                // Скрываем основное окно
                NSApplication.shared.hide(nil)
                
                // Политика применения сохраняется через UserDefaults при перезапуске
                
                // Показываем уведомление что приложение теперь в трее
                i2pdManager.logExportComplete("📱 Приложение скрыто из Dock. Доступ через трей.")
                
            } else {
                // Показываем в Dock обратно: меняем политику на regular
                NSApplication.shared.setActivationPolicy(.regular)
                
                // Показываем основное окно
                NSApplication.shared.unhide(nil)
                
                // Политика применения сохраняется через UserDefaults при перезапуске
                
                i2pdManager.logExportComplete("📱 Приложение возвращено в Dock.")
            }
        }
    }
    
    private func openConfigFile() {
        let configPath = getI2pdConfigDirectory().appendingPathComponent("i2pd.conf")
        
        if FileManager.default.fileExists(atPath: configPath.path) {
            NSWorkspace.shared.open(configPath)
        } else {
            // Если файл не существует, создаем его с базовыми настройками
            createDefaultConfigFile(at: configPath)
        }
        
        i2pdManager.logExportComplete("📁 Открыт конфигурационный файл")
    }
    
    private func createDefaultConfigFile(at path: URL) {
        // Используем полный конфиг из bundle вместо упрощенного
        let bundle = Bundle.main
        let resourcesPath = "Contents/Resources"
        
        if let configURL = bundle.url(forResource: "i2pd", withExtension: "conf", subdirectory: resourcesPath) {
            do {
                try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: configURL, to: path)
                NSWorkspace.shared.open(path)
                i2pdManager.logExportComplete("✅ Полный i2pd.conf скопирован из бандла")
            } catch {
                print("Ошибка копирования полного конфига: \(error)")
                // Fallback к упрощенному конфигу
                createSimplifiedConfig(at: path)
            }
        } else {
            // Fallback к упрощенному конфигу если полный не найден
            createSimplifiedConfig(at: path)
        }
    }
    
    private func createSimplifiedConfig(at path: URL) {
        let defaultConfig = """
## Configuration file for I2P Router
## Generated by I2P-GUI (simplified fallback)

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
            i2pdManager.logExportComplete("⚠️ Создан упрощенный i2pd.conf")
        } catch {
            print("Ошибка создания конфига: \(error)")
        }
    }
    
    
    private func openLogsDirectory() {
        let logsDir = getI2pdConfigDirectory()
        
        if FileManager.default.fileExists(atPath: logsDir.path) {
            NSWorkspace.shared.open(logsDir)
        } else {
            // Текущая директория логов
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            NSWorkspace.shared.open(homeDir)
        }
        
        i2pdManager.logExportComplete("📋 Открыта директория логов")
    }
    
    private func openTunnelManager() {
        let tunnelsConf = getI2pdConfigDirectory().appendingPathComponent("tunnels.conf")
        
        if !FileManager.default.fileExists(atPath: tunnelsConf.path) {
            // Создаем файл с примерами туннелей
            createDefaultTunnelsFile(at: tunnelsConf)
        }
        
        NSWorkspace.shared.open(tunnelsConf)
        i2pdManager.logExportComplete("🚇 Открыт менеджер туннелей")
    }
    
    private func createDefaultTunnelsFile(at path: URL) {
        // Используем полный tunnels.conf из bundle вместо упрощенного
        let bundle = Bundle.main
        let resourcesPath = "Contents/Resources"
        
        if let tunnelsURL = bundle.url(forResource: "tunnels", withExtension: "conf", subdirectory: resourcesPath) {
            do {
                try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: tunnelsURL, to: path)
                i2pdManager.logExportComplete("✅ Полный tunnels.conf скопирован из бандла")
            } catch {
                print("Ошибка копирования полного tunnels.conf: \(error)")
                // Fallback к упрощенному файлу
                createSimplifiedTunnelsFile(at: path)
            }
        } else {
            // Fallback к упрощенному файлу если полный не найден
            createSimplifiedTunnelsFile(at: path)
        }
    }
    
    private func createSimplifiedTunnelsFile(at path: URL) {
        let defaultTunnels = """
## Туннели I2P
## Добавьте сюда ваши туннели (simplified fallback)

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
            i2pdManager.logExportComplete("⚠️ Создан упрощенный tunnels.conf")
        } catch {
            print("Ошибка создания упрощенного файла туннелей: \(error)")
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
    
    private func openAddressBookSubscriptions() {
        let subscriptionsPath = getI2pdConfigDirectory().appendingPathComponent("subscriptions.txt")
        
        if FileManager.default.fileExists(atPath: subscriptionsPath.path) {
            NSWorkspace.shared.open(subscriptionsPath)
        } else {
            // Если файл не существует, создаем его из bundle
            createDefaultSubscriptionsFile(at: subscriptionsPath)
        }
        
        i2pdManager.logExportComplete("📖 Открыт файл подписок address book")
    }
    
    private func createDefaultSubscriptionsFile(at path: URL) {
        // Используем полный subscriptions.txt из bundle вместо пустого
        let bundle = Bundle.main
        let resourcesPath = "Contents/Resources"
        
        if let subscriptionsURL = bundle.url(forResource: "subscriptions", withExtension: "txt", subdirectory: resourcesPath) {
            do {
                try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: subscriptionsURL, to: path)
                NSWorkspace.shared.open(path)
                i2pdManager.logExportComplete("✅ Полный subscriptions.txt скопирован из бандла")
            } catch {
                print("Ошибка копирования полного subscriptions.txt: \(error)")
                // Fallback к созданию пустого файла
                createEmptySubscriptionsFile(at: path)
            }
        } else {
            // Fallback к созданию пустого файла если полный не найден
            createEmptySubscriptionsFile(at: path)
        }
    }
    
    private func createEmptySubscriptionsFile(at path: URL) {
        let defaultSubscriptions = """
http://reg.i2p/hosts.txt
http://identiguy.i2p/hosts.txt
http://stats.i2p/cgi-bin/newhosts.txt
http://i2p-projekt.i2p/hosts.txt

"""
        
        do {
            try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            try defaultSubscriptions.write(to: path, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(path)
            i2pdManager.logExportComplete("⚠️ Создан базовый subscriptions.txt")
        } catch {
            print("Ошибка создания файла подписок: \(error)")
        }
    }
}

// MARK: - Settings Scroll Chrome
private struct SettingsTopScrollFade: View {
    @Environment(\.colorScheme) private var colorScheme

    private var shade: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        VStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            shade.opacity(0.16),
                            shade.opacity(0.08),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 104)

            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .liquidGlassHeader()
            
            // Содержимое секции
            VStack(spacing: 12) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .liquidGlassPanel(cornerRadius: 16, material: .thinMaterial, tintOpacity: 0.024, shadowOpacity: 0.06)
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
    let daemonVersion: String

    private var versionLabel: Text {
        Text(String(format: NSLocalizedString("i2pd v%@", comment: "i2pd version label"), daemonVersion))
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            statusWideRow
            statusCompactColumn
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 76, alignment: .center)
        .liquidGlassPanel(cornerRadius: 20, material: .regularMaterial)
    }

    private var statusIndicatorBlock: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isRunning ? Color.green : Color.red)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(isRunning ? L("Запущен") : L("Остановлен"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Text(isRunning ? L("Статус: активен") : L("Статус: неактивен"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var uptimeBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L("Время работы"))
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
    }

    private var peersBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L("Подключения"))
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
    }

    private var statusWideRow: some View {
        HStack(spacing: 32) {
            statusIndicatorBlock
            uptimeBlock
            peersBlock
            Spacer()
            versionLabel
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var statusCompactColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                statusIndicatorBlock
                Spacer(minLength: 8)
                versionLabel
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.trailing)
            }
            HStack(alignment: .top, spacing: 20) {
                uptimeBlock
                peersBlock
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Control Buttons
struct ControlButtons: View {
    @ObservedObject var i2pdManager: I2pdManager
    @Binding var showingSettings: Bool
    @Binding var showingTools: Bool
    @Binding var manualStop: Bool?

    var body: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    restartButton
                    startStopButton
                    refreshStatusButton
                }
                VStack(spacing: 10) {
                    startStopButton
                    HStack(spacing: 10) {
                        restartButton
                        refreshStatusButton
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    settingsButton
                    toolsButton
                    trayButton
                    webConsoleButton
                }
                HStack(spacing: 8) {
                    settingsButton.labelStyle(.iconOnly).help(L("Настройки"))
                    toolsButton.labelStyle(.iconOnly).help(L("Утилиты"))
                    trayButton.labelStyle(.iconOnly).help(L("Свернуть в трей"))
                    webConsoleButton.labelStyle(.iconOnly).help(L("Веб-консоль"))
                }
                // Когда у компактного ряда показываются ТОЛЬКО иконки, делаем
                // их чуть крупнее: текстового якоря рядом нет, и стандартного
                // SF Symbol-а в кнопке зрительно мало.
                .imageScale(.large)
                .font(.system(size: 17, weight: .medium))
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        settingsButton
                        toolsButton
                    }
                    HStack(spacing: 10) {
                        trayButton
                        webConsoleButton
                    }
                }
            }
        }
        .padding(12)
        .liquidGlassPanel(cornerRadius: 18, material: .thinMaterial)
    }

    private var restartButton: some View {
        Button {
            manualStop = false
            i2pdManager.restartDaemon()
        } label: {
            Label(NSLocalizedString("Перезапустить", comment: "Restart button"), systemImage: "arrow.clockwise")
                .frame(height: 36)
                .frame(maxWidth: .infinity)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.9)
        .disabled(i2pdManager.isLoading || !i2pdManager.isRunning)
    }

    private var startStopButton: some View {
        Button {
            if i2pdManager.isRunning {
                manualStop = true
                i2pdManager.stopDaemon()
            } else {
                manualStop = false
                i2pdManager.startDaemon()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: i2pdManager.isRunning ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 16))
                Text(i2pdManager.isRunning ? NSLocalizedString("Остановить", comment: "Stop") : NSLocalizedString("Запустить", comment: "Start"))
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
    }

    private var refreshStatusButton: some View {
        Button {
            i2pdManager.checkStatus()
        } label: {
            Label(L("Обновить статус"), systemImage: "arrow.triangle.2.circlepath")
                .frame(height: 36)
                .frame(maxWidth: .infinity)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.9)
        .disabled(i2pdManager.isLoading)
    }

    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            Label(L("Настройки"), systemImage: "gearshape")
                .frame(height: 36)
                .frame(maxWidth: .infinity)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.9)
    }

    private var toolsButton: some View {
        Button {
            showingTools = true
        } label: {
            Label(L("Утилиты"), systemImage: "wrench.and.screwdriver")
                .frame(height: 36)
                .frame(maxWidth: .infinity)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.9)
    }

    private var trayButton: some View {
        Button {
            TrayManager.shared.hideMainWindow()
        } label: {
            Label(L("Свернуть в трей"), systemImage: "menubar.arrow.down.rectangle")
                .frame(height: 36)
                .frame(maxWidth: .infinity)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.9)
    }

    private var webConsoleButton: some View {
        Button {
            guard i2pdManager.isRunning else {
                i2pdManager.logExportComplete("⚠️ Сначала запустите daemon для открытия веб-консоли")
                return
            }
            if let webURL = URL(string: "http://127.0.0.1:7070") {
                NSWorkspace.shared.open(webURL)
                i2pdManager.logExportComplete("🌐 Открыта веб-консоль")
            }
        } label: {
            Label(L("Веб-консоль"), systemImage: "safari")
                .frame(height: 36)
                .frame(maxWidth: .infinity)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.9)
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
            .liquidGlassPanel(cornerRadius: 14, material: .regularMaterial, shadowOpacity: 0.04)
        }
        .frame(maxHeight: 300)
        .onKeyPress(.escape) {
            // Отправляем уведомление для закрытия настроек
            NotificationCenter.default.post(name: NSNotification.Name("CloseSettings"), object: nil)
            return .handled
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
        .liquidGlassPanel(cornerRadius: 12, material: .thinMaterial, shadowOpacity: 0.04)
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
    @Published var tunnelCreationSuccessRate = "—"
    @Published var routerInfos = 0
    @Published var floodfills = 0
    @Published var leaseSets = 0
    @Published var routerCaps = "—"
    @Published var daemonVersion: String = "—"
    
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
    private var i2pdPID: Int32?
    private var daemonPID: Int32?
    private var logTimer: Timer?
    private var logCleanupTimer: Timer?
    
    private let executablePath: String

    private struct NetworkStatsSnapshot {
        var uptime: String? = nil
        var bytesReceived: Int? = nil
        var bytesSent: Int? = nil
        var activeTunnels: Int? = nil
        var tunnelCreationSuccessRate: String? = nil
        var peerCount: Int? = nil
        var routerInfos: Int? = nil
        var floodfills: Int? = nil
        var leaseSets: Int? = nil
        var routerCaps: String? = nil

        mutating func fillMissing(from fallback: NetworkStatsSnapshot) {
            uptime = uptime ?? fallback.uptime
            bytesReceived = bytesReceived ?? fallback.bytesReceived
            bytesSent = bytesSent ?? fallback.bytesSent
            activeTunnels = activeTunnels ?? fallback.activeTunnels
            tunnelCreationSuccessRate = tunnelCreationSuccessRate ?? fallback.tunnelCreationSuccessRate
            peerCount = peerCount ?? fallback.peerCount
            routerInfos = routerInfos ?? fallback.routerInfos
            floodfills = floodfills ?? fallback.floodfills
            leaseSets = leaseSets ?? fallback.leaseSets
            routerCaps = routerCaps ?? fallback.routerCaps
        }
    }
    
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
            self?.addLog(.debug, L("🔧 Инициализация I2pdManager"))
            self?.addLog(.debug, L("📍 Bundle path:") + "  \(bundlePath)")
            self?.addLog(.debug, L("🎯 Ресурсный путь:") + "  \(resourcePath)")
            self?.addLog(.debug, L("✅ Финальный путь:") + "  \(self?.executablePath ?? "не найден")")
            self?.addLog(.debug, "🔍 " + L("Файл существует:") + "  \(FileManager.default.fileExists(atPath: self?.executablePath ?? "") ? "✅ " + L("да") : "❌ " + L("нет"))")
        }
        
        // Подписываемся на уведомления от трея
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DaemonStarted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Немедленно обновляем иконку трея
            TrayManager.shared.updateMenuState(isRunning: true)
            self?.addLog(.info, L("📱 Daemon запущен - иконка трея обновлена"))
            
            // Обновляем статус с небольшой задержкой
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.checkStatus()
                self?.fetchDaemonVersion()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DaemonStopped"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Немедленно обновляем иконку трея
            TrayManager.shared.updateMenuState(isRunning: false)
            self?.addLog(.info, L("📱 Daemon остановлен - иконка трея обновлена"))
            
            // Обновляем статус с небольшой задержкой
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.checkStatus()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("StatusUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.addLog(.info, L("📱 Статус обновлен из трея"))
            self?.checkStatus()
            self?.fetchDaemonVersionIfNeeded()
        }
    }
    
    func startDaemon() {
        addLog(.debug, "🔍 startDaemon() вызван - начинаем запуск")
        
        guard !operationInProgress else {
            addLog(.warn, L("Операция уже выполняется, пропускаем..."))
            return
        }
        operationInProgress = true
        isLoading = true
        addLog(.info, L("Запуск I2P daemon..."))
        addLog(.debug, L("🔄 Пытаемся запустить daemon..."))
        addLog(.debug, L("📍 Путь к бинарнику:") + "  \(executablePath)")
        addLog(.debug, L("🔍 Проверка существования:") + "  \(FileManager.default.fileExists(atPath: executablePath))")
        
        guard FileManager.default.fileExists(atPath: executablePath) else {
            addLog(.error, L("❌ Бинарник i2pd не найден по пути:") + " \(executablePath)")
            isLoading = false
            operationInProgress = false
            return
        }
        
        addLog(.debug, L("✅ Бинарник найден, продолжаем запуск"))
        
        // Проверяем, не запущен ли уже процесс
        if isRunning {
            addLog(.warn, L("I2P daemon уже запущен"))
            isLoading = false
            operationInProgress = false
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.executeI2pdCommand(["--daemon"])
        }
    }
    
    func stopDaemon() {
        addLog(.info, L("🚫 ОСТАНОВКА ДЕМОНА ИЗ I2pdManager НАЧАТА!"))
        addLog(.debug, "🔍 stopDaemon() вызван - начинаем остановку")
        
        guard !operationInProgress else {
            addLog(.warn, "⚠️ Операция уже выполняется, пропускаем...")
            return
        }
        
        addLog(.debug, L("✅ Блокировка операций установлена"))
        operationInProgress = true
        isLoading = true
        addLog(.info, L("🛑 Остановка I2P daemon через kill -s INT..."))
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.stopDaemonProcess()
            
            // Обновляем состояние в UI после остановки
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.isLoading = false
                self?.operationInProgress = false
                self?.addLog(.info, L("✅ Демон остановлен"))
            }
        }
    }
    
    func restartDaemon() {
        addLog(.info, L("🔄 ПЕРЕЗАПУСК ДЕМОНА ИЗ I2pdManager НАЧАТ!"))
        
        // Уведомляем трей о начале перезапуска
        NotificationCenter.default.post(name: NSNotification.Name("DaemonRestarting"), object: nil)
        
        // Устанавливаем флаг операции для перезапуска
        operationInProgress = true
        isLoading = true
        
        // Останавливаем демон напрямую без установки operationInProgress
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.stopDaemonProcess()
            
            // Обновляем состояние после остановки
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.addLog(.info, L("✅ Демон остановлен, начинаем запуск..."))
                
                // Ждем немного перед перезапуском
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    // Сбрасываем флаг операции перед запуском
                    self?.operationInProgress = false
                    self?.startDaemon()
                    
                    // Уведомляем трей о завершении перезапуска
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        NotificationCenter.default.post(name: NSNotification.Name("DaemonRestartComplete"), object: nil)
                    }
                }
            }
        }
    }
    
    private func stopDaemonProcess() {
        addLog(.debug, L("🛑 Начинаем прямую остановку демона..."))
        
        // ПРОСТОЙ И НАДЕЖНЫЙ поиск и остановка демона
        let simpleStopCommand = """
        echo "🔍 Поиск демона i2pd..." &&
        DEMON_PID=$(ps aux | grep "i2pd.*daemon" | grep -v grep | awk '{print $2}' | head -1) &&
        
        if [ -n "$DEMON_PID" ]; then
            echo "✅ Найден демон с PID: $DEMON_PID" &&
            echo "💀 Останавливаем демон через kill -s INT..." &&
            kill -s INT $DEMON_PID 2>/dev/null &&
        sleep 2 &&
            kill -s TERM $DEMON_PID 2>/dev/null &&
            sleep 1 &&
            kill -KILL $DEMON_PID 2>/dev/null &&
        
            # Проверка результата
        sleep 1 &&
            if ps -p $DEMON_PID >/dev/null 2>&1; then
                echo "❌ Демон всё ещё жив!"
            else
                echo "✅ Демон успешо остановлен!"
            fi
        else
            echo "⚠️ Демон не найден"
        fi
        """
        
        executeStopCommand(simpleStopCommand)
    }
    
    private func findDaemonChildProcesses() {
        // РАЗВЕРНУТЫЙ поиск демона с подробной диагностикой
        let findCommand = """
        echo "🔍 ДЕТАЛЬНЫЙ ПОИСК ДЕМОНА..." &&
        echo "📋 Все процессы с i2pd:" &&
        ps aux | grep i2pd | grep -v grep &&
        echo "" &&
        echo "📋 Демоны с --daemon:" &&
        ps aux | grep "i2pd.*daemon" | grep -v grep &&
        echo "" &&
        echo "📋 Точный поиск демона:" &&
        ps aux | grep "i2pd.*--daemon" | grep -v grep &&
        echo "" &&
        echo "🎯 ПОЛУЧЕНИЕ PID:" &&
        ps aux | grep "i2pd.*--daemon" | grep -v grep | awk '{print $2}' | head -1
        """
        
        addLog(.debug, L("🔍 Запускаем подробный поиск демона..."))
        
        let findProcess = Process()
        findProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        findProcess.arguments = ["-c", findCommand]
        
        let pipe = Pipe()
        findProcess.standardOutput = pipe
        
        do {
            try findProcess.run()
            findProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
    
            DispatchQueue.main.async { [weak self] in
                if let output = output {
                    print("🔍 Результат поиска PID: \(output)")
                    
                    let lines = output.components(separatedBy: "\n")
                    
                    // ПРОСТОЙ И НАДЕЖНЫЙ поиск PID
                    var foundPid: Int32?
                    
                    // Ищем строку с "ПОЛУЧЕНИЕ PID:" и извлекаем число из следующего элемента
                    for (index, line) in lines.enumerated() {
                        if line.contains("ПОЛУЧЕНИЕ PID:") {
                            // Берем следующую строку после "ПОЛУЧЕНИЕ PID:"
                            if index + 1 < lines.count {
                                let nextLine = lines[index + 1]
                                if let pid = Int32(nextLine.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                    foundPid = pid
                                    break
                                }
                            }
                            // Попробуем также найти в той же строке
                            let components = line.components(separatedBy: " ")
                            for component in components {
                                if let pid = Int32(component.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                    foundPid = pid
                                    break
                                }
                            }
                            break
                        }
                    }
                    
                    if let pid = foundPid {
                        self?.daemonPID = pid
                        self?.addLog(.debug, L("✅ Найден реальный PID демона:") + " \(pid)")
                    } else {
                        self?.addLog(.debug, L("⚠️ Не удалось найти PID в выводе:") + " \(lines)")
                    }
                } else {
                    self?.addLog(.debug, L("⚠️ Пустой вывод поиска PID"))
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.addLog(.error, L("Ошибка поиска PID демона:") + " \(error)")
            }
        }
    }
    
    private var globalStopCommand: String {
        return """
        echo "🔍 БЕЗОПАСНАЯ остановка только демона i2pd..." &&
        
        # Показываем только процессы демона (не GUI!)
        echo "📋 Найденные процессы ДЕМОНА i2pd:" &&
        ps aux | grep "i2pd.*daemon" | grep -v grep &&
        
        # БЕЗОПАСНЫЙ Метод 1: остановка только демона с --daemon
        echo "🛑 Метод 1: pkill только демона..." &&
        pkill -INT -f "i2pd.*--daemon" 2>/dev/null || true &&
        sleep 3 &&
        
        echo "💀 Метод 2: pkill KILL только демона..." &&
        pkill -KILL -f "i2pd.*--daemon" 2>/dev/null || true &&
        sleep 1 &&
        
        # БЕЗОПАСНЫЙ Метод 3: остановка по точному имени процесса демона
        echo "⚰️ Метод 3: killall только существующих демонов..." &&
        (ps aux | grep "i2pd.*daemon" | grep -v grep >/dev/null && killall -INT i2pd 2>/dev/null || true) &&
        sleep 1 &&
        (ps aux | grep "i2pd.*daemon" | grep -v grep >/dev/null && killall -KILL i2pd 2>/dev/null || true) &&
        sleep 1 &&
        
        # БЕЗОПАСНЫЙ Метод 4: поиск и kill ТОЛЬКО демонов
        echo "🎯 Метод 4: поиск и kill только демонов..." &&
        ps aux | grep "i2pd.*daemon" | grep -v grep | awk '{print $2}' | xargs -I {} kill -TERM {} 2>/dev/null || true &&
        sleep 1 &&
        ps aux | grep "i2pd.*daemon" | grep -v grep | awk '{print $2}' | xargs -I {} kill -KILL {} 2>/dev/null || true &&
        sleep 2 &&
        
        # Финальная проверка ТОЛЬКО демонов
        DEMON_COUNT=$(ps aux | grep "i2pd.*daemon" | grep -v grep | wc -l | tr -d ' ') &&
        if [ "$DEMON_COUNT" -eq 0 ]; then
            echo "✅ ДЕМОНЫ i2pd ПОЛНОСТЬЮ остановлены!" &&
            echo "✅ GUI приложение НЕ должно пострадать!"
        else
            echo "❌ ДЕМОНЫ не останавливаются! ($DEMON_COUNT шт.)" &&
            echo "Оставшиеся демоны:" &&
            ps aux | grep "i2pd.*daemon" | grep -v grep
        fi
        """
    }
    
    private func executeStopCommand(_ command: String) {
        addLog(.debug, L("🚀 Запускаем команду остановки демона..."))
        addLog(.debug, "🔍 Команда остановки: \(command)")
        
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        killProcess.arguments = ["-c", command]
        
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
                    self?.addLog(.info, L("Daemon остановлен"))
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
                self?.addLog(.error, L("Ошибка остановки daemon:") + " \(error.localizedDescription)")
                self?.isLoading = false
                self?.operationInProgress = false
            }
        }
    }
    
    func checkStatus() {
        isLoading = true
        addLog(.info, L("Проверка статуса..."))
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.checkDaemonStatus()
        }
    }
    
    func clearLogs() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.addLog(.info, L("Логи очищены"))
        }
    }
    
    func logExportComplete(_ path: String) {
        DispatchQueue.main.async { [weak self] in
            self?.addLog(.info, L("📄 Статистика экспортирована:") + " \(path)")
        }
    }
    
    func getExtendedStats() {
        refreshNetworkStats(shouldLog: true)
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
                self?.i2pdPID = process.processIdentifier
                self?.addLog(.debug, L("🚀 Команда запущена:") + " \(self?.executablePath ?? "unknown") \(arguments.joined(separator: " ")) " + L("с PID:") + " \(process.processIdentifier)")
                
                // Для daemon режима также ищем дочерние процессы
                if arguments.contains("--daemon") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.findDaemonChildProcesses()
                    }
                }
            }
            
            // Читаем вывод команды
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { [weak self] in
                    let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedOutput.isEmpty {
                        self?.addLog(.info, L("📝 Вывод команды:") + " \(trimmedOutput)")
                    }
                }
            }
            
            process.waitUntilExit()
            
            DispatchQueue.main.async { [weak self] in
                self?.addLog(.debug, L("✅ Процесс завершен с кодом:") + " \(process.terminationStatus)")
                self?.isLoading = false
                self?.operationInProgress = false
                
                // Обновляем статус после завершения команды
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.addLog(.debug, "🔄 " + L("Checking daemon status..."))
                    self?.checkDaemonStatus()
                }
            }
            
            // Проверяем статус после выполнения команды
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.checkDaemonStatus()
            }
            
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.addLog(.error, L("Ошибка выполнения команды:") + " \(error.localizedDescription)")
                self?.isLoading = false
                self?.operationInProgress = false
            }
        }
    }
    
    private func checkDaemonStatus() {
        addLog(.debug, "🔍 checkDaemonStatus() вызван - проверяем статус демона")
        
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
                let currentStatus = self?.isRunning ?? false
                
                // ВСЕГДА синхронизируем трей с текущим статусом
                TrayManager.shared.updateMenuState(isRunning: currentStatus)
                
                if currentStatus != wasRunning {
                    let status = currentStatus ? L("started") : L("stopped")
                    self?.addLog(.info, L("Daemon") + " \(status)")
                    
                    // Отправляем уведомления об изменении состояния демона
                    if currentStatus {
                        NotificationCenter.default.post(name: NSNotification.Name("DaemonStarted"), object: nil)
                    } else {
                        NotificationCenter.default.post(name: NSNotification.Name("DaemonStopped"), object: nil)
                    }
                }
                
                self?.isLoading = false
                self?.operationInProgress = false
                
                if currentStatus {
                    self?.startStatusMonitoring()
                } else {
                    self?.stopStatusMonitoring()
                }
            }
            
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.addLog(.error, L("Ошибка проверки статуса:") + " \(error.localizedDescription)")
                self?.isLoading = false
                self?.operationInProgress = false
            }
        }
    }
    
    // Новая функция для проверки статуса с учетом флага manualStop
    private func checkDaemonStatusWithManualStopFlag() {
        NotificationCenter.default.post(name: NSNotification.Name("GetManualStopFlag"), object: nil)
        
        checkDaemonStatus()
    }
    
    private func startStatusMonitoring() {
        guard logTimer == nil else {
            updateStatus()
            fetchDaemonVersionIfNeeded()
            return
        }

        // Обновляем статистику каждые 5 секунд
        logTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
            self?.fetchDaemonVersionIfNeeded()
        }
        
        // Обновляем статистику сразу
        updateStatus()
        fetchDaemonVersionIfNeeded()
    }
    
    private func stopStatusMonitoring() {
        logTimer?.invalidate()
        logTimer = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.resetNetworkStats(shouldLog: true)
        }
    }
    
    // MARK: - Автоматическое обновление
    func enableAutoRefresh() {
        addLog(.info, "🔄 Автообновление включено (каждые 5 секунд)")
    }
    
    func disableAutoRefresh() {
        addLog(.info, "⏸️ Автообновление отключено")
    }
    
    // MARK: - Автоматическая очистка логов
    func enableAutoLogCleanup() {
        addLog(.info, "🧹 Автоочистка логов включена")
        guard logCleanupTimer == nil else { return }

        // Автоматически очищаем логи старше 1 часа каждые 10 минут
        logCleanupTimer = Timer.scheduledTimer(withTimeInterval: 600.0, repeats: true) { [weak self] _ in
            self?.performAutoLogCleanup()
        }
    }

    func disableAutoLogCleanup() {
        logCleanupTimer?.invalidate()
        logCleanupTimer = nil
        addLog(.info, "⏸️ Автоочистка логов отключена")
    }
    
    private func performAutoLogCleanup() {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let oldLogsCount = logs.count
        logs = logs.filter { $0.timestamp >= oneHourAgo }
        let removedCount = oldLogsCount - logs.count
        if removedCount > 0 {
            addLog(.info, "🧹 Автоочистка: удалено \(removedCount) старых записей логов")
        }
    }
    
    private func updateStatus() {
        refreshNetworkStats(shouldLog: false)
    }

    private func refreshNetworkStats(shouldLog: Bool) {
        let daemonIsRunning = isRunning

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }

            guard daemonIsRunning else {
                DispatchQueue.main.async {
                    self.resetNetworkStats(shouldLog: shouldLog)
                }
                return
            }

            let stats = self.loadNetworkStatsSnapshot()

            DispatchQueue.main.async {
                guard self.isRunning else {
                    self.resetNetworkStats(shouldLog: shouldLog)
                    return
                }

                self.applyNetworkStats(stats)

                if shouldLog {
                    self.addLog(.info, L("📊 Расширенная статистика обновлена"))
                }
            }
        }
    }

    private func resetNetworkStats(shouldLog: Bool) {
        uptime = "00:00:00"
        bytesReceived = 0
        bytesSent = 0
        activeTunnels = 0
        tunnelCreationSuccessRate = "—"
        peerCount = 0
        routerInfos = 0
        floodfills = 0
        leaseSets = 0
        routerCaps = "—"

        if shouldLog {
            addLog(.info, L("📊 Статистика сброшена (daemon остановлен)"))
        }
    }

    private func applyNetworkStats(_ stats: NetworkStatsSnapshot) {
        uptime = stats.uptime ?? uptime
        bytesReceived = stats.bytesReceived ?? bytesReceived
        bytesSent = stats.bytesSent ?? bytesSent
        activeTunnels = stats.activeTunnels ?? 0
        tunnelCreationSuccessRate = stats.tunnelCreationSuccessRate ?? "—"
        peerCount = stats.peerCount ?? 0
        routerInfos = stats.routerInfos ?? stats.peerCount ?? 0
        floodfills = stats.floodfills ?? 0
        leaseSets = stats.leaseSets ?? 0
        routerCaps = stats.routerCaps ?? "—"
    }

    private func loadNetworkStatsSnapshot() -> NetworkStatsSnapshot {
        var stats = fetchNetworkStatsFromWebConsole() ?? NetworkStatsSnapshot()

        if stats.peerCount == nil || stats.floodfills == nil || stats.routerInfos == nil {
            stats.fillMissing(from: readNetDbStats())
        }

        if stats.routerCaps == nil {
            stats.routerCaps = readRouterCapsFromRouterInfo()
        }

        return stats
    }

    private func fetchNetworkStatsFromWebConsole() -> NetworkStatsSnapshot? {
        guard let url = URL(string: "http://127.0.0.1:7070/"),
              let html = synchronousFetchString(url: url, timeout: 2.0) else {
            return nil
        }

        return parseWebConsoleStats(html)
    }

    private func parseWebConsoleStats(_ html: String) -> NetworkStatsSnapshot {
        var stats = NetworkStatsSnapshot()

        if let rawUptime = firstRegexCapture(in: html, pattern: "<b>\\s*Uptime:\\s*</b>\\s*([^<]+)<br>") {
            stats.uptime = formatUptime(rawUptime)
        }

        if let successRate = firstRegexCapture(in: html, pattern: "<b>\\s*Tunnel creation success rate:\\s*</b>\\s*([0-9]+%)") {
            stats.tunnelCreationSuccessRate = successRate
        }

        if let received = firstRegexCapture(in: html, pattern: "<b>\\s*Received:\\s*</b>\\s*([^<\\(]+)") {
            stats.bytesReceived = parseByteAmount(received)
        }

        if let sent = firstRegexCapture(in: html, pattern: "<b>\\s*Sent:\\s*</b>\\s*([^<\\(]+)") {
            stats.bytesSent = parseByteAmount(sent)
        }

        let clientTunnels = firstRegexCapture(in: html, pattern: "<b>\\s*Client Tunnels:\\s*</b>\\s*([0-9]+)").flatMap(Int.init)
        let transitTunnels = firstRegexCapture(in: html, pattern: "<b>\\s*Transit Tunnels:\\s*</b>\\s*([0-9]+)").flatMap(Int.init)

        if clientTunnels != nil || transitTunnels != nil {
            stats.activeTunnels = (clientTunnels ?? 0) + (transitTunnels ?? 0)
        }

        if let routers = firstRegexCapture(in: html, pattern: "<b>\\s*Routers:\\s*</b>\\s*([0-9]+)").flatMap(Int.init) {
            stats.peerCount = routers
            stats.routerInfos = routers
        }

        if let floodfills = firstRegexCapture(in: html, pattern: "<b>\\s*Floodfills:\\s*</b>\\s*([0-9]+)").flatMap(Int.init) {
            stats.floodfills = floodfills
        }

        if let leaseSets = firstRegexCapture(in: html, pattern: "<b>\\s*LeaseSets:\\s*</b>\\s*([0-9]+)").flatMap(Int.init) {
            stats.leaseSets = leaseSets
        }

        if let caps = firstRegexCapture(in: html, pattern: "<b>\\s*Router Caps:\\s*</b>\\s*([^<\\s]+)") {
            stats.routerCaps = caps.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return stats
    }

    private func readNetDbStats() -> NetworkStatsSnapshot {
        let netDbURL = getI2pdConfigDirectory().appendingPathComponent("netDb")
        guard let enumerator = FileManager.default.enumerator(
            at: netDbURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return NetworkStatsSnapshot()
        }

        var routers = 0
        var floodfills = 0

        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent.hasPrefix("routerInfo-"),
                  (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }

            routers += 1

            if let data = try? Data(contentsOf: fileURL),
               let caps = lastRouterInfoProperty(named: "caps", in: data),
               caps.contains("f") {
                floodfills += 1
            }
        }

        return NetworkStatsSnapshot(peerCount: routers, routerInfos: routers, floodfills: floodfills)
    }

    private func parseByteAmount(_ text: String) -> Int? {
        let normalized = text
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let captures = regexCaptures(
            in: normalized,
            pattern: "([0-9]+(?:\\.[0-9]+)?)\\s*([KMGT]?i?B|[KMGT]?B|B)"
        ),
        captures.count == 2,
        let value = Double(captures[0]) else {
            return nil
        }

        let unit = captures[1].lowercased()
        let multiplier: Double

        switch unit {
        case "kib", "kb":
            multiplier = 1024
        case "mib", "mb":
            multiplier = 1024 * 1024
        case "gib", "gb":
            multiplier = 1024 * 1024 * 1024
        case "tib", "tb":
            multiplier = 1024 * 1024 * 1024 * 1024
        default:
            multiplier = 1
        }

        return Int((value * multiplier).rounded())
    }

    private func formatUptime(_ text: String) -> String {
        guard let seconds = parseDurationSeconds(text) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
    }

    private func parseDurationSeconds(_ text: String) -> Int? {
        let units: [(String, Int)] = [
            ("day", 86_400),
            ("hour", 3_600),
            ("minute", 60),
            ("second", 1)
        ]

        var total = 0

        for (unit, multiplier) in units {
            if let value = firstRegexCapture(in: text, pattern: "(\\d+)\\s*\(unit)s?").flatMap(Int.init) {
                total += value * multiplier
            }
        }

        return total > 0 ? total : nil
    }

    private func readRouterCapsFromRouterInfo() -> String? {
        let routerInfoURL = getI2pdConfigDirectory().appendingPathComponent("router.info")
        guard let data = try? Data(contentsOf: routerInfoURL),
              let caps = lastRouterInfoProperty(named: "caps", in: data) else {
            return nil
        }

        return caps.isEmpty ? nil : caps
    }

    private func lastRouterInfoProperty(named name: String, in data: Data) -> String? {
        let bytes = Array(data)
        let marker = Array("\(name)=".utf8)
        guard !marker.isEmpty, bytes.count >= marker.count else { return nil }

        var lastValue: String?
        var index = bytes.startIndex

        while index <= bytes.count - marker.count {
            if bytes[index..<index + marker.count].elementsEqual(marker) {
                let valueStart = index + marker.count
                var valueEnd = valueStart

                while valueEnd < bytes.count, bytes[valueEnd] != 0x3b {
                    valueEnd += 1
                }

                let valueBytes = bytes[valueStart..<valueEnd].filter { $0 >= 0x20 && $0 < 0x7f }
                lastValue = String(bytes: valueBytes, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                index = valueEnd
            } else {
                index += 1
            }
        }

        return lastValue
    }

    // MARK: - Версия демона
    private func fetchDaemonVersionIfNeeded() {
        guard isRunning else { return }
        if daemonVersion == "—" || daemonVersion.isEmpty {
            fetchDaemonVersion()
        }
    }

    func fetchDaemonVersion() {
        // 1) Пытаемся получить из веб‑консоли: http://127.0.0.1:7070/about или /version
        // У i2pd нет стабильного JSON API веб‑консоли, поэтому используем парсинг HTML как бэкап.
        // 2) Бэкап: через бинарник `i2pd --version`.
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            if let version = self.fetchVersionFromWebConsole() ?? self.fetchVersionFromBinary() {
                DispatchQueue.main.async {
                    self.daemonVersion = version
                    self.addLog(.info, "🔎 " + L("Daemon version:") + " v\(version)")
                }
            }
        }
    }

    private func fetchVersionFromWebConsole() -> String? {
        let candidates = [
            "http://127.0.0.1:7070/",
            "http://127.0.0.1:7070/?lang=en",
            "http://127.0.0.1:7070/?lang=ru"
        ]
        for urlString in candidates {
            guard let url = URL(string: urlString) else { continue }
            if let html = synchronousFetchString(url: url) {
                if let match = firstRegexCapture(in: html, pattern: "(?:i2pd\\s+version\\s+|i2pd\\s+v)(\\d+\\.\\d+(?:\\.\\d+)?)") {
                    return match
                }
            }
        }
        return nil
    }

    private func fetchVersionFromBinary() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if let match = firstRegexCapture(in: output, pattern: "i2pd\\s+version\\s+(\\d+\\.\\d+(?:\\.\\d+)?)") { return match }
        } catch {
            addLog(.error, "Не удалось получить версию из бинарника: \(error.localizedDescription)")
        }
        return nil
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
        // Получаем путь к директории конфигурации
        let i2pdDir = getI2pdConfigDirectory()
        
        // Создаем директорию конфигурации если ее нет
        try? FileManager.default.createDirectory(at: i2pdDir, withIntermediateDirectories: true)
        
        let bundle = Bundle.main
        
        // Копируем subscriptions.txt - используем прямой путь к файлу
        let subscriptionsBundlePath = "\(bundle.bundlePath)/Contents/Resources/subscriptions.txt"
        
        if FileManager.default.fileExists(atPath: subscriptionsBundlePath) {
            let subscriptionsURL = URL(fileURLWithPath: subscriptionsBundlePath)
            let destPath = i2pdDir.appendingPathComponent("subscriptions.txt")
            
            do {
                // Копируем только если файл не существует
                if !FileManager.default.fileExists(atPath: destPath.path) {
                    try FileManager.default.copyItem(at: subscriptionsURL, to: destPath)
                    addLog(.info, L("✅ subscriptions.txt скопирован из бандла (первый запуск)"))
                } else {
                    addLog(.info, L("📁 subscriptions.txt уже существует - сохраняем пользовательский"))
                }
            } catch {
                addLog(.error, L("❌ Ошибка копирования subscriptions.txt:") + " \(error)")
            }
        }
        
        // Копируем i2pd.conf
        let i2pdConfBundlePath = "\(bundle.bundlePath)/Contents/Resources/i2pd.conf"
        
        if FileManager.default.fileExists(atPath: i2pdConfBundlePath) {
            let configURL = URL(fileURLWithPath: i2pdConfBundlePath)
            let destPath = i2pdDir.appendingPathComponent("i2pd.conf")
            
            do {
                // Копируем только если файл не существует
                if !FileManager.default.fileExists(atPath: destPath.path) {
                    try FileManager.default.copyItem(at: configURL, to: destPath)
                    addLog(.info, L("✅ i2pd.conf скопирован из бандла (первый запуск)"))
                } else {
                    addLog(.info, L("📁 i2pd.conf уже существует - сохраняем пользовательский"))
                }
            } catch {
                addLog(.error, L("❌ Ошибка копирования i2pd.conf:") + " \(error)")
            }
        }
        
        // Копируем tunnels.conf
        let tunnelsConfBundlePath = "\(bundle.bundlePath)/Contents/Resources/tunnels.conf"
        
        if FileManager.default.fileExists(atPath: tunnelsConfBundlePath) {
            let tunnelsURL = URL(fileURLWithPath: tunnelsConfBundlePath)
            let destPath = i2pdDir.appendingPathComponent("tunnels.conf")
            
            do {
                // Копируем только если файл не существует
                if !FileManager.default.fileExists(atPath: destPath.path) {
                    try FileManager.default.copyItem(at: tunnelsURL, to: destPath)
                    addLog(.info, L("✅ tunnels.conf скопирован из бандла (первый запуск)"))
                } else {
                    addLog(.info, L("📁 tunnels.conf уже существует - сохраняем пользовательский"))
                }
            } catch {
                addLog(.error, L("❌ Ошибка копирования tunnels.conf:") + " \(error)")
            }
        }
    }

    // MARK: - Utility helpers
    private func synchronousFetchString(url: URL, timeout: TimeInterval = 3.0) -> String? {
        var resultData: Data?
        var responseError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            resultData = data
            responseError = error
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + timeout)
        if responseError != nil { return nil }
        if let data = resultData, let str = String(data: data, encoding: .utf8) { return str }
        return nil
    }

    private func firstRegexCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1,
           let r = Range(match.range(at: 1), in: text) {
            return String(text[r])
        }
        return nil
    }

    private func regexCaptures(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }

        var captures: [String] = []

        for index in 1..<match.numberOfRanges {
            guard let captureRange = Range(match.range(at: index), in: text) else {
                return nil
            }
            captures.append(String(text[captureRange]))
        }

        return captures
    }
}

// MARK: - LaunchAgent Controls Component
struct LaunchAgentControlsView: View {
    @Binding var autoStart: Bool
    
    var body: some View {
        if SettingsView.launchAgentExists() {
            HStack(spacing: 12) {
                Button(action: {
                    _ = SettingsView.removeLaunchAgent()
                    autoStart = false
                }) {
                    Label(L("Отключить автозапуск"), systemImage: "stop.circle")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
                    NSWorkspace.shared.open(launchAgentsDir)
                }) {
                    Label(L("Открыть папку"), systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
        } else {
            HStack(spacing: 12) {
                Button(action: {
                    if SettingsView.createLaunchAgent() {
                        autoStart = true
                        let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
                    NSWorkspace.shared.open(launchAgentsDir)
                    }
                }) {
                    Label(L("Включить автозапуск"), systemImage: "play.circle")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
        }
    }
}
