import SwiftUI
import Foundation
import AppKit

// MARK: - Убрать ANSI-коды из строки (только для проверки содержимого)
private func stripANSI(_ s: String) -> String {
    var result = ""
    var i = s.startIndex
    while i < s.endIndex {
        if s[i] == "\u{1B}" {
            var j = s.index(after: i)
            guard j < s.endIndex else { result.append(s[i]); i = s.index(after: i); continue }
            if s[j] == "[" {
                j = s.index(after: j)
                while j < s.endIndex && (s[j].isNumber || s[j] == ";" || s[j] == "?") { j = s.index(after: j) }
                if j < s.endIndex { j = s.index(after: j) }
                i = j
                continue
            }
        }
        result.append(s[i])
        i = s.index(after: i)
    }
    return result
}

// MARK: - Убрать приглашение "YOU:" и пустые строки из вывода чата
private func filterYouPrompt(_ output: String) -> String {
    let normalized = output.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    return normalized
        .components(separatedBy: "\n")
        .filter { line in
            let plain = stripANSI(line).trimmingCharacters(in: .whitespacesAndNewlines)
            if plain.isEmpty { return false }
            if plain == "YOU:" || plain.hasPrefix("YOU:") { return false }
            return true
        }
        .joined(separator: "\n")
}

// MARK: - Парсер ANSI escape-кодов в NSAttributedString (подсветка чата)
private func attributedString(fromANSI ansiString: String, font: NSFont) -> NSAttributedString {
    let result = NSMutableAttributedString()
    var current: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.textColor
    ]
    var i = ansiString.startIndex
    while i < ansiString.endIndex {
        if ansiString[i] == "K" && (i == ansiString.startIndex || ansiString[ansiString.index(before: i)] == "\n") {
            i = ansiString.index(after: i)
            continue
        }
        if ansiString[i] == "\u{1B}" {
            var j = ansiString.index(after: i)
            guard j < ansiString.endIndex, ansiString[j] == "[" else { i = j; continue }
            j = ansiString.index(after: j)
            var codes: [Int] = []
            var num = 0
            var consumedTerminator = false
            while j < ansiString.endIndex {
                let c = ansiString[j]
                if c == "m" {
                    j = ansiString.index(after: j)
                    consumedTerminator = true
                    break
                }
                if c == ";" {
                    codes.append(num)
                    num = 0
                    j = ansiString.index(after: j)
                    continue
                }
                if c.isNumber {
                    num = num * 10 + Int(String(c))!
                    j = ansiString.index(after: j)
                    continue
                }
                break
            }
            if num != 0 { codes.append(num) }
            i = j
            if !consumedTerminator && j < ansiString.endIndex {
                i = ansiString.index(after: j)
            }
            if codes.count >= 3, codes[0] == 38, codes[1] == 5, (0..<256).contains(codes[2]) {
                current[.foregroundColor] = color256(codes[2])
            }
            for code in codes {
                switch code {
                case 0:
                    current[.font] = font
                    current[.foregroundColor] = NSColor.textColor
                case 1:
                    current[.font] = font
                case 22:
                    current[.font] = font
                case 30: current[.foregroundColor] = NSColor.black
                case 31: current[.foregroundColor] = NSColor.systemRed
                case 32: current[.foregroundColor] = NSColor.systemGreen
                case 33: current[.foregroundColor] = NSColor.systemOrange
                case 34: current[.foregroundColor] = NSColor.systemBlue
                case 35: current[.foregroundColor] = NSColor.systemPurple
                case 36: current[.foregroundColor] = NSColor.systemCyan
                case 37: current[.foregroundColor] = NSColor.white
                case 39: current[.foregroundColor] = NSColor.textColor
                default: break
                }
            }
            continue
        }
        let nextI = ansiString.index(after: i)
        let ch = String(ansiString[i..<nextI])
        result.append(NSAttributedString(string: ch, attributes: current))
        i = nextI
    }
    return result
}

// MARK: - Разные цвета для блоков Local Destination и Local Private Key
private func applyKeySectionColors(to mutable: NSMutableAttributedString) {
    let s = mutable.string
    let destLabel = "Local Destination:"
    let keyLabel = "Local Private Key:"
    let systemMarker = "[SYSTEM]:"
    
    func blockRange(from startRange: Range<String.Index>) -> NSRange? {
        let rest = s[startRange.upperBound...]
        if let next = rest.range(of: "\n" + systemMarker) {
            let end = next.lowerBound
            return NSRange(startRange.lowerBound..<end, in: s)
        }
        return NSRange(startRange.lowerBound..<s.endIndex, in: s)
    }
    
    if let r1 = s.range(of: destLabel), let nsRange1 = blockRange(from: r1) {
        mutable.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: nsRange1)
    }
    if let r2 = s.range(of: keyLabel), let nsRange2 = blockRange(from: r2) {
        mutable.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: nsRange2)
    }
}

// MARK: - Один и тот же размер шрифта для строк [PEER]: как у [YOU]
private func applyPeerFont(to mutable: NSMutableAttributedString, font: NSFont) {
    let s = mutable.string
    var searchStart = s.startIndex
    while searchStart < s.endIndex, let r = s.range(of: "[PEER]:", range: searchStart..<s.endIndex) {
        let lineStart = s[..<r.lowerBound].lastIndex(of: "\n").map { s.index(after: $0) } ?? s.startIndex
        let lineEnd = s[r.upperBound...].firstIndex(of: "\n") ?? s.endIndex
        let lineRange = NSRange(lineStart..<lineEnd, in: s)
        mutable.addAttribute(.font, value: font, range: lineRange)
        searchStart = lineEnd
    }
}

private func color256(_ index: Int) -> NSColor {
    if index < 16 {
        let table: [NSColor] = [
            .black, .systemRed, .systemGreen, .systemYellow, .systemBlue,
            .systemPurple, .systemCyan, .white, .gray, .systemRed,
            .systemGreen, .systemYellow, .systemBlue, .systemPurple, .systemCyan, .white
        ]
        return table[index % 16]
    }
    if index >= 232 {
        let g = Double(index - 232) / 23.0
        return NSColor(white: g, alpha: 1)
    }
    let r = Double((index / 36) % 6) / 5.0
    let g = Double((index / 6) % 6) / 5.0
    let b = Double(index % 6) / 5.0
    return NSColor(red: r, green: g, blue: b, alpha: 1)
}

// MARK: - Текстовое поле с перехватом клавиш для PTY
private final class TerminalTextView: NSTextView {
    var onKey: ((String, UInt16) -> Void)?
    var onPaste: ((String) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        // Cmd+V — вставка из буфера (не отправлять "v" в PTY)
        if event.modifierFlags.contains(.command), event.keyCode == 9 {
            paste(nil)
            return
        }
        let keyCode = event.keyCode
        // Стрелки вверх/вниз — скролл чата (не отправлять в PTY)
        if keyCode == 126 || keyCode == 125, let scrollView = enclosingScrollView {
            let lineHeight = layoutManager?.defaultLineHeight(for: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)) ?? 14
            let clipView = scrollView.contentView
            var origin = clipView.bounds.origin
            if keyCode == 126 {
                origin.y = max(0, origin.y - lineHeight)
            } else {
                let maxY = max(0, frame.height - clipView.bounds.height)
                origin.y = min(maxY, origin.y + lineHeight)
            }
            clipView.scroll(to: origin)
            return
        }
        guard let onKey = onKey else { super.keyDown(with: event); return }
        let chars = event.characters ?? ""
        var toSend = ""
        if keyCode == 36 {
            // Отправить сообщение — только одиночный Enter без Shift.
            // Новая строка: Shift+Enter, удержание Shift затем Enter, или удержание Enter (повтор).
            let fromEvent = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
            let fromCurrent = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
            let shiftHeld = fromEvent || fromCurrent
            let newlineOnly = shiftHeld || event.isARepeat
            toSend = newlineOnly ? "\n" : "\r\n"
        } else if keyCode == 51 || keyCode == 117 {
            toSend = "\u{7f}"
        } else if keyCode == 48 {
            toSend = "\t"
        } else if !chars.isEmpty {
            toSend = chars
        }
        if !toSend.isEmpty {
            onKey(toSend, keyCode)
            return
        }
        super.keyDown(with: event)
    }
    
    override func paste(_ sender: Any?) {
        guard let onPaste = onPaste else { super.paste(sender); return }
        let pasteboard = NSPasteboard.general
        guard let str = pasteboard.string(forType: .string), !str.isEmpty else { return }
        onPaste(str)
    }
    
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(paste(_:)) {
            guard onPaste != nil else { return false }
            return NSPasteboard.general.string(forType: .string) != nil
        }
        if item.action == #selector(copy(_:)) {
            return selectedRange().length > 0
        }
        return super.validateUserInterfaceItem(item)
    }
    
    override func copy(_ sender: Any?) {
        let selected = selectedRange()
        guard selected.length > 0,
              let content = textStorage?.string,
              let range = Range(selected, in: content) else { return }
        let str = String(content[range])
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(str, forType: .string)
    }
}

// MARK: - Поле ввода чата: Enter — отправить, Shift+Enter — новая строка
private final class ChatInputTextView: NSTextView, NSTextViewDelegate {
    var onSubmit: (() -> Void)?
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 {
            if event.modifierFlags.contains(.shift) {
                super.keyDown(with: event)
            } else {
                onSubmit?()
            }
            return
        }
        super.keyDown(with: event)
    }
}

struct ChatInputView: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        
        let textView = ChatInputTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.minSize = NSSize(width: 0, height: 44)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 100)
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        textView.onSubmit = { [onSubmit] in onSubmit() }
        
        scroll.documentView = textView
        context.coordinator.textView = textView
        return scroll
    }
    
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? ChatInputTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.onSubmit = onSubmit
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputView
        fileprivate var textView: ChatInputTextView?
        
        init(_ parent: ChatInputView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Только вывод (как в интерактивном терминале автоконфигурации)
struct ChatOutputView: NSViewRepresentable {
    @ObservedObject var runner: PTYRunner
    
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor.black
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.minSize = NSSize(width: 200, height: 150)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width, .height]
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.drawsBackground = true
        textView.backgroundColor = .black
        
        scroll.documentView = textView
        context.coordinator.textView = textView
        return scroll
    }
    
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        let newOutput = runner.output
        if context.coordinator.lastOutput != newOutput {
            context.coordinator.lastOutput = newOutput
            let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            let filtered = filterYouPrompt(newOutput)
            let attributed = attributedString(fromANSI: filtered, font: font)
            let mutable = NSMutableAttributedString(attributedString: attributed)
            applyKeySectionColors(to: mutable)
            applyPeerFont(to: mutable, font: font)
            textView.textStorage?.setAttributedString(mutable)
            scrollToBottom(scroll: scroll, textView: textView)
        }
    }
    
    private func scrollToBottom(scroll: NSScrollView, textView: NSTextView) {
        textView.scrollRangeToVisible(NSRange(location: max(0, textView.string.count - 1), length: 1))
        DispatchQueue.main.async {
            let docView = scroll.documentView
            let clipView = scroll.contentView
            let docHeight = docView?.frame.height ?? 0
            let clipHeight = clipView.bounds.height
            if docHeight > clipHeight {
                var origin = clipView.bounds.origin
                origin.y = docHeight - clipHeight
                clipView.scroll(to: origin)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        fileprivate var textView: NSTextView?
        fileprivate var lastOutput = ""
    }
}

// MARK: - Chat Window View (интерактивный терминал: вывод + поле ввода, как автоконфигурация)
struct ChatWindowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissWindow) private var dismissWindow
    @StateObject private var runner = PTYRunner()
    @State private var inputText = ""
    
    private var chatBinaryPath: String {
        if let resourcePath = Bundle.main.resourcePath {
            let bundlePath = "\(resourcePath)/tools/termchat-i2p"
            if FileManager.default.fileExists(atPath: bundlePath) {
                return bundlePath
            }
        }
        if let execPath = Bundle.main.executablePath {
            let execDir = (execPath as NSString).deletingLastPathComponent
            let nextToApp = "\(execDir)/termchat-i2p"
            if FileManager.default.fileExists(atPath: nextToApp) { return nextToApp }
            let inTools = "\(execDir)/tools/termchat-i2p"
            if FileManager.default.fileExists(atPath: inTools) { return inTools }
        }
        return ""
    }
    
    private var chatBinaryExists: Bool { !chatBinaryPath.isEmpty }
    
    var body: some View {
        VStack(spacing: 0) {
            if let err = runner.errorMessage {
                Text(err)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(8)
            }
            
            if !chatBinaryExists {
                Text(L("Бинарник termchat-i2p не найден. Соберите его и поместите в папку tools приложения или рядом с приложением."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(24)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ChatOutputView(runner: runner)
                        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 280, maxHeight: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    HStack(alignment: .top, spacing: 8) {
                        Text(">")
                            .foregroundColor(.green)
                            .font(.system(.body, design: .monospaced))
                            .padding(.top, 8)
                        ZStack(alignment: .topLeading) {
                            ChatInputView(text: $inputText, onSubmit: { sendLine() })
                            if inputText.isEmpty {
                                Text(L("Введите сообщение..."))
                                    .foregroundColor(Color(nsColor: .placeholderTextColor))
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(minHeight: 44, maxHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .background(Color(NSColor.textBackgroundColor))
                        Button(L("Отправить")) {
                            sendLine()
                        }
                        .keyboardShortcut(.return, modifiers: .command)
                    }
                    .font(.system(.body, design: .monospaced))
                }
                .padding(12)
            }
        }
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        .onAppear {
            if chatBinaryExists && !runner.isRunning {
                runner.executablePath = chatBinaryPath
                runner.start()
            }
        }
        .onDisappear {
            runner.stop()
            NotificationCenter.default.post(name: NSNotification.Name("ChatWindowDidClose"), object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ApplicationWillTerminate"))) { _ in
            runner.stop()
        }
    }
    
    private func sendLine() {
        guard runner.isRunning else { return }
        let line = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        runner.write(line + "\r\n")
        inputText = ""
    }
}
