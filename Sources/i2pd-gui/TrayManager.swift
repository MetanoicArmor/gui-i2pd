import SwiftUI
import AppKit

// MARK: - Tray Manager Singleton  
class TrayManager: NSObject, ObservableObject {
    static let shared = TrayManager()
    private var statusBarItem: NSStatusItem?
    private var appDelegate: AppDelegate?
    
    // Ссылки на элементы меню для обновления состояния
    private var statusItem: NSMenuItem?
    private var startItem: NSMenuItem?
    private var stopItem: NSMenuItem?
    private var restartItem: NSMenuItem?
    
    // Состояние перезапуска демона
    private var isRestarting = false
    
    private override init() {
        super.init()
        setupStatusBar()
        
        // Создаем и сохраняем делегат для обработки завершения приложения
        appDelegate = AppDelegate()
        NSApp.delegate = appDelegate
    }
    
    private func setupStatusBar() {
        print("🔧🔧🔧 СОЗДАНИЕ ТРЕЯ НАЧИНАЕТСЯ 🔧🔧🔧")
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        print("🔧 StatusBar создан: \(String(describing: statusBarItem))")
        
        if let statusBarItem = statusBarItem {
            // Используем кастомную иконку трея или системную как fallback
            var image: NSImage?
            
            // Театральные маски из SF Symbols 7 - символично для I2P (анонимность/трагедия)
            // По умолчанию используем контурную иконку (демон остановлен)
            image = NSImage(systemSymbolName: "theatermasks", accessibilityDescription: "I2P Daemon")
            print("🎭 Используются театральные маски для трея (контурная иконка по умолчанию)")
            
            // Устанавливаем оптимальный размер иконки для сбалансированности
            if let image = image {
                image.size = NSSize(width: 18, height: 18)
                print("📏 Оптимальный размер иконки установлен: 18x18 пикселей")
            }
            
            statusBarItem.button?.image = image
            
            let menu = NSMenu()
            
            // Статус
            statusItem = NSMenuItem(title: L("Статус: Готов"), action: #selector(checkStatus), keyEquivalent: "")
            statusItem?.target = self
            menu.addItem(statusItem!)
            menu.addItem(NSMenuItem.separator())
            
            // Управление daemon - только текст
            let startAction = #selector(TrayManager.startDaemon)
            print("🔧 Селектор для start: \(String(describing: startAction))")
            
            startItem = NSMenuItem(title: L("Запустить daemon"), action: startAction, keyEquivalent: "")
            startItem?.target = self
            startItem?.tag = 1
            print("🔧 startItem создан с target: \(String(describing: startItem?.target)), action: \(String(describing: startItem?.action))")
            menu.addItem(startItem!)
            
            stopItem = NSMenuItem(title: L("Остановить daemon"), action: #selector(stopDaemon), keyEquivalent: "")
            stopItem?.target = self
            stopItem?.tag = 2
            print("🔧 stopItem создан с target: \(String(describing: stopItem?.target)), action: \(String(describing: stopItem?.action))")
            menu.addItem(stopItem!)
            
            restartItem = NSMenuItem(title: L("Перезапустить daemon"), action: #selector(restartDaemon), keyEquivalent: "")
            restartItem?.target = self
            restartItem?.tag = 3
            print("🔧 restartItem создан с target: \(String(describing: restartItem?.target)), action: \(String(describing: restartItem?.action))")
            menu.addItem(restartItem!)
            menu.addItem(NSMenuItem.separator())
            
            // Функции
            let settingsItem = NSMenuItem(title: L("Настройки"), action: #selector(openSettings), keyEquivalent: ",")
            settingsItem.target = self
            print("🔧 Создан settingsItem с target: \(String(describing: settingsItem.target)), action: \(String(describing: settingsItem.action))")
            menu.addItem(settingsItem)
            
            let toolsItem = NSMenuItem(title: L("Утилиты"), action: #selector(openTools), keyEquivalent: "t")
            toolsItem.target = self
            menu.addItem(toolsItem)
            
            let webItem = NSMenuItem(title: L("Веб-консоль"), action: #selector(openWebConsole), keyEquivalent: "")
            webItem.target = self
            menu.addItem(webItem)
            
            let showItem = NSMenuItem(title: L("Показать окно"), action: #selector(showMainWindow), keyEquivalent: "")
            showItem.target = self
            menu.addItem(showItem)
            menu.addItem(NSMenuItem.separator())
            
            let hideItem = NSMenuItem(title: L("Свернуть в трей"), action: #selector(hideMainWindow), keyEquivalent: "")
            hideItem.target = self
            menu.addItem(hideItem)
            
            let quitItem = NSMenuItem(title: L("Выйти"), action: #selector(quitApplication), keyEquivalent: "")
            quitItem.target = self
            menu.addItem(quitItem)
            
            statusBarItem.menu = menu
            print("✅✅✅ СТАТУС БАР ПОЛНОСТЬЮ СОЗДАН И НАСТРОЕН! ✅✅✅")
            print("🔧 Меню установлено: \(String(describing: statusBarItem.menu))")
            print("🔧 Количество пунктов меню: \(menu.items.count)")
            print("🔧 Target startItem: \(String(describing: startItem?.target))")
            print("🔧 Action startItem: \(String(describing: startItem?.action))")
        } else {
            print("❌❌❌ ОШИБКА СОЗДАНИЯ STATUS BAR! ❌❌❌")
        }
    }
    
    // MARK: - Объективные методы для меню
    
    @objc func checkStatus() {
        print("📊📊📊 МЕТОД checkStatus ВЫЗВАН ИЗ ТРЕЯ! 📊📊📊")
        updateStatusText("📊 Статус обновлен")
        print("📊 Статус обновлен на: 📊 Статус обновлен")
    }
    
    
    @objc public func startDaemon() {
        print("🚀 ========== ЗАПУСК DAEMON ИЗ ТРЕЯ! ==========")
        updateStatusText("🚀 Запуск daemon из трея...")
        
        // Делегируем запуск к I2pdManager чтобы избежать дублирования процессов
        NotificationCenter.default.post(name: NSNotification.Name("DaemonStartRequest"), object: nil)
        
        // Даем время на обработку запроса
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            NotificationCenter.default.post(name: NSNotification.Name("StatusUpdated"), object: nil)
            self.updateStatusText("🎯 Запрос обработан главным окном")
        }
    }
    
    @objc public func stopDaemon() {
        print("⏹️ ОСТАНОВКА DAEMON из трея!")
        updateStatusText("⏹️ Остановка daemon из трея...")
        
        // Делегируем остановку к I2pdManager чтобы избежать конфликтов
        NotificationCenter.default.post(name: NSNotification.Name("DaemonStopRequest"), object: nil)
        
        // Даем время на обработку запроса
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            NotificationCenter.default.post(name: NSNotification.Name("StatusUpdated"), object: nil)
            self.updateStatusText("🎯 Остановка обработана главным окном")
        }
    }
    
    private func checkIfStillRunning() {
        print("🔍 Проверяем, остановился ли daemon...")
        // Используем ту же команду проверки, что и в I2pdManager
        let checkCommand = "ps aux | grep \"i2pd.*daemon\" | grep -v \"grep\" | wc -l | tr -d ' '"
        
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
                // Обновляем состояние меню трея
                updateMenuState(isRunning: false)
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
        
        // БЕЗОПАСНО: убиваем только процессы с --daemon, не трогаем системные i2pd
        let forceCommand = "pkill -KILL -f 'i2pd.*--daemon' 2>/dev/null || true"
        
        let forceProcess = Process()
        forceProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        forceProcess.arguments = ["-c", forceCommand]
        
        do {
            try forceProcess.run()
            updateStatusText("✅ Daemon остановлен принудительно")
            print("✅ Жёсткая остановка выполнена")
            
            NotificationCenter.default.post(name: NSNotification.Name("DaemonStopped"), object: nil)
            // Обновляем состояние меню трея
            updateMenuState(isRunning: false)
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
        
        // Устанавливаем флаг перезапуска
        isRestarting = true
        updateMenuState(isRunning: false) // Обновляем меню с флагом перезапуска (предполагаем что демон остановлен)
        
        // Делегируем перезапуск к I2pdManager через уведомление
        NotificationCenter.default.post(name: NSNotification.Name("DaemonRestartRequest"), object: nil)
        
        // Сбрасываем флаг перезапуска через некоторое время
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.isRestarting = false
            self.updateMenuState(isRunning: true) // Предполагаем что демон запустился
        }
    }
    
    @objc func openSettings() {
        print("⚙️ ОТКРЫТИЕ НАСТРОЕК из трея!")
        print("📋 Текущее количество окон: \(NSApplication.shared.windows.count)")
        
        // Показываем главное окно
        showMainWindow()
        
        // Отправляем уведомление для открытия настроек в главном окне
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            print("📨 Отправляем уведомление OpenSettings...")
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
            print("✅ Уведомление OpenSettings отправлено")
        }
        
        updateStatusText("⚙️ Открытие настроек...")
        print("✅ Главное окно открыто с настройками")
    }
    
    @objc func openTools() {
        print("🔧 ОТКРЫТИЕ УТИЛИТ из трея!")
        print("📋 Текущее количество окон: \(NSApplication.shared.windows.count)")
        
        // Показываем главное окно
        showMainWindow()
        
        // Отправляем уведомление для открытия утилит в главном окне
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            print("📨 Отправляем уведомление OpenTools...")
            NotificationCenter.default.post(name: NSNotification.Name("OpenTools"), object: nil)
            print("✅ Уведомление OpenTools отправлено")
        }
        
        updateStatusText("🔧 Открытие утилит...")
        print("✅ Главное окно открыто с утилитами")
    }
    
    @objc func openWebConsole() {
        print("🌐 Открываем веб-консоль...")
        if let url = URL(string: "http://127.0.0.1:7070") {
            NSWorkspace.shared.open(url)
            updateStatusText("🌐 Веб-консоль открыта")
        } else {
            updateStatusText("❌ Ошибка открытия веб-консоли")
        }
    }
    
    @objc func showMainWindow() {
        print("⚙️ ПОКАЗ ОКНА из трея!")
        
        // Показываем окна без изменения политики приложения
        for window in NSApplication.shared.windows {
            window.makeKeyAndOrderFront(nil)
            // Убеждаемся, что у окна правильный делегат
            if window.delegate === nil || !(window.delegate is WindowCloseDelegate) {
                window.delegate = WindowCloseDelegate.shared
            }
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.updateStatusText("⚙️ Главное окно открыто")
        print("✅ Главное окно показано")
    }
    
    @objc func hideMainWindow() {
        print("❌ СВОРАЧИВАНИЕ В ТРЕЙ из трея!")
        for window in NSApplication.shared.windows {
            window.orderOut(nil)
        }
        
        // Возвращаем приложение в accessory режим если настройка включена
        let hideFromDock = UserDefaults.standard.bool(forKey: "hideFromDock")
        if hideFromDock {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        
        updateStatusText("📱 Свернуто в трей")
        print("✅ Приложение свернуто в трей")
    }
    
    @objc public func quitApplication() {
        print("🚪🚪🚪 ПЛАВНОЕ ЗАКРЫТИЕ ПРИЛОЖЕНИЯ! ФУНКЦИЯ ВЫЗВАНА! 🚪🚪🚪")
        print("📢 Время вызова: \(Date())")
        updateStatusText("🚪 Остановка демона и выход...")
        
        // СИНХРОННАЯ остановка демона - без async операций
        print("🔍 Ищем демон для остановки...")
        let findAndKillCommand = """
        DEMON_PID=$(ps aux | grep "i2pd.*daemon" | grep -v grep | awk '{print $2}' | head -1)
        if [ -n "$DEMON_PID" ]; then
            echo "✅ Найден демон с PID: $DEMON_PID"
            kill -s INT $DEMON_PID 2>/dev/null
            echo "✅ Демон остановлен синхронно"
            sleep 0.5
        else
            echo "ℹ️ Демон не найден"
        fi
        """
        
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        killProcess.arguments = ["-c", findAndKillCommand]
        
        do {
            print("💀 Выполняем синхронную остановку демона...")
            try killProcess.run()
            killProcess.waitUntilExit()
            print("✅ Синхронная остановка завершена")
            
            // Принудительно закрываем все окна (включая настройки) перед выходом
            print("🚪 Закрываем все окна перед выходом...")
            for window in NSApplication.shared.windows {
                window.close()
            }
            
            // Сбрасываем флаг настроек
            WindowCloseDelegate.isSettingsOpen = false
            
            // Даём время окнам закрыться, затем завершаем
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🚪 Завершаем приложение...")
                NSApplication.shared.terminate(nil)
            }
            
        } catch {
            print("❌ Ошибка остановки демона: \(error)")
            
            // Даже при ошибке закрываем все окна
            for window in NSApplication.shared.windows {
                window.close()
            }
            WindowCloseDelegate.isSettingsOpen = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    private func updateStatusText(_ text: String) {
        statusItem?.title = text
        print("📱 Обновлен статус трея: \(text)")
    }
    
    // Обновление иконки трея в зависимости от статуса демона
    private func updateTrayIcon(isRunning: Bool) {
        guard let statusBarItem = statusBarItem else { return }
        
        let symbolName = isRunning ? "theatermasks.fill" : "theatermasks"
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "I2P Daemon") {
            image.size = NSSize(width: 18, height: 18)
            statusBarItem.button?.image = image
            print("🎭 Иконка трея обновлена: \(isRunning ? "активна (fill)" : "неактивна")")
        }
    }
    
    // Обновление состояния элементов меню на основе состояния демона
    func updateMenuState(isRunning: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Обновляем иконку трея
            self.updateTrayIcon(isRunning: isRunning)
            
            if isRunning {
                // Демон запущен - галочка на "Запустить daemon" (показывает текущее состояние)
                self.startItem?.title = "✓ " + L("Запустить daemon") // Галочка показывает что запущен
                self.stopItem?.title = L("Остановить daemon")
                self.restartItem?.title = L("Перезапустить daemon") // Без галочки когда не перезапускается
                self.statusItem?.title = L("Статус: Запущен")
            } else {
                // Демон остановлен - галочка на "Остановить daemon" (показывает текущее состояние)
                self.startItem?.title = L("Запустить daemon")
                self.stopItem?.title = "✓ " + L("Остановить daemon") // Галочка показывает что остановлен
                self.restartItem?.title = L("Перезапустить daemon") // Без галочки когда не перезапускается
                self.statusItem?.title = L("Статус: Остановлен")
            }
            
            // Если идет перезапуск - показываем галочку на "Перезапустить daemon"
            if self.isRestarting {
                self.restartItem?.title = "✓ " + L("Перезапустить daemon") // Галочка во время перезапуска
                self.statusItem?.title = L("Статус: Перезапуск...")
            }
            
            print("🏷️ Обновлено состояние меню трея: демон \(isRunning ? "запущен" : "остановлен"), перезапуск: \(self.isRestarting)")
        }
    }
    
    // Установка флага перезапуска извне
    func setRestarting(_ restarting: Bool) {
        isRestarting = restarting
    }
    
    // Проверка начального статуса демона при запуске приложения
    func checkInitialDaemonStatus() {
        print("🔍 Проверяем начальный статус демона для трея...")
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        // Используем ту же команду, что и в I2pdManager.checkDaemonStatus()
        checkProcess.arguments = ["-c", "ps aux | grep \"i2pd.*daemon\" | grep -v \"grep\" | wc -l | tr -d ' '"]
        
        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "0"
            let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            
            let isRunning = count > 0
            print("🎭 Начальный статус демона: \(isRunning ? "запущен" : "остановлен") (найдено процессов: \(count))")
            
            DispatchQueue.main.async { [weak self] in
                self?.updateMenuState(isRunning: isRunning)
            }
        } catch {
            print("❌ Ошибка проверки начального статуса: \(error)")
        }
    }
}

