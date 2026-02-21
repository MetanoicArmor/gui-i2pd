import SwiftUI
import Foundation
import AppKit

// MARK: - Парсер ANSI escape-кодов в NSAttributedString (подсветка чата)
private func attributedString(fromANSI ansiString: String, font: NSFont) -> NSAttributedString {
    let result = NSMutableAttributedString()
    var current: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.textColor
    ]
    var i = ansiString.startIndex
    while i < ansiString.endIndex {
        if ansiString[i] == "\u{1B}" {
            var j = ansiString.index(after: i)
            guard j < ansiString.endIndex, ansiString[j] == "[" else { i = j; continue }
            j = ansiString.index(after: j)
            var codes: [Int] = []
            var num = 0
            while j < ansiString.endIndex {
                let c = ansiString[j]
                if c == "m" {
                    j = ansiString.index(after: j)
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
            if codes.count >= 3, codes[0] == 38, codes[1] == 5, (0..<256).contains(codes[2]) {
                current[.foregroundColor] = color256(codes[2])
            } else {
                for code in codes {
                    switch code {
                    case 0:
                        current[.font] = font
                        current[.foregroundColor] = NSColor.textColor
                    case 1:
                        current[.font] = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)
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
            let lineHeight = layoutManager?.defaultLineHeight(for: font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)) ?? 14
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

// MARK: - Встроенный терминал (вывод + ввод с клавиатуры)
struct EmbeddedTerminalView: NSViewRepresentable {
    @ObservedObject var runner: PTYRunner
    
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor.textBackgroundColor
        
        let textView = TerminalTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.minSize = NSSize(width: 200, height: 150)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width, .height]
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.onKey = { [weak runner] str, _ in
            runner?.write(str)
        }
        textView.onPaste = { [weak runner] str in
            runner?.write(str)
        }
        
        scroll.documentView = textView
        context.coordinator.textView = textView
        return scroll
    }
    
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? TerminalTextView else { return }
        let newOutput = runner.output
        if context.coordinator.lastOutput != newOutput {
            context.coordinator.lastOutput = newOutput
            let font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            let attributed = attributedString(fromANSI: newOutput, font: font)
            textView.textStorage?.setAttributedString(attributed)
            scrollToBottom(scroll: scroll, textView: textView)
        }
        if runner.isRunning && scroll.window?.firstResponder != textView {
            scroll.window?.makeFirstResponder(textView)
        }
    }
    
    private func scrollToBottom(scroll: NSScrollView, textView: NSTextView) {
        textView.scrollRangeToVisible(NSRange(location: max(0, textView.string.count - 1), length: 1))
        DispatchQueue.main.async {
            textView.scrollRangeToVisible(NSRange(location: max(0, textView.string.count - 1), length: 1))
            let docView = scroll.documentView
            let clipView = scroll.contentView
            let docHeight = docView?.frame.height ?? 0
            let clipHeight = clipView.bounds.height
            if docHeight > clipHeight {
                var origin = clipView.bounds.origin
                origin.y = docHeight - clipHeight
                clipView.scroll(to: origin)
            }
            textView.window?.makeFirstResponder(textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        fileprivate var textView: TerminalTextView?
        fileprivate var lastOutput = ""
    }
}

// MARK: - Chat Window View (встроенный чат через PTY)
struct ChatWindowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissWindow) private var dismissWindow
    @StateObject private var runner = PTYRunner()
    
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
            HStack {
                Text(L("Чат I2P"))
                    .font(.headline)
                Spacer()
                if runner.isRunning {
                    Button(L("Остановить")) {
                        runner.stop()
                    }
                    .buttonStyle(.bordered)
                }
                Button(L("Закрыть")) {
                    runner.stop()
                    dismissWindow(id: "chat")
                    dismiss()
                    NotificationCenter.default.post(name: NSNotification.Name("ChatWindowDidClose"), object: nil)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            
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
                EmbeddedTerminalView(runner: runner)
                    .frame(minWidth: 500, maxWidth: .infinity, minHeight: 350, maxHeight: .infinity)
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
}
