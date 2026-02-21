import Foundation
import Darwin

/// Запуск процесса в псевдо-терминале (PTY) для интерактивного TUI.
final class PTYRunner: ObservableObject {
    /// PID запущенных чат-процессов (для гарантированного завершения при выходе из приложения)
    private static var knownChatPids: Set<pid_t> = []
    private static let pidLock = NSLock()
    
    static func killAllKnownChatProcesses() {
        pidLock.lock()
        let pids = knownChatPids
        knownChatPids.removeAll()
        pidLock.unlock()
        for pid in pids where pid > 0 {
            if kill(pid, 0) == 0 { kill(pid, SIGKILL) }
        }
    }
    
    @Published private(set) var output = ""
    @Published private(set) var isRunning = false
    @Published var errorMessage: String?
    
    private var masterFD: Int32 = -1
    private var process: Process?
    private var readSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "pty.read")
    
    /// Путь к исполняемому файлу
    var executablePath: String?
    
    /// Запуск процесса с PTY
    func start() {
        guard let path = executablePath, !path.isEmpty else {
            errorMessage = "Путь к termchat-i2p не задан"
            return
        }
        guard FileManager.default.fileExists(atPath: path) else {
            errorMessage = "Файл не найден: \(path)"
            return
        }
        
        errorMessage = nil
        output = ""
        
        var master: Int32 = -1, slave: Int32 = -1
        
#if os(macOS)
        if openpty(&master, &slave, nil, nil, nil) == -1 {
            errorMessage = "Не удалось создать PTY (openpty): \(String(cString: strerror(errno)))"
            return
        }
#else
        master = posix_openpt(O_RDWR)
        if master == -1 {
            errorMessage = "posix_openpt: \(String(cString: strerror(errno)))"
            return
        }
        if grantpt(master) != 0 || unlockpt(master) != 0 {
            close(master)
            errorMessage = "grantpt/unlockpt failed"
            return
        }
        guard let name = ptsname(master) else {
            close(master)
            errorMessage = "ptsname failed"
            return
        }
        slave = open(name, O_RDWR)
        if slave == -1 {
            close(master)
            errorMessage = "open(slave) failed"
            return
        }
#endif
        
        masterFD = master
        
        var term = termios()
        if tcgetattr(slave, &term) == 0 {
            term.c_lflag |= tcflag_t(ECHO | ECHOE | ICANON)
            withUnsafeMutablePointer(to: &term) { p in
                let raw = UnsafeMutableRawPointer(p)
                let ccOffset = 4 * MemoryLayout<tcflag_t>.size
                (raw + ccOffset).assumingMemoryBound(to: UInt8.self)[2] = 0x7f
            }
            tcsetattr(slave, TCSANOW, &term)
        }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = []
        proc.currentDirectoryURL = URL(fileURLWithPath: (path as NSString).deletingLastPathComponent)
        
        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        proc.standardInput = slaveHandle
        proc.standardOutput = slaveHandle
        proc.standardError = slaveHandle
        
        do {
            try proc.run()
            close(slave)
            process = proc
            isRunning = true
            Self.pidLock.lock()
            Self.knownChatPids.insert(proc.processIdentifier)
            Self.pidLock.unlock()
        } catch {
            close(slave)
            close(master)
            masterFD = -1
            errorMessage = "Запуск: \(error.localizedDescription)"
            return
        }
        
        _ = fcntl(master, F_SETFL, fcntl(master, F_GETFL) | O_NONBLOCK)
        
        readSource = DispatchSource.makeReadSource(fileDescriptor: master, queue: queue)
        readSource?.setEventHandler { [weak self] in
            self?.readFromMaster()
        }
        readSource?.resume()
    }
    
    private func readFromMaster() {
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = read(masterFD, &buf, buf.count)
        guard n > 0 else {
            if n == 0 {
                DispatchQueue.main.async { [weak self] in
                    self?.processDidTerminate()
                }
            }
            return
        }
        let data = Data(bytes: buf, count: n)
        guard let str = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let next = self.output + str
            self.output = self.applyBackspace(next)
        }
    }
    
    /// Интерпретирует \\b в выводе: каждый backspace удаляет предыдущий символ (видимое стирание).
    private func applyBackspace(_ s: String) -> String {
        var result = [Character]()
        for c in s {
            if c == "\u{8}" {
                if !result.isEmpty { result.removeLast() }
            } else {
                result.append(c)
            }
        }
        return String(result)
    }
    
    /// Отправить ввод в процесс (символы или строку)
    func write(_ string: String) {
        guard isRunning, masterFD >= 0 else { return }
        guard let data = string.data(using: .utf8) else { return }
        let fd = masterFD
        let count = data.count
        queue.async {
            guard fd >= 0 else { return }
            data.withUnsafeBytes { ptr in
                _ = Darwin.write(fd, ptr.baseAddress, count)
            }
        }
    }
    
    /// Отправить нажатие Enter
    func sendEnter() {
        write("\r\n")
    }
    
    /// Очистить буфер вывода (для кнопки «Очистить» в UI)
    func clearOutput() {
        output = ""
    }
    
    func stop() {
        guard let proc = process else {
            processDidTerminate(removePidFromSet: true)
            return
        }
        let pid = proc.processIdentifier
        proc.terminate()
        // Не удаляем PID из knownChatPids сразу — иначе при быстром выходе из приложения
        // killAllKnownChatProcesses() не убьёт процесс. Удалим после SIGKILL в отложенном блоке.
        processDidTerminate(removePidFromSet: false)
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
            if pid > 0 && kill(pid, 0) == 0 {
                kill(pid, SIGKILL)
            }
            Self.pidLock.lock()
            Self.knownChatPids.remove(pid)
            Self.pidLock.unlock()
            DispatchQueue.main.async {
                self?.process = nil
                self?.isRunning = false
            }
        }
    }
    
    private func processDidTerminate(removePidFromSet: Bool = true) {
        readSource?.cancel()
        readSource = nil
        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }
        if removePidFromSet, let pid = process?.processIdentifier {
            Self.pidLock.lock()
            Self.knownChatPids.remove(pid)
            Self.pidLock.unlock()
        }
        process = nil
        isRunning = false
    }
    
    deinit {
        stop()
    }
}
