import SwiftUI
import AppKit

struct LiquidGlassBackdrop: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true
    }
}

struct LiquidGlassWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: view.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        let isSheet = window.sheetParent != nil
        window.isOpaque = false
        window.backgroundColor = .clear
        if isSheet {
            // Лист/модалка: не fullSizeContentView — иначе контент уезжает под скруглённую
            // кромку окна (эффект «срезания» сверху/снизу) и мешает ScrollView.
            var mask = window.styleMask
            mask.remove(.fullSizeContentView)
            window.styleMask = mask
            window.titlebarAppearsTransparent = false
            window.isMovableByWindowBackground = false
        } else {
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
        }
        window.hasShadow = true
    }
}

enum LiquidGlassTheme {
    static let windowPadding: CGFloat = 12
    static let panelRadius: CGFloat = 18
    static let controlRadius: CGFloat = 12
    static let subtleTint = Color.white.opacity(0.035)
    static let darkShadow = Color.black.opacity(0.16)

    static var glassEdge: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.34),
                Color.white.opacity(0.14),
                Color.black.opacity(0.08),
                Color.white.opacity(0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var innerGlassEdge: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.16),
                Color.white.opacity(0.04),
                Color.black.opacity(0.07),
                Color.white.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct LiquidGlassPanelModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let cornerRadius: CGFloat
    let material: Material
    let tintOpacity: Double
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        reduceTransparency
                            ? AnyShapeStyle(Color(NSColor.windowBackgroundColor))
                            : AnyShapeStyle(material)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(reduceTransparency ? tintOpacity * 0.5 : tintOpacity))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(LiquidGlassTheme.glassEdge, lineWidth: reduceTransparency ? 0.8 : 0.7)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: max(cornerRadius - 1, 0), style: .continuous)
                            .strokeBorder(LiquidGlassTheme.innerGlassEdge, lineWidth: 0.45)
                            .padding(1)
                    }
            }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 18, x: 0, y: 10)
    }
}

private struct LiquidGlassSelectedModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .fill(
                            reduceTransparency
                                ? AnyShapeStyle(Color.accentColor.opacity(0.14))
                                : AnyShapeStyle(.regularMaterial)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                                .fill(Color.accentColor.opacity(0.22))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                                .strokeBorder(LiquidGlassTheme.glassEdge, lineWidth: 0.7)
                        }
                } else {
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .fill(Color.clear)
                }
            }
    }
}

extension View {
    func liquidGlassWindow() -> some View {
        background {
            LiquidGlassWindowConfigurator()
                .frame(width: 0, height: 0)
        }
    }

    func liquidGlassPanel(
        cornerRadius: CGFloat = LiquidGlassTheme.panelRadius,
        material: Material = .regularMaterial,
        tintOpacity: Double = 0.035,
        shadowOpacity: Double = 0.08
    ) -> some View {
        modifier(
            LiquidGlassPanelModifier(
                cornerRadius: cornerRadius,
                material: material,
                tintOpacity: tintOpacity,
                shadowOpacity: shadowOpacity
            )
        )
    }

    func liquidGlassHeader(cornerRadius: CGFloat = 14) -> some View {
        modifier(
            LiquidGlassPanelModifier(
                cornerRadius: cornerRadius,
                material: .regularMaterial,
                tintOpacity: 0.03,
                shadowOpacity: 0.025
            )
        )
    }

    func liquidGlassToolbar(cornerRadius: CGFloat = 14) -> some View {
        modifier(
            LiquidGlassPanelModifier(
                cornerRadius: cornerRadius,
                material: .bar,
                tintOpacity: 0.006,
                shadowOpacity: 0.0
            )
        )
    }

    func liquidGlassSelection(isSelected: Bool) -> some View {
        modifier(LiquidGlassSelectedModifier(isSelected: isSelected))
    }
}
