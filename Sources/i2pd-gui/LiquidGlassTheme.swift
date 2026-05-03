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
    var usesTranslucentSheetChrome = false

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
            window.titlebarAppearsTransparent = usesTranslucentSheetChrome
            window.titleVisibility = usesTranslucentSheetChrome ? .hidden : .visible
            window.titlebarSeparatorStyle = usesTranslucentSheetChrome ? .none : .automatic
            window.isMovableByWindowBackground = false
        } else {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .visible
            window.titlebarSeparatorStyle = .none
            var mask = window.styleMask
            mask.insert(.fullSizeContentView)
            mask.remove(.resizable)
            window.styleMask = mask
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

private struct LiquidGlassSidebarChromeModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let tintOpacity: Double
    let surfaceTintOpacity: Double
    let shadowOpacity: Double

    /// До macOS 26: как в тёмной теме — sidebar + вуаль + белые слои; в светлой вуаль слабее, чтобы линза читалась прозрачнее.
    private var legacyVeilOpacity: Double {
        colorScheme == .dark ? 0.16 : 0.044
    }

    /// macOS 26+: та же схема, что в dark — только `glassEffect` + тинт + `surfaceTint`, без отдельной чёрной вуали.
    /// В светлой теме тинт через `primary` (дымчатое стекло); базовая непрозрачность ниже, чем раньше, чтобы не «забивать» blur.
    private var glassTintColor: Color {
        if colorScheme == .dark {
            Color.white.opacity(tintOpacity)
        } else {
            Color.primary.opacity(0.024 + tintOpacity * 0.42)
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            content
                .background {
                    shape.fill(Color(NSColor.windowBackgroundColor))
                }
                .modifier(LiquidGlassEdgeModifier(cornerRadius: cornerRadius, reduceTransparency: true))
                .shadow(color: Color.black.opacity(shadowOpacity), radius: 24, x: 0, y: 14)
        } else if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    Glass.regular.tint(glassTintColor),
                    in: shape
                )
                .overlay {
                    shape.fill(Color.white.opacity(surfaceTintOpacity))
                        .allowsHitTesting(false)
                }
                .modifier(LiquidGlassEdgeModifier(cornerRadius: cornerRadius, reduceTransparency: false))
                .shadow(color: Color.black.opacity(shadowOpacity), radius: 24, x: 0, y: 14)
        } else {
            content
                .background {
                    ZStack {
                        LiquidGlassBackdrop(material: .sidebar, blendingMode: .behindWindow)
                            .clipShape(shape)

                        shape.fill(Color.black.opacity(legacyVeilOpacity))
                            .allowsHitTesting(false)
                        shape.fill(Color.white.opacity(colorScheme == .dark ? tintOpacity : tintOpacity * 0.65))
                            .allowsHitTesting(false)
                        shape.fill(Color.white.opacity(surfaceTintOpacity))
                            .allowsHitTesting(false)
                    }
                    .clipShape(shape)
                }
                .modifier(LiquidGlassEdgeModifier(cornerRadius: cornerRadius, reduceTransparency: false))
                .shadow(color: Color.black.opacity(shadowOpacity), radius: 24, x: 0, y: 14)
        }
    }
}

private struct LiquidGlassEdgeModifier: ViewModifier {
    let cornerRadius: CGFloat
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LiquidGlassTheme.glassEdge, lineWidth: reduceTransparency ? 0.9 : 0.8)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: max(cornerRadius - 1, 0), style: .continuous)
                    .strokeBorder(LiquidGlassTheme.innerGlassEdge, lineWidth: 0.55)
                    .padding(1)
                    .allowsHitTesting(false)
            }
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
    func liquidGlassWindow(usesTranslucentSheetChrome: Bool = false) -> some View {
        background {
            LiquidGlassWindowConfigurator(usesTranslucentSheetChrome: usesTranslucentSheetChrome)
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

    /// Матовая полоска заголовка (`regularMaterial`), без `glassEffect` — как блок «Сетевая статистика».
    /// «Жидкая линза» только через `liquidGlassSidebarChrome` (логи, хром настроек и т.п.).
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

    func liquidGlassSidebarChrome(
        cornerRadius: CGFloat = 22,
        tintOpacity: Double = 0.035,
        surfaceTintOpacity: Double = 0.0,
        shadowOpacity: Double = 0.12
    ) -> some View {
        modifier(
            LiquidGlassSidebarChromeModifier(
                cornerRadius: cornerRadius,
                tintOpacity: tintOpacity,
                surfaceTintOpacity: surfaceTintOpacity,
                shadowOpacity: shadowOpacity
            )
        )
    }

    func liquidGlassSelection(isSelected: Bool) -> some View {
        modifier(LiquidGlassSelectedModifier(isSelected: isSelected))
    }
}
