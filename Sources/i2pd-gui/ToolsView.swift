import SwiftUI
import Foundation

// MARK: - Tools Manager
class ToolsManager: ObservableObject {
    @Published var isRunning = false
    @Published var output = ""
    @Published var currentTool = ""
    
    private var process: Process?
    
    init() {
        // Подписываемся на уведомление о завершении приложения
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSNotification.Name("ApplicationWillTerminate"),
            object: nil
        )
    }
    
    @objc private func applicationWillTerminate() {
        print("🔧 ToolsManager: получено уведомление о завершении приложения")
        stopCurrentTool()
    }
    
    // Централизованные пути
    private var bundleToolsPath: String {
        guard let bundlePath = Bundle.main.resourcePath else {
            return ""
        }
        return "\(bundlePath)/tools"
    }
    
    private var i2pdDataPath: String {
        // Проверяем стандартные пути для i2pd данных
        let possiblePaths = [
            "/var/lib/i2pd",  // Linux/macOS стандартный путь
            "\(NSHomeDirectory())/.i2pd",  // Пользовательский путь
            "\(NSHomeDirectory())/Library/Application Support/i2pd"  // macOS Application Support
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Возвращаем домашнюю папку по умолчанию
        return NSHomeDirectory()
    }
    
    func getBundledToolPath(name: String) -> String {
        return "\(bundleToolsPath)/\(name)"
    }
    
    func getI2pdDataPath() -> String {
        return i2pdDataPath
    }
    
    func getToolsInfo() -> String {
        let bundlePath = bundleToolsPath
        let i2pdPath = i2pdDataPath
        let toolsExist = FileManager.default.fileExists(atPath: bundlePath)
        
        return """
        📁 Пути к утилитам:
        • Bundle tools: \(bundlePath) \(toolsExist ? "✅" : "❌")
        • i2pd данные: \(i2pdPath)
        • Домашняя папка: \(NSHomeDirectory())
        """
    }
    
    func validateToolExists(name: String) -> Bool {
        let toolPath = getBundledToolPath(name: name)
        return FileManager.default.fileExists(atPath: toolPath)
    }
    
    func runTool(name: String, arguments: [String], stdinData: String? = nil, workingDirectory: String? = nil, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let toolPath = self.getBundledToolPath(name: name)
            
            guard self.validateToolExists(name: name) else {
                DispatchQueue.main.async {
                    completion("❌ Утилита '\(name)' не найдена по пути: \(toolPath)")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.isRunning = true
                self.currentTool = name
                self.output = "🚀 Запуск \(name)...\n"
            }
            
            let process = Process()
            self.process = process // Сохраняем ссылку на процесс
            process.executableURL = URL(fileURLWithPath: toolPath)
            process.arguments = arguments
            
            // Устанавливаем рабочую директорию на домашнюю папку пользователя
            // чтобы утилиты могли создавать файлы
            // Устанавливаем рабочую директорию: либо переданную, либо домашнюю папку по умолчанию
            if let workingDir = workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
            } else {
                process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
            }
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let inputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.standardInput = inputPipe
            
            do {
                try process.run()
                
                // Записываем данные в stdin если они предоставлены
                if let stdinData = stdinData {
                    let inputHandle = inputPipe.fileHandleForWriting
                    if let data = stdinData.data(using: .utf8) {
                        inputHandle.write(data)
                    }
                    inputHandle.closeFile()
                }
                
                // Ждём завершения процесса с таймаутом
                let timeout: TimeInterval = 300 // 5 минут
                let startTime = Date()
                
                while process.isRunning {
                    if Date().timeIntervalSince(startTime) > timeout {
                        // Принудительно завершаем процесс при таймауте
                        process.terminate()
                        DispatchQueue.main.async {
                            self.isRunning = false
                            self.currentTool = ""
                            completion("⚠️ Процесс завершён по таймауту (5 минут)")
                        }
                        return
                    }
                    usleep(100000) // 0.1 секунды
                }
                
                // Читаем вывод после завершения процесса
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let outputString = String(data: outputData, encoding: .utf8) ?? ""
                let errorString = String(data: errorData, encoding: .utf8) ?? ""
                
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.currentTool = ""
                    self.process = nil // Очищаем ссылку на процесс
                    
                    var result = ""
                    if !outputString.isEmpty {
                        result += outputString
                    }
                    if !errorString.isEmpty {
                        result += "\n⚠️ Ошибки:\n\(errorString)"
                    }
                    
                    if result.isEmpty {
                        result = "✅ Команда выполнена успешно"
                    }
                    
                    completion(result)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.currentTool = ""
                    self.process = nil // Очищаем ссылку на процесс
                    completion("❌ Ошибка запуска: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func stopCurrentTool() {
        guard let process = process else { return }
        
        // Принудительно завершаем процесс
        process.terminate()
        
        // Ждём завершения с коротким таймаутом
        let timeout: TimeInterval = 2.0
        let startTime = Date()
        
        while process.isRunning && Date().timeIntervalSince(startTime) < timeout {
            usleep(50000) // 0.05 секунды
        }
        
        // Если процесс всё ещё работает, принудительно убиваем его
        if process.isRunning {
            process.terminate()
        }
        
        self.process = nil
        isRunning = false
        currentTool = ""
    }
    
    deinit {
        // Отписываемся от уведомлений
        NotificationCenter.default.removeObserver(self)
        
        // Завершаем все запущенные процессы при деинициализации
        process?.terminate()
        process = nil
    }
}

// MARK: - Tool Types
enum ToolType: String, CaseIterable {
    case keygen = "keygen"
    case vain = "vain"
    case keyinfo = "keyinfo"
    case b33address = "b33address"
    case regaddr = "regaddr"
    case regaddr3ld = "regaddr_3ld"
    case regaddralias = "regaddralias"
    case offlinekeys = "offlinekeys"
    case routerinfo = "routerinfo"
    case x25519 = "x25519"
    case i2pbase64 = "i2pbase64"
    case famtool = "famtool"
    case verifyhost = "verifyhost"
    case autoconf = "autoconf"
    
    var displayName: String {
        switch self {
        case .keygen: return L("Генерация ключей")
        case .vain: return L("Майнер адресов")
        case .keyinfo: return L("Информация о ключах")
        case .b33address: return L("B33 адрес")
        case .regaddr: return L("Регистрация домена")
        case .regaddr3ld: return L("Регистрация 3LD")
        case .regaddralias: return L("Алиас домена")
        case .offlinekeys: return L("Офлайн ключи")
        case .routerinfo: return L("Информация роутера")
        case .x25519: return L("X25519 ключи")
        case .i2pbase64: return L("Base64 кодирование")
        case .famtool: return L("Family tool")
        case .verifyhost: return L("Проверка хоста")
        case .autoconf: return L("Автоконфигурация")
        }
    }
    
    var icon: String {
        switch self {
        case .keygen: return "key.fill"
        case .vain: return "sparkles"
        case .keyinfo: return "info.circle.fill"
        case .b33address: return "link"
        case .regaddr: return "globe"
        case .regaddr3ld: return "globe.americas"
        case .regaddralias: return "arrow.triangle.2.circlepath"
        case .offlinekeys: return "key.slash.fill"
        case .routerinfo: return "network"
        case .x25519: return "lock.fill"
        case .i2pbase64: return "textformat.abc"
        case .famtool: return "person.3.fill"
        case .verifyhost: return "checkmark.shield.fill"
        case .autoconf: return "gear.circle.fill"
        }
    }
}

// MARK: - Main Tools View
struct ToolsView: View {
    @StateObject private var toolsManager = ToolsManager()
    @State private var selectedTool: ToolType = .keygen
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text(L("Утилиты"))
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(ToolType.allCases, id: \.self) { tool in
                            Button(action: {
                                selectedTool = tool
                            }) {
                                HStack {
                                    Image(systemName: tool.icon)
                                        .foregroundColor(selectedTool == tool ? .white : .primary)
                                        .frame(width: 20)
                                    
                                    Text(tool.displayName)
                                        .foregroundColor(selectedTool == tool ? .white : .primary)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedTool == tool ? Color.blue : Color.clear)
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
            .frame(width: 220)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main content
            VStack {
                // Заголовок с описанием
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: selectedTool.icon)
                            .foregroundColor(.blue)
                        Text(selectedTool.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // Кнопки управления
                        HStack(spacing: 8) {
                            Button(L("Очистить")) {
                                toolsManager.output = ""
                            }
                            .disabled(toolsManager.isRunning)
                            
                            Button(L("Пути")) {
                                toolsManager.output = toolsManager.getToolsInfo()
                            }
                            .disabled(toolsManager.isRunning)
                        }
                    }
                    
                    Text(getToolDescription(for: selectedTool))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Контент для выбранной утилиты
                Group {
                    switch selectedTool {
                    case .keygen:
                        KeygenView(toolsManager: toolsManager)
                    case .vain:
                        VainView(toolsManager: toolsManager)
                    case .keyinfo:
                        KeyinfoView(toolsManager: toolsManager)
                    case .b33address:
                        B33AddressView(toolsManager: toolsManager)
                    case .regaddr:
                        RegaddrView(toolsManager: toolsManager)
                    case .regaddr3ld:
                        Regaddr3ldView(toolsManager: toolsManager)
                    case .regaddralias:
                        RegaddraliasView(toolsManager: toolsManager)
                    case .offlinekeys:
                        OfflinekeysView(toolsManager: toolsManager)
                    case .routerinfo:
                        RouterinfoView(toolsManager: toolsManager)
                    case .x25519:
                        X25519View(toolsManager: toolsManager)
                    case .i2pbase64:
                        I2pbase64View(toolsManager: toolsManager)
                    case .famtool:
                        FamtoolView(toolsManager: toolsManager)
                    case .verifyhost:
                        VerifyhostView(toolsManager: toolsManager)
                    case .autoconf:
                        AutoconfView(toolsManager: toolsManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onDisappear {
            // Останавливаем все процессы при закрытии окна Tools
            toolsManager.stopCurrentTool()
        }
    }
    
    private func getToolDescription(for tool: ToolType) -> String {
        switch tool {
        case .keygen:
            return L("Генерация криптографических ключей для I2P туннелей")
        case .vain:
            return L("Поиск красивых адресов с заданным паттерном")
        case .keyinfo:
            return L("Получение информации о существующих ключах")
        case .b33address:
            return L("Получение адреса для зашифрованного лизсета")
        case .regaddr:
            return L("Регистрация короткого домена в зоне .i2p")
        case .regaddr3ld:
            return L("Регистрация домена третьего уровня в зоне .i2p")
        case .regaddralias:
            return L("Привязка короткого домена к новым ключам")
        case .offlinekeys:
            return L("Работа с временными ключами для безопасности")
        case .routerinfo:
            return L("Информация о I2P роутерах")
        case .x25519:
            return L("Генерация ключей шифрования X25519")
        case .i2pbase64:
            return L("Кодирование и декодирование в base64")
        case .famtool:
            return L("Управление семейными группами роутеров")
        case .verifyhost:
            return L("Проверка подлинности хостов")
        case .autoconf:
            return L("Автоматическая конфигурация")
        }
    }
}

// MARK: - Keygen View
struct KeygenView: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var keyName = ""
    @State private var signatureType = "7" // EDDSA-SHA512-ED25519 default
    
    let signatureTypes = [
        ("7", "EDDSA-SHA512-ED25519 (default)"),
        ("10", "RSA-SHA256-2048"),
        ("11", "RSA-SHA384-3072"),
        ("12", "RSA-SHA512-4096")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Имя файла ключа"))
                    .font(.headline)
                TextField(L("Введите имя файла"), text: $keyName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Тип подписи"))
                    .font(.headline)
                Picker(L("Тип подписи"), selection: $signatureType) {
                    ForEach(signatureTypes, id: \.0) { type in
                        Text(type.1).tag(type.0)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            HStack {
                Button(action: generateKey) {
                    HStack {
                        if toolsManager.isRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(L("Генерировать ключ"))
                    }
                }
                .disabled(toolsManager.isRunning || keyName.isEmpty)
                
                if toolsManager.isRunning {
                    Button(L("Остановить")) {
                        toolsManager.stopCurrentTool()
                    }
                }
            }
            
            if !toolsManager.output.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Результат"))
                        .font(.headline)
                    ScrollView {
                        Text(toolsManager.output)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(height: 200)
                }
            }
        }
        .padding()
    }
    
    private func generateKey() {
        let arguments = [keyName, signatureType]
        toolsManager.runTool(name: "keygen", arguments: arguments) { output in
            toolsManager.output = output
        }
    }
}

// MARK: - Vain View (Address Miner)
struct VainView: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var pattern = ""
    @State private var useRegex = false
    @State private var threads = "0" // 0 = количество ядер
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Паттерн поиска"))
                    .font(.headline)
                TextField(L("Введите паттерн"), text: $pattern)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text(L("Поиск осуществляется с начала адреса"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle(L("Использовать регулярные выражения"), isOn: $useRegex)
                Text(L("Регулярные выражения работают медленнее"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Количество потоков"))
                    .font(.headline)
                TextField(L("0 = количество ядер"), text: $threads)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack {
                Button(action: startMining) {
                    HStack {
                        if toolsManager.isRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(L("Начать поиск"))
                    }
                }
                .disabled(toolsManager.isRunning || pattern.isEmpty)
                
                if toolsManager.isRunning {
                    Button(L("Остановить")) {
                        toolsManager.stopCurrentTool()
                    }
                }
            }
            
            if !toolsManager.output.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Результат"))
                        .font(.headline)
                    ScrollView {
                        Text(toolsManager.output)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(height: 200)
                }
            }
            
        }
        .padding()
    }
    
    private func startMining() {
        var arguments = [pattern]
        if useRegex {
            arguments.append("--regex")
        }
        if threads != "0" {
            arguments.append("-t")
            arguments.append(threads)
        }
        
        toolsManager.runTool(name: "vain", arguments: arguments) { output in
            toolsManager.output = output
        }
    }
}

// MARK: - Keyinfo View
struct KeyinfoView: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var keyFilePath = ""
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Файл с ключом"))
                    .font(.headline)
                HStack {
                    TextField(L("Выберите файл с ключом"), text: $keyFilePath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                    
                    Button(L("Выбрать файл")) {
                        showingFilePicker = true
                    }
                }
            }
            
            HStack {
                Button(action: getKeyInfo) {
                    HStack {
                        if toolsManager.isRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(L("Получить информацию"))
                    }
                }
                .disabled(toolsManager.isRunning || keyFilePath.isEmpty)
                
                if toolsManager.isRunning {
                    Button(L("Остановить")) {
                        toolsManager.stopCurrentTool()
                    }
                }
            }
            
            if !toolsManager.output.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Результат"))
                        .font(.headline)
                    ScrollView {
                        Text(toolsManager.output)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(height: 200)
                }
            }
            
            Spacer()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.data, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    keyFilePath = url.path
                }
            case .failure(let error):
                toolsManager.output = "❌ Ошибка выбора файла: \(error.localizedDescription)"
            }
        }
    }
    
    private func getKeyInfo() {
        toolsManager.runTool(name: "keyinfo", arguments: [keyFilePath]) { output in
            toolsManager.output = output
        }
    }
}

// MARK: - Placeholder Views для остальных утилит
struct B33AddressView: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var base64Address = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Полный адрес в Base64"))
                    .font(.headline)
                TextEditor(text: $base64Address)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 120)
                    .border(Color.gray.opacity(0.3))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Инструкция"))
                    .font(.headline)
                Text(L("Вставьте полный адрес в кодировке Base64. Получить его можно командой: keyinfo -d <файл_ключа>"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(L("Вычислить B33 адрес")) {
                calculateB33Address()
            }
            .disabled(base64Address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || toolsManager.isRunning)
            
            if toolsManager.isRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("Вычисление..."))
                        .font(.caption)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Результат"))
                    .font(.headline)
                ScrollView {
                    Text(toolsManager.output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(height: 200)
            }
            
        }
        .padding()
    }
    
    private func calculateB33Address() {
        let trimmedAddress = base64Address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedAddress.isEmpty {
            toolsManager.output = "❌ Введите полный адрес в Base64"
            return
        }
        
        // Запускаем b33address с передачей данных через stdin
        toolsManager.runTool(name: "b33address", arguments: [], stdinData: trimmedAddress) { output in
            toolsManager.output = output
        }
    }
}

struct RegaddrView: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var keyFilePath = ""
    @State private var domainName = ""
    @State private var showingFilePicker = false
    @State private var registrationString = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Файл с ключами"))
                    .font(.headline)
                HStack {
                    TextField(L("Выберите файл с ключами"), text: $keyFilePath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                    Button(L("Выбрать")) {
                        showingFilePicker = true
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Желаемый домен"))
                    .font(.headline)
                TextField(L("Например: mysite.i2p"), text: $domainName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Инструкция"))
                    .font(.headline)
                Text(L("Введите желаемый домен (например: mysite.i2p) и выберите файл с ключами. После генерации регистрационной строки отправьте её на reg.i2p или stats.i2p"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(L("Сгенерировать регистрационную строку")) {
                generateRegistrationString()
            }
            .disabled(keyFilePath.isEmpty || domainName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || toolsManager.isRunning)
            
            if toolsManager.isRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("Генерация..."))
                        .font(.caption)
                }
            }
            
            if !registrationString.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Регистрационная строка"))
                        .font(.headline)
                    ScrollView {
                        Text(registrationString)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(height: 150)
                    
                    HStack {
                        Button(L("Копировать")) {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(registrationString, forType: .string)
                        }
                        
                        Button(L("Проверить подпись")) {
                            verifySignature()
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Результат"))
                    .font(.headline)
                ScrollView {
                    Text(toolsManager.output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(height: 200)
            }
            
            Spacer()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.data, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    keyFilePath = url.path
                }
            case .failure(let error):
                toolsManager.output = "❌ Ошибка выбора файла: \(error.localizedDescription)"
            }
        }
    }
    
    private func generateRegistrationString() {
        let trimmedDomain = domainName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedDomain.isEmpty {
            toolsManager.output = "❌ Введите желаемый домен"
            return
        }
        
        if keyFilePath.isEmpty {
            toolsManager.output = "❌ Выберите файл с ключами"
            return
        }
        
        // Запускаем regaddr с файлом ключей и доменом
        toolsManager.runTool(name: "regaddr", arguments: [keyFilePath, trimmedDomain]) { output in
            DispatchQueue.main.async {
                if output.contains("=") && output.contains("#!sig=") {
                    // Успешная генерация регистрационной строки
                    registrationString = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    toolsManager.output = "✅ " + L("Регистрационная строка сгенерирована успешно!") + "\n\n" + output
                } else {
                    // Ошибка
                    toolsManager.output = output
                    registrationString = ""
                }
            }
        }
    }
    
    private func verifySignature() {
        if registrationString.isEmpty {
            toolsManager.output = "❌ Сначала сгенерируйте регистрационную строку"
            return
        }
        
        // Запускаем verifyhost для проверки подписи
        // Экранируем восклицательный знак для корректной передачи в bash
        let escapedString = registrationString.replacingOccurrences(of: "!", with: "\\!")
        
        toolsManager.runTool(name: "verifyhost", arguments: [escapedString]) { output in
            DispatchQueue.main.async {
                if output.isEmpty {
                    toolsManager.output = "✅ Подпись корректна! Регистрационная строка готова для отправки на reg.i2p или stats.i2p"
                } else {
                    toolsManager.output = "❌ Ошибка проверки подписи:\n" + output
                }
            }
        }
    }
}

struct Regaddr3ldView: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var subDomainKeyPath = ""
    @State private var mainDomainKeyPath = ""
    @State private var subDomainName = ""
    @State private var mainDomainName = ""
    @State private var showingSubKeyPicker = false
    @State private var showingMainKeyPicker = false
    @State private var currentStep = 0
    @State private var step1Result = ""
    @State private var step2Result = ""
    @State private var finalResult = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Ключ субдомена"))
                    .font(.headline)
                HStack {
                    TextField(L("Выберите файл с ключом субдомена"), text: $subDomainKeyPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                    Button(L("Выбрать")) {
                        showingSubKeyPicker = true
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Ключ основного домена"))
                    .font(.headline)
                HStack {
                    TextField(L("Выберите файл с ключом основного домена"), text: $mainDomainKeyPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                    Button(L("Выбрать")) {
                        showingMainKeyPicker = true
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Домен третьего уровня"))
                    .font(.headline)
                TextField(L("Например: sub.domain.i2p"), text: $subDomainName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Основной домен"))
                    .font(.headline)
                TextField(L("Например: domain.i2p"), text: $mainDomainName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Инструкция"))
                    .font(.headline)
                Text(L("Регистрация домена третьего уровня происходит в 3 шага:\n1. Подпись домена ключом субдомена\n2. Подпись результата ключом основного домена\n3. Финальная подпись ключом субдомена"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button(L("Шаг 1: Подписать домен")) {
                    executeStep1()
                }
                .disabled(!canExecuteStep1() || toolsManager.isRunning)
                
                Button(L("Шаг 2: Подписать результат")) {
                    executeStep2()
                }
                .disabled(!canExecuteStep2() || toolsManager.isRunning)
                
                Button(L("Шаг 3: Финальная подпись")) {
                    executeStep3()
                }
                .disabled(!canExecuteStep3() || toolsManager.isRunning)
            }
            
            if toolsManager.isRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("Выполнение..."))
                        .font(.caption)
                }
            }
            
            if !finalResult.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Регистрационная строка"))
                        .font(.headline)
                    ScrollView {
                        Text(finalResult)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(height: 150)
                    
                    HStack {
                        Button(L("Копировать")) {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(finalResult, forType: .string)
                        }
                        
                        Button(L("Проверить подпись")) {
                            verifySignature()
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Результат"))
                    .font(.headline)
                ScrollView {
                    Text(toolsManager.output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(height: 200)
            }
            
            Spacer()
        }
        .fileImporter(
            isPresented: $showingSubKeyPicker,
            allowedContentTypes: [.data, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    subDomainKeyPath = url.path
                }
            case .failure(let error):
                toolsManager.output = "❌ Ошибка выбора файла субдомена: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showingMainKeyPicker,
            allowedContentTypes: [.data, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    mainDomainKeyPath = url.path
                }
            case .failure(let error):
                toolsManager.output = "❌ Ошибка выбора файла основного домена: \(error.localizedDescription)"
            }
        }
    }
    
    private func canExecuteStep1() -> Bool {
        return !subDomainKeyPath.isEmpty && !subDomainName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func canExecuteStep2() -> Bool {
        return !mainDomainKeyPath.isEmpty && !mainDomainName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !step1Result.isEmpty
    }
    
    private func canExecuteStep3() -> Bool {
        return !subDomainKeyPath.isEmpty && !step2Result.isEmpty
    }
    
    private func executeStep1() {
        let trimmedDomain = subDomainName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedDomain.isEmpty {
            toolsManager.output = "❌ Введите домен третьего уровня"
            return
        }
        
        if subDomainKeyPath.isEmpty {
            toolsManager.output = "❌ Выберите файл с ключом субдомена"
            return
        }
        
        // Шаг 1: Подпись домена ключом субдомена
        toolsManager.runTool(name: "regaddr_3ld", arguments: ["step1", subDomainKeyPath, trimmedDomain]) { output in
            DispatchQueue.main.async {
                if !output.isEmpty && !output.contains("❌") {
                    step1Result = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    toolsManager.output = "✅ Шаг 1 выполнен успешно!\n\n" + output
                } else {
                    toolsManager.output = output
                }
            }
        }
    }
    
    private func executeStep2() {
        let trimmedDomain = mainDomainName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedDomain.isEmpty {
            toolsManager.output = "❌ Введите основной домен"
            return
        }
        
        if mainDomainKeyPath.isEmpty {
            toolsManager.output = "❌ Выберите файл с ключом основного домена"
            return
        }
        
        if step1Result.isEmpty {
            toolsManager.output = "❌ Сначала выполните шаг 1"
            return
        }
        
        // Создаем временный файл с результатом шага 1
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("step1_temp.txt")
        
        do {
            try step1Result.write(to: tempFile, atomically: true, encoding: .utf8)
            
            // Шаг 2: Подпись результата ключом основного домена
            toolsManager.runTool(name: "regaddr_3ld", arguments: ["step2", tempFile.path, mainDomainKeyPath, trimmedDomain]) { output in
                // Удаляем временный файл
                try? FileManager.default.removeItem(at: tempFile)
                
                DispatchQueue.main.async {
                    if !output.isEmpty && !output.contains("❌") {
                        step2Result = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        toolsManager.output = "✅ Шаг 2 выполнен успешно!\n\n" + output
                    } else {
                        toolsManager.output = output
                    }
                }
            }
        } catch {
            toolsManager.output = "❌ Ошибка создания временного файла: \(error.localizedDescription)"
        }
    }
    
    private func executeStep3() {
        if subDomainKeyPath.isEmpty {
            toolsManager.output = "❌ Выберите файл с ключом субдомена"
            return
        }
        
        if step2Result.isEmpty {
            toolsManager.output = "❌ Сначала выполните шаг 2"
            return
        }
        
        // Создаем временный файл с результатом шага 2
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("step2_temp.txt")
        
        do {
            try step2Result.write(to: tempFile, atomically: true, encoding: .utf8)
            
            // Шаг 3: Финальная подпись ключом субдомена
            toolsManager.runTool(name: "regaddr_3ld", arguments: ["step3", tempFile.path, subDomainKeyPath]) { output in
                // Удаляем временный файл
                try? FileManager.default.removeItem(at: tempFile)
                
                DispatchQueue.main.async {
                    if !output.isEmpty && !output.contains("❌") {
                        finalResult = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        toolsManager.output = "✅ Шаг 3 выполнен успешно! Регистрационная строка готова!\n\n" + output
                    } else {
                        toolsManager.output = output
                    }
                }
            }
        } catch {
            toolsManager.output = "❌ Ошибка создания временного файла: \(error.localizedDescription)"
        }
    }
    
    private func verifySignature() {
        if finalResult.isEmpty {
            toolsManager.output = "❌ Сначала выполните все 3 шага"
            return
        }
        
        // Запускаем verifyhost для проверки подписи
        let escapedString = finalResult.replacingOccurrences(of: "!", with: "\\!")
        
        toolsManager.runTool(name: "verifyhost", arguments: [escapedString]) { output in
            DispatchQueue.main.async {
                if output.isEmpty {
                    toolsManager.output = "✅ Подпись корректна! Регистрационная строка готова для отправки на reg.i2p или stats.i2p"
                } else {
                    toolsManager.output = "❌ Ошибка проверки подписи:\n" + output
                }
            }
        }
    }
}

struct RegaddraliasView: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var oldKeyPath = ""
    @State private var newKeyPath = ""
    @State private var domainName = ""
    @State private var showingOldKeyPicker = false
    @State private var showingNewKeyPicker = false
    @State private var aliasString = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Старые ключи"))
                    .font(.headline)
                HStack {
                    TextField(L("Выберите файл со старыми ключами"), text: $oldKeyPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                    Button(L("Выбрать")) {
                        showingOldKeyPicker = true
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Новые ключи"))
                    .font(.headline)
                HStack {
                    TextField(L("Выберите файл с новыми ключами"), text: $newKeyPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                    Button(L("Выбрать")) {
                        showingNewKeyPicker = true
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Домен для перепривязки"))
                    .font(.headline)
                TextField(L("Например: mysite.i2p"), text: $domainName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Инструкция"))
                    .font(.headline)
                Text(L("Для смены ключей домена необходимо иметь как старые, так и новые ключи. Утилита создаст алиас, который привяжет домен к новым ключам, указав при этом старые ключи для проверки."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(L("Создать алиас перепривязки")) {
                createAlias()
            }
            .disabled(!canCreateAlias() || toolsManager.isRunning)
            
            if toolsManager.isRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("Создание алиаса..."))
                        .font(.caption)
                }
            }
            
            if !aliasString.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Алиас перепривязки"))
                        .font(.headline)
                    ScrollView {
                        Text(aliasString)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(height: 200)
                    
                    HStack {
                        Button(L("Копировать")) {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(aliasString, forType: .string)
                        }
                        
                        Button(L("Проверить подпись")) {
                            verifySignature()
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Результат"))
                    .font(.headline)
                ScrollView {
                    Text(toolsManager.output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(height: 200)
            }
            
            Spacer()
        }
        .fileImporter(
            isPresented: $showingOldKeyPicker,
            allowedContentTypes: [.data, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    oldKeyPath = url.path
                }
            case .failure(let error):
                toolsManager.output = "❌ Ошибка выбора файла старых ключей: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showingNewKeyPicker,
            allowedContentTypes: [.data, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    newKeyPath = url.path
                }
            case .failure(let error):
                toolsManager.output = "❌ Ошибка выбора файла новых ключей: \(error.localizedDescription)"
            }
        }
    }
    
    private func canCreateAlias() -> Bool {
        return !oldKeyPath.isEmpty && !newKeyPath.isEmpty && !domainName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func createAlias() {
        let trimmedDomain = domainName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedDomain.isEmpty {
            toolsManager.output = "❌ Введите домен для перепривязки"
            return
        }
        
        if oldKeyPath.isEmpty {
            toolsManager.output = "❌ Выберите файл со старыми ключами"
            return
        }
        
        if newKeyPath.isEmpty {
            toolsManager.output = "❌ Выберите файл с новыми ключами"
            return
        }
        
        // Запускаем regaddralias с файлами ключей и доменом
        toolsManager.runTool(name: "regaddralias", arguments: [oldKeyPath, newKeyPath, trimmedDomain]) { output in
            DispatchQueue.main.async {
                if output.contains("=") && output.contains("#!action=adddest") {
                    // Успешное создание алиаса
                    aliasString = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    toolsManager.output = "✅ Алиас перепривязки создан успешно!\n\n" + output
                } else {
                    // Ошибка
                    toolsManager.output = output
                    aliasString = ""
                }
            }
        }
    }
    
    private func verifySignature() {
        if aliasString.isEmpty {
            toolsManager.output = "❌ Сначала создайте алиас перепривязки"
            return
        }
        
        // Запускаем verifyhost для проверки подписи
        let escapedString = aliasString.replacingOccurrences(of: "!", with: "\\!")
        
        toolsManager.runTool(name: "verifyhost", arguments: [escapedString]) { output in
            DispatchQueue.main.async {
                if output.isEmpty {
                    toolsManager.output = "✅ Подпись корректна! Алиас перепривязки готов для отправки на reg.i2p или stats.i2p"
                } else {
                    toolsManager.output = "❌ Ошибка проверки подписи:\n" + output
                }
            }
        }
    }
}

struct OfflinekeysView: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var masterKeyPath = ""
    @State private var outputKeyPath = ""
    @State private var days = "365"
    @State private var signatureType = "7"
    @State private var showingMasterKeyPicker = false
    @State private var showingOutputKeyPicker = false
    @State private var offlineKeyInfo = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Основной ключ"))
                    .font(.headline)
                HStack {
                    TextField(L("Выберите файл с основным ключом"), text: $masterKeyPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                    Button(L("Выбрать")) {
                        showingMasterKeyPicker = true
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Выходной файл"))
                    .font(.headline)
                HStack {
                    TextField(L("Имя файла для временного ключа"), text: $outputKeyPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(L("Выбрать")) {
                        showingOutputKeyPicker = true
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Срок действия (дни)"))
                    .font(.headline)
                TextField(L("Например: 365"), text: $days)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Тип подписи"))
                    .font(.headline)
                TextField(L("Например: 7 (ED25519-SHA512)"), text: $signatureType)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Инструкция"))
                    .font(.headline)
                Text(L("Офлайн-ключи позволяют хранить основной ключ в безопасном месте, а на сервере использовать временный ключ с ограниченным сроком действия. В случае компрометации временного ключа, после истечения срока действия ваш адрес снова будет принадлежать только вам."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(L("Создать офлайн-ключ")) {
                createOfflineKey()
            }
            .disabled(!canCreateOfflineKey() || toolsManager.isRunning)
            
            if toolsManager.isRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("Создание офлайн-ключа..."))
                        .font(.caption)
                }
            }
            
            if !offlineKeyInfo.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Информация об офлайн-ключе"))
                        .font(.headline)
                    ScrollView {
                        Text(offlineKeyInfo)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(height: 200)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Результат"))
                    .font(.headline)
                ScrollView {
                    Text(toolsManager.output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showingMasterKeyPicker,
            allowedContentTypes: [.data, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    masterKeyPath = url.path
                }
            case .failure(let error):
                toolsManager.output = "❌ Ошибка выбора файла основного ключа: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showingOutputKeyPicker,
            allowedContentTypes: [.data, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    outputKeyPath = url.path
                }
            case .failure(let error):
                toolsManager.output = "❌ Ошибка выбора выходного файла: \(error.localizedDescription)"
            }
        }
        .padding()
    }
    
    private func canCreateOfflineKey() -> Bool {
        return !masterKeyPath.isEmpty && !outputKeyPath.isEmpty && !days.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !signatureType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func createOfflineKey() {
        let trimmedDays = days.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSignatureType = signatureType.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedDays.isEmpty {
            toolsManager.output = "❌ Введите срок действия в днях"
            return
        }
        
        if trimmedSignatureType.isEmpty {
            toolsManager.output = "❌ Введите тип подписи"
            return
        }
        
        guard let daysInt = Int(trimmedDays), daysInt > 0 else {
            toolsManager.output = "❌ Срок действия должен быть положительным числом"
            return
        }
        
        guard let signatureTypeInt = Int(trimmedSignatureType), signatureTypeInt > 0 else {
            toolsManager.output = "❌ Тип подписи должен быть положительным числом"
            return
        }
        
        if masterKeyPath.isEmpty {
            toolsManager.output = "❌ Выберите файл с основным ключом"
            return
        }
        
        if outputKeyPath.isEmpty {
            toolsManager.output = "❌ Выберите выходной файл"
            return
        }
        
        // Запускаем offlinekeys с основным ключом, выходным файлом, типом подписи и сроком действия
        toolsManager.runTool(name: "offlinekeys", arguments: [outputKeyPath, masterKeyPath, trimmedSignatureType, trimmedDays]) { output in
            DispatchQueue.main.async {
                if output.contains("Offline keys for destination") && output.contains("created") {
                    // Успешное создание офлайн-ключа
                    toolsManager.output = "✅ Офлайн-ключ создан успешно!\n\n" + output
                    
                    // Получаем подробную информацию о созданном ключе
                    self.getOfflineKeyInfo()
                } else {
                    // Ошибка
                    toolsManager.output = output
                    offlineKeyInfo = ""
                }
            }
        }
    }
    
    private func getOfflineKeyInfo() {
        // Получаем подробную информацию о созданном офлайн-ключе
        toolsManager.runTool(name: "keyinfo", arguments: ["-v", outputKeyPath]) { output in
            DispatchQueue.main.async {
                if !output.isEmpty && !output.contains("❌") {
                    offlineKeyInfo = output
                } else {
                    offlineKeyInfo = "Не удалось получить подробную информацию о ключе"
                }
            }
        }
    }
}

struct RouterinfoView: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var routerInfoPath = ""
    @State private var showingFilePicker = false
    @State private var showPorts = false
    @State private var showFirewallRules = false
    @State private var showIPv6 = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Файл RouterInfo"))
                    .font(.headline)
                HStack {
                    TextField(L("Выберите файл RouterInfo"), text: $routerInfoPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                    Button(L("Выбрать")) {
                        showingFilePicker = true
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Опции"))
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(L("Показать порты (-p)"), isOn: $showPorts)
                    Toggle(L("Правила файервола (-f)"), isOn: $showFirewallRules)
                    Toggle(L("IPv6 адреса (-6)"), isOn: $showIPv6)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Инструкция"))
                    .font(.headline)
                Text(L("RouterInfo содержит информацию о криптографических ключах и IP-адресе роутера. Файлы обычно находятся в netDb/ директории данных i2pd. Флаг -p показывает порты, -f генерирует правила iptables, -6 добавляет IPv6 адреса."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(L("Анализировать RouterInfo")) {
                analyzeRouterInfo()
            }
            .disabled(routerInfoPath.isEmpty || toolsManager.isRunning)
            
            if toolsManager.isRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("Анализ..."))
                        .font(.caption)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Результат"))
                    .font(.headline)
                ScrollView {
                    Text(toolsManager.output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(height: 300)
            }
            
            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.data, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    routerInfoPath = url.path
                }
            case .failure(let error):
                toolsManager.output = "❌ Ошибка выбора файла RouterInfo: \(error.localizedDescription)"
            }
        }
    }
    
    private func analyzeRouterInfo() {
        if routerInfoPath.isEmpty {
            toolsManager.output = "❌ Выберите файл RouterInfo"
            return
        }
        
        var arguments = [routerInfoPath]
        
        if showPorts {
            arguments.insert("-p", at: 0)
        }
        
        if showFirewallRules {
            arguments.insert("-f", at: 0)
        }
        
        if showIPv6 {
            arguments.insert("-6", at: 0)
        }
        
        // Устанавливаем рабочую директорию для корректной работы с RouterInfo
        toolsManager.runTool(name: "routerinfo", arguments: arguments, workingDirectory: toolsManager.getI2pdDataPath()) { output in
            DispatchQueue.main.async {
                if !output.isEmpty && !output.contains("❌") {
                    toolsManager.output = "✅ Анализ RouterInfo завершен!\n\n" + output
                } else {
                    toolsManager.output = output
                }
            }
        }
    }
}

struct X25519View: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var publicKey = ""
    @State private var privateKey = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Инструкция"))
                    .font(.headline)
                Text(L("Утилита генерирует пару ключей шифрования X25519 в кодировке Base64. Используется в зашифрованных лизсетах с авторизацией для защиты от DDoS-атак на уровне протокола сети I2P."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Применение"))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("• Server: i2cp.leaseSetClient.dh.NNN = User:PublicKey"))
                    Text(L("• Client: i2cp.leaseSetPrivKey = PrivateKey"))
                    Text(L("• signaturetype = 11, i2cp.leaseSetType = 5, i2cp.leaseSetAuthType = 1"))
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            }
            
            Button(L("Генерировать X25519 ключи")) {
                generateX25519()
            }
            .disabled(toolsManager.isRunning)
            
            if toolsManager.isRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("Генерация..."))
                        .font(.caption)
                }
            }
            
            if !publicKey.isEmpty && !privateKey.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Публичный ключ"))
                            .font(.headline)
                        HStack {
                            Text(publicKey)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button(L("Копировать")) {
                                copyToClipboard(publicKey)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Приватный ключ"))
                            .font(.headline)
                        HStack {
                            Text(privateKey)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button(L("Копировать")) {
                                copyToClipboard(privateKey)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Готовые конфигурации"))
                            .font(.headline)
                        
                        HStack {
                            Button(L("Конфигурация сервера")) {
                                copyServerConfig()
                            }
                            
                            Button(L("Конфигурация клиента")) {
                                copyClientConfig()
                            }
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Результат"))
                    .font(.headline)
                ScrollView {
                    Text(toolsManager.output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(height: 200)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func generateX25519() {
        toolsManager.runTool(name: "x25519", arguments: []) { output in
            DispatchQueue.main.async {
                if !output.isEmpty && !output.contains("❌") {
                    // Парсим вывод утилиты x25519
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        if line.hasPrefix("PublicKey: ") {
                            publicKey = String(line.dropFirst("PublicKey: ".count))
                        } else if line.hasPrefix("PrivateKey: ") {
                            privateKey = String(line.dropFirst("PrivateKey: ".count))
                        }
                    }
                    
                    toolsManager.output = "✅ X25519 ключи сгенерированы успешно!\n\n" + output
                } else {
                    toolsManager.output = output
                    publicKey = ""
                    privateKey = ""
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func copyServerConfig() {
        let serverConfig = """
[SUPER-HIDDEN-SERVICE]
type = server
host = 127.0.0.1
port = 8080
inport = 80
keys = site.dat
signaturetype = 11
i2cp.leaseSetType = 5
i2cp.leaseSetAuthType = 1
i2cp.leaseSetClient.dh.123 = user:\(publicKey)
"""
        copyToClipboard(serverConfig)
    }
    
    private func copyClientConfig() {
        let clientConfig = """
[hidden-client]
type = client
address = 127.0.0.1
port = 8090
destination = your-service.b32.i2p
destinationport = 80
keys = client.dat
i2cp.leaseSetPrivKey = \(privateKey)
"""
        copyToClipboard(clientConfig)
    }
}

struct I2pbase64View: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var inputText = ""
    @State private var operation = "encode" // encode или decode
    @State private var result = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Инструкция"))
                    .font(.headline)
                Text(L("I2P Base64 использует специальный алфавит: + заменяется на -, / на ~. Это связано с использованием в веб-браузере для addresshelper. Подходит для кодирования криптографических ключей и бинарных данных."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Операция"))
                    .font(.headline)
                Picker(L("Операция"), selection: $operation) {
                    Text(L("Кодировать")).tag("encode")
                    Text(L("Декодировать")).tag("decode")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Входной текст"))
                    .font(.headline)
                TextEditor(text: $inputText)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            Button(operation == "encode" ? L("Кодировать в I2P Base64") : L("Декодировать из I2P Base64")) {
                processBase64()
            }
            .disabled(toolsManager.isRunning || inputText.isEmpty)
            
            if toolsManager.isRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("Обработка..."))
                        .font(.caption)
                }
            }
            
            if !result.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Результат"))
                        .font(.headline)
                    HStack {
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(L("Копировать")) {
                            copyToClipboard(result)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Полный вывод"))
                    .font(.headline)
                ScrollView {
                    Text(toolsManager.output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(height: 150)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func processBase64() {
        // Создаем временный файл с входными данными
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("i2pbase64_input.txt")
        
        do {
            try inputText.write(to: tempFile, atomically: true, encoding: .utf8)
            
            let arguments = operation == "encode" ? ["-e", tempFile.path] : ["-d", tempFile.path]
            
            toolsManager.runTool(name: "i2pbase64", arguments: arguments) { output in
                DispatchQueue.main.async {
                    if !output.isEmpty && !output.contains("❌") {
                        // Извлекаем результат (убираем лишние символы)
                        let cleanOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        result = cleanOutput
                        toolsManager.output = "✅ \(operation == "encode" ? "Кодирование" : "Декодирование") завершено!\n\n" + output
                    } else {
                        toolsManager.output = output
                        result = ""
                    }
                }
            }
        } catch {
            toolsManager.output = "❌ Ошибка создания временного файла: \(error.localizedDescription)"
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

struct FamtoolView: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var familyName = ""
    @State private var operation = "generate" // generate, sign, verify
    @State private var routerKeysPath = ""
    @State private var routerInfoPath = ""
    @State private var familyCertPath = ""
    @State private var familyKeyPath = ""
    @State private var showingRouterKeysPicker = false
    @State private var showingRouterInfoPicker = false
    @State private var showingFamilyCertPicker = false
    @State private var showingFamilyKeyPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Инструкция"))
                    .font(.headline)
                Text(L("Family - дополнительный опознавательный признак роутера для предотвращения появления роутеров одного админа в одном туннеле. Практически не используется, но может быть полезен для организации роутеров."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Операция"))
                    .font(.headline)
                Picker(L("Операция"), selection: $operation) {
                    Text(L("Генерация сертификата")).tag("generate")
                    Text(L("Подпись роутера")).tag("sign")
                    Text(L("Проверка подписи")).tag("verify")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Название family"))
                    .font(.headline)
                TextField(L("Например: myfamily"), text: $familyName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            if operation == "generate" {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Выходные файлы"))
                        .font(.headline)
                    HStack {
                        TextField(L("family.crt"), text: $familyCertPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(L("Выбрать")) {
                            showingFamilyCertPicker = true
                        }
                    }
                    HStack {
                        TextField(L("family.pem"), text: $familyKeyPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(L("Выбрать")) {
                            showingFamilyKeyPicker = true
                        }
                    }
                }
            }
            
            if operation == "sign" {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Файлы роутера"))
                        .font(.headline)
                    HStack {
                        TextField(L("router.keys"), text: $routerKeysPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(L("Выбрать")) {
                            showingRouterKeysPicker = true
                        }
                    }
                    HStack {
                        TextField(L("router.info"), text: $routerInfoPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(L("Выбрать")) {
                            showingRouterInfoPicker = true
                        }
                    }
                    HStack {
                        TextField(L("family.pem"), text: $familyKeyPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(L("Выбрать")) {
                            showingFamilyKeyPicker = true
                        }
                    }
                }
            }
            
            if operation == "verify" {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Файлы для проверки"))
                        .font(.headline)
                    HStack {
                        TextField(L("family.crt"), text: $familyCertPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(L("Выбрать")) {
                            showingFamilyCertPicker = true
                        }
                    }
                    HStack {
                        TextField(L("router.info"), text: $routerInfoPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(L("Выбрать")) {
                            showingRouterInfoPicker = true
                        }
                    }
                }
            }
            
            Button(getButtonTitle()) {
                executeFamtool()
            }
            .disabled(!canExecute() || toolsManager.isRunning)
            
            if toolsManager.isRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("Выполнение..."))
                        .font(.caption)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Результат"))
                    .font(.headline)
                ScrollView {
                    Text(toolsManager.output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(height: 300)
            }
            
            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $showingRouterKeysPicker,
            allowedContentTypes: [.data, .text],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result, path: $routerKeysPath)
        }
        .fileImporter(
            isPresented: $showingRouterInfoPicker,
            allowedContentTypes: [.data, .text],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result, path: $routerInfoPath)
        }
        .fileImporter(
            isPresented: $showingFamilyCertPicker,
            allowedContentTypes: [.data, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result, path: $familyCertPath)
        }
        .fileImporter(
            isPresented: $showingFamilyKeyPicker,
            allowedContentTypes: [.data, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result, path: $familyKeyPath)
        }
    }
    
    private func getButtonTitle() -> String {
        switch operation {
        case "generate":
            return L("Генерировать сертификат family")
        case "sign":
            return L("Подписать роутер")
        case "verify":
            return L("Проверить подпись")
        default:
            return L("Выполнить")
        }
    }
    
    private func canExecute() -> Bool {
        if familyName.isEmpty {
            return false
        }
        
        switch operation {
        case "generate":
            return !familyCertPath.isEmpty && !familyKeyPath.isEmpty
        case "sign":
            return !routerKeysPath.isEmpty && !routerInfoPath.isEmpty && !familyKeyPath.isEmpty
        case "verify":
            return !familyCertPath.isEmpty && !routerInfoPath.isEmpty
        default:
            return false
        }
    }
    
    private func executeFamtool() {
        var arguments: [String] = []
        
        switch operation {
        case "generate":
            arguments = ["-g", "-n", familyName, "-c", familyCertPath, "-k", familyKeyPath]
        case "sign":
            arguments = ["-s", "-n", familyName, "-k", familyKeyPath, "-i", routerKeysPath, "-f", routerInfoPath]
        case "verify":
            arguments = ["-V", "-c", familyCertPath, "-f", routerInfoPath]
        default:
            return
        }
        
        toolsManager.runTool(name: "famtool", arguments: arguments) { output in
            DispatchQueue.main.async {
                if !output.isEmpty && !output.contains("❌") {
                    toolsManager.output = "✅ Операция famtool завершена!\n\n" + output
                } else {
                    toolsManager.output = output
                }
            }
        }
    }
    
    private func handleFileSelection(result: Result<[URL], Error>, path: Binding<String>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                path.wrappedValue = url.path
            }
        case .failure(let error):
            toolsManager.output = "❌ Ошибка выбора файла: \(error.localizedDescription)"
        }
    }
}

struct VerifyhostView: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var hostRecord = ""
    @State private var verificationResult = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Инструкция"))
                    .font(.headline)
                Text(L("Утилита проверяет подлинность хостов по их записям. Используется для проверки подписей регистрационных строк доменов .i2p и других криптографических записей."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Запись хоста"))
                    .font(.headline)
                TextEditor(text: $hostRecord)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Примеры записей"))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("• Регистрационная строка домена .i2p"))
                    Text(L("• Подписанная запись RouterInfo"))
                    Text(L("• Любая криптографическая запись с подписью"))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Примеры результатов"))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("• 'Valid destination' - подпись действительна"))
                    Text(L("• 'Destination signature not found' - подпись не найдена"))
                    Text(L("• 'Invalid destination signature' - подпись недействительна"))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Button(L("Проверить подпись")) {
                verifyHost()
            }
            .disabled(hostRecord.isEmpty || toolsManager.isRunning)
            
            if toolsManager.isRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("Проверка..."))
                        .font(.caption)
                }
            }
            
            if !verificationResult.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Результат проверки"))
                        .font(.headline)
                    HStack {
                        Text(verificationResult)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(L("Копировать")) {
                            copyToClipboard(verificationResult)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Полный вывод"))
                    .font(.headline)
                ScrollView {
                    Text(toolsManager.output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(height: 200)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func verifyHost() {
        if hostRecord.isEmpty {
            toolsManager.output = "❌ Введите запись хоста для проверки"
            return
        }
        
        // Экранируем специальные символы в записи хоста
        let escapedRecord = hostRecord.replacingOccurrences(of: "'", with: "\\'")
        
        toolsManager.runTool(name: "verifyhost", arguments: ["'\(escapedRecord)'"]) { output in
            DispatchQueue.main.async {
                if !output.isEmpty && !output.contains("❌") {
                    // Определяем результат проверки по выводу
                    if output.contains("Valid destination") {
                        verificationResult = "✅ Подпись действительна (Valid destination)"
                    } else if output.contains("Invalid destination signature") {
                        verificationResult = "❌ Подпись недействительна (Invalid destination signature)"
                    } else if output.contains("Destination signature not found") {
                        verificationResult = "⚠️ Подпись не найдена (Destination signature not found)"
                    } else {
                        verificationResult = "ℹ️ Результат проверки получен"
                    }
                    
                    toolsManager.output = "✅ Проверка подписи завершена!\n\n" + output
                } else {
                    toolsManager.output = output
                    verificationResult = ""
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

struct AutoconfView: View {
    @ObservedObject var toolsManager: ToolsManager
    @State private var terminalOutput = ""
    @State private var isProcessRunning = false
    @State private var process: Process?
    @State private var inputText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Инструкция"))
                    .font(.headline)
                Text(L("Утилита autoconf предназначена для интерактивного создания конфигурационного файла i2pd. Она задает множество вопросов о настройках роутера и генерирует готовый конфигурационный файл."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Особенности"))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("• Интерактивный режим с множественными вопросами"))
                    Text(L("• Поддержка различных типов конфигураций"))
                    Text(L("• Автоматическая генерация оптимальных настроек"))
                    Text(L("• Создание готового файла i2pd.conf"))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Типы конфигураций"))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("• Clearnet - обычная конфигурация"))
                    Text(L("• Only Yggdrasil - только сеть Yggdrasil"))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Интерактивный терминал
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Интерактивный терминал"))
                    .font(.headline)
                
                VStack(spacing: 8) {
                    // Область вывода терминала
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(terminalOutput.isEmpty ? L("Нажмите 'Запустить autoconf' для начала") : terminalOutput)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.black)
                                .foregroundColor(.green)
                                .cornerRadius(4)
                                .id("terminal-output") // ID для автопрокрутки
                        }
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: terminalOutput) {
                            // Автоматическая прокрутка к последней строке при обновлении
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("terminal-output", anchor: .bottom)
                            }
                        }
                    }
                    
                    // Поле ввода
                    HStack {
                        Text(">")
                            .foregroundColor(.green)
                        TextField(L("Введите ответ..."), text: $inputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                sendInput()
                            }
                    }
                    .font(.system(.caption, design: .monospaced))
                }
            }
            
            HStack(spacing: 12) {
                Button(L("Запустить autoconf")) {
                    startAutoconf()
                }
                .disabled(isProcessRunning)
                
                Button(L("Остановить")) {
                    stopProcess()
                }
                .disabled(!isProcessRunning)
                
                Button(L("Очистить")) {
                    terminalOutput = ""
                }
                .disabled(isProcessRunning)
            }
            
            if isProcessRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("Процесс выполняется..."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .onDisappear {
            // Останавливаем процесс при закрытии AutoconfView
            stopProcess()
        }
    }
    
    private func startAutoconf() {
        guard !isProcessRunning else { return }
        
        terminalOutput = ""
        isProcessRunning = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            self.process = process
            
            // Получаем путь к утилите autoconf
            let autoconfPath = toolsManager.getBundledToolPath(name: "autoconf")
            
            // Проверяем существование утилиты
            guard FileManager.default.fileExists(atPath: autoconfPath) else {
                DispatchQueue.main.async {
                    self.terminalOutput += "❌ Утилита 'autoconf' не найдена по пути: \(autoconfPath)\n"
                    self.isProcessRunning = false
                }
                return
            }
            
            process.executableURL = URL(fileURLWithPath: autoconfPath)
            process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
            
            // Настраиваем pipes для ввода/вывода
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Обработка вывода
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    DispatchQueue.main.async {
                        // Добавляем новую строку перед каждым новым выводом, если он не пустой
                        if !output.isEmpty {
                            // Если текущий вывод не заканчивается новой строкой, добавляем её
                            if !self.terminalOutput.isEmpty && !self.terminalOutput.hasSuffix("\n") {
                                self.terminalOutput += "\n"
                            }
                            self.terminalOutput += output
                        }
                    }
                }
            }
            
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let error = String(data: data, encoding: .utf8) ?? ""
                    DispatchQueue.main.async {
                        // Добавляем новую строку перед каждым новым выводом ошибки, если он не пустой
                        if !error.isEmpty {
                            // Если текущий вывод не заканчивается новой строкой, добавляем её
                            if !self.terminalOutput.isEmpty && !self.terminalOutput.hasSuffix("\n") {
                                self.terminalOutput += "\n"
                            }
                            self.terminalOutput += error
                        }
                    }
                }
            }
            
            do {
                try process.run()
                
                // Ждем завершения процесса
                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    self.isProcessRunning = false
                    self.process = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.terminalOutput += "❌ Ошибка запуска: \(error.localizedDescription)\n"
                    self.isProcessRunning = false
                    self.process = nil
                }
            }
        }
    }
    
    private func sendInput() {
        guard isProcessRunning, let process = process, !inputText.isEmpty else { return }
        
        let command = inputText
        let inputData = (command + "\n").data(using: .utf8)
        
        // Добавляем введённую команду в терминал для отображения
        DispatchQueue.main.async {
            // Если текущий вывод не заканчивается новой строкой, добавляем её
            if !self.terminalOutput.isEmpty && !self.terminalOutput.hasSuffix("\n") {
                self.terminalOutput += "\n"
            }
            self.terminalOutput += "> " + command + "\n"
            self.inputText = ""
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let inputPipe = process.standardInput as? Pipe {
                inputPipe.fileHandleForWriting.write(inputData ?? Data())
            }
        }
    }
    
    private func stopProcess() {
        process?.terminate()
        process?.waitUntilExit() // Ждём завершения процесса
        isProcessRunning = false
        process = nil
    }
}
