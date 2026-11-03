import AppKit
import SwiftUI

// MARK: - Appearance (light / dark / system)

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - Colour themes
//
// Four quiet, heritage-inspired palettes. Every theme pairs a deep accent with
// brass hairlines on an ivory (light) or ink-green/blue (dark) canvas.

enum ThemeID: String, CaseIterable, Identifiable {
    case forest, navy, claret, stone

    var id: String { rawValue }

    static let storageKey = "PureMac.Theme"

    /// Read straight from UserDefaults so `Tint` stays usable from any context.
    static var current: ThemeID {
        ThemeID(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .forest
    }

    var label: String {
        switch self {
        case .forest: return "Forest"
        case .navy: return "Navy"
        case .claret: return "Claret"
        case .stone: return "Stone"
        }
    }

    struct Swatch {
        let accentLight, accentDark: UInt32
        let brassLight, brassDark: UInt32
        let canvasLight, canvasDark: UInt32
        let surfaceLight, surfaceDark: UInt32
        let sidebarLight, sidebarDark: UInt32
    }

    var swatch: Swatch {
        switch self {
        case .forest:
            return Swatch(accentLight: 0x1F5C45, accentDark: 0x4A9573,
                          brassLight: 0x9A7B3A, brassDark: 0xC9A55C,
                          canvasLight: 0xF5F1E8, canvasDark: 0x101713,
                          surfaceLight: 0xFCFAF4, surfaceDark: 0x18211C,
                          sidebarLight: 0xEDE8DB, sidebarDark: 0x0C120F)
        case .navy:
            return Swatch(accentLight: 0x24456B, accentDark: 0x5A8BC2,
                          brassLight: 0x9A7B3A, brassDark: 0xC9A55C,
                          canvasLight: 0xF3F1EB, canvasDark: 0x0E141B,
                          surfaceLight: 0xFBFAF6, surfaceDark: 0x161F29,
                          sidebarLight: 0xEAE7DF, sidebarDark: 0x0A0F15)
        case .claret:
            return Swatch(accentLight: 0x7A2E3A, accentDark: 0xB5596A,
                          brassLight: 0x9A7B3A, brassDark: 0xC9A55C,
                          canvasLight: 0xF6F0E9, canvasDark: 0x161011,
                          surfaceLight: 0xFCF9F4, surfaceDark: 0x211819,
                          sidebarLight: 0xEEE6DC, sidebarDark: 0x100B0C)
        case .stone:
            return Swatch(accentLight: 0x45433E, accentDark: 0x7A756A,
                          brassLight: 0x8F7A4E, brassDark: 0xBBA374,
                          canvasLight: 0xF2F0EB, canvasDark: 0x141311,
                          surfaceLight: 0xFAF9F6, surfaceDark: 0x1F1D1A,
                          sidebarLight: 0xE9E6DF, sidebarDark: 0x0E0D0C)
        }
    }

    /// Accent for previews (theme picker), independent of the active theme.
    var accentColor: Color { dynamicColor(light: swatch.accentLight, dark: swatch.accentDark) }
    var brassColor: Color { dynamicColor(light: swatch.brassLight, dark: swatch.brassDark) }
    var canvasColor: Color { dynamicColor(light: swatch.canvasLight, dark: swatch.canvasDark) }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// A colour that follows the *effective* appearance, so it flips with the
/// light/dark switch (including the app-level override) without a re-render.
func dynamicColor(light: UInt32, dark: UInt32) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return NSColor(hex: isDark ? dark : light)
    })
}

/// Surfaces used across the app. Replaces the stock system backgrounds.
enum Palette {
    static var canvas: Color {
        let s = ThemeID.current.swatch
        return dynamicColor(light: s.canvasLight, dark: s.canvasDark)
    }
    static var surface: Color {
        let s = ThemeID.current.swatch
        return dynamicColor(light: s.surfaceLight, dark: s.surfaceDark)
    }
    static var sidebar: Color {
        let s = ThemeID.current.swatch
        return dynamicColor(light: s.sidebarLight, dark: s.sidebarDark)
    }
    static var hairline: Color { Color.primary.opacity(0.09) }
}

// MARK: - Theme manager

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("PureMac.Appearance") private var rawValue = AppearanceMode.system.rawValue

    private init() {
        applyToApp()
    }

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: rawValue) ?? .system }
        set {
            rawValue = newValue.rawValue
            objectWillChange.send()
            applyToApp()
        }
    }

    /// The active colour theme. Persisted; views that should refresh live
    /// attach `.id(theme.themeID)` (MainWindow does this for you).
    var themeID: ThemeID {
        get { ThemeID.current }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: ThemeID.storageKey)
            objectWillChange.send()
        }
    }

    func applyToApp() {
        NSApplication.shared.appearance = appearance.nsAppearance
    }
}

// MARK: - Tints
//
// Same names as before so every existing view re-themes automatically, but the
// values are now muted heritage tones: sage, ochre, oxblood, slate, plum.

enum Tint {
    static var accent: Color {
        let s = ThemeID.current.swatch
        return dynamicColor(light: s.accentLight, dark: s.accentDark)
    }
    static var brass: Color {
        let s = ThemeID.current.swatch
        return dynamicColor(light: s.brassLight, dark: s.brassDark)
    }
    static var teal: Color { accent }

    static var blue: Color { dynamicColor(light: 0x3E5C7A, dark: 0x8FB0CE) }
    static var green: Color { dynamicColor(light: 0x3F7A58, dark: 0x86B898) }
    static var orange: Color { dynamicColor(light: 0xB5792B, dark: 0xE0AE6A) }
    static var purple: Color { dynamicColor(light: 0x6E5A80, dark: 0xB5A0C8) }
    static var pink: Color { dynamicColor(light: 0xA5576B, dark: 0xD99BAA) }
    static var cyan: Color { dynamicColor(light: 0x3F7F82, dark: 0x86BFC0) }
    static var red: Color { dynamicColor(light: 0x8E2F35, dark: 0xD9777B) }
    static var yellow: Color { brass }
}

// MARK: - Type
//
// Serif for titles and big numbers (New York on macOS), SF for everything else.

enum Typo {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

// MARK: - Motion

enum MotionTokens {
    static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let gentle = Animation.spring(response: 0.46, dampingFraction: 0.88)
    static let press = Animation.easeOut(duration: 0.1)
    static let settle = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.5)
}

enum TintGradient {
    static var accent: LinearGradient {
        LinearGradient(
            colors: [Tint.accent.opacity(0.94), Tint.accent],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    static var smartCare: LinearGradient {
        LinearGradient(
            colors: [Palette.surface, Palette.canvas],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    static var destructive: LinearGradient {
        LinearGradient(
            colors: [Tint.red.opacity(0.94), Tint.red],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func of(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color.opacity(0.94), color], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Building blocks

struct IconTile: View {
    let systemName: String
    var tint: Color = Tint.accent
    var size: CGFloat = 26
    var corner: CGFloat = 7
    var glow = false
    var vivid = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(vivid ? tint : tint.opacity(glow ? 0.18 : 0.11))
                .overlay {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(tint.opacity(vivid ? 0.22 : 0.18), lineWidth: 0.5)
                }
            Image(systemName: systemName)
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(vivid ? Color.white : tint)
        }
        .frame(width: size, height: size)
    }
}

struct AmbientBackdrop: View {
    var body: some View {
        Palette.canvas
            .ignoresSafeArea()
    }
}

struct CardSurface<Content: View>: View {
    var padding: CGFloat = 16
    var accent: Color? = nil
    var elevation: CardElevation = .standard
    var material: Material? = nil
    var tint: Color? = nil
    @ViewBuilder var content: Content

    private let cornerRadius: CGFloat = 12

    var body: some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    if let material {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(material)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Palette.surface)
                    }
                    if let tint {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(0.04))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 0.5)
            }
            .overlay(alignment: .top) {
                if let accent {
                    Capsule()
                        .fill(accent.opacity(0.8))
                        .frame(width: 36, height: 2)
                        .padding(.top, 1)
                }
            }
            .shadow(
                color: .black.opacity(elevation.ambient),
                radius: elevation.ambientRadius,
                y: elevation.ambientY
            )
    }
}

enum CardElevation {
    case flat, standard, raised

    var ambient: Double {
        switch self {
        case .flat: return 0
        case .standard: return 0.035
        case .raised: return 0.08
        }
    }

    var ambientRadius: CGFloat {
        switch self {
        case .flat: return 0
        case .standard: return 8
        case .raised: return 22
        }
    }

    var ambientY: CGFloat {
        switch self {
        case .flat: return 0
        case .standard: return 2
        case .raised: return 9
        }
    }
}

struct StatusChip: View {
    let label: String
    var systemImage: String? = nil
    var tint: Color = Tint.accent

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(tint)
        .background(Capsule().fill(tint.opacity(0.10)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.18), lineWidth: 0.5))
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(Typo.display(16))
    }
}

struct PressableScale: ViewModifier {
    @State private var hovering = false
    @State private var pressing = false
    var hoverScale: CGFloat = 1.006
    var lift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1 : pressing ? 0.985 : hovering ? hoverScale : 1)
            .shadow(color: .black.opacity(lift && hovering ? 0.07 : 0), radius: 12, y: 5)
            .animation(reduceMotion ? nil : MotionTokens.snappy, value: hovering)
            .animation(reduceMotion ? nil : MotionTokens.press, value: pressing)
            .onHover { hovering = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressing = true }
                    .onEnded { _ in pressing = false }
            )
    }
}

extension View {
    func pressable(hoverScale: CGFloat = 1.006, lift: Bool = false) -> some View {
        modifier(PressableScale(hoverScale: hoverScale, lift: lift))
    }
}

struct GlowProminentButtonStyle: ButtonStyle {
    var tint: Color = Tint.accent
    var gradient: LinearGradient = TintGradient.accent
    var breathes = false
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 14 : 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, large ? 22 : 16)
            .padding(.vertical, large ? 11 : 8)
            .background(Capsule().fill(gradient))
            .overlay(Capsule().strokeBorder(Tint.brass.opacity(0.55), lineWidth: 0.75))
            .shadow(color: tint.opacity(configuration.isPressed ? 0 : 0.22), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(MotionTokens.press, value: configuration.isPressed)
    }
}

struct AnimatedCheckboxStyle: ToggleStyle {
    var tint: Color = Tint.accent

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(configuration.isOn ? tint : Color.primary.opacity(0.04))
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(configuration.isOn ? tint : Color.primary.opacity(0.26), lineWidth: 1)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(configuration.isOn ? 1 : 0.4)
                    .opacity(configuration.isOn ? 1 : 0)
            }
            .frame(width: 16, height: 16)
            .animation(MotionTokens.snappy, value: configuration.isOn)
            configuration.label
        }
        .contentShape(Rectangle())
        .onTapGesture { configuration.isOn.toggle() }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.checkbox)
        }
    }
}

// MARK: - ======== Motion & loading components (formerly Craft.swift) ========


// MARK: - Loading: shimmer + skeletons

/// A soft light sweep used on skeletons and progress bars. Does nothing under
/// Reduce Motion.
struct ShimmerSweep: View {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            if !reduceMotion {
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(colorScheme == .dark ? 0.10 : 0.55),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.55)
                .offset(x: -geo.size.width * 0.55 + phase * geo.size.width * 1.55)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Placeholder block shown while real content is loading.
struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12
    var corner: CGFloat = 5

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.primary.opacity(0.07))
            .frame(width: width, height: height)
            .overlay(ShimmerSweep())
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Progress bar

/// Thin capsule progress bar with a slow sheen while work is in flight.
struct GildedProgressBar: View {
    let value: Double
    var height: CGFloat = 6
    var tint: Color = Tint.accent
    var showsSheen = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { max(0, min(1, value)) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.78), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height, geo.size.width * clamped))
                    .overlay {
                        if showsSheen && clamped < 1 { ShimmerSweep() }
                    }
                    .clipShape(Capsule())
                    .opacity(clamped > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: clamped)
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }
}

// MARK: - Status dot

/// Small dot with a slow halo, for "ready / live" states.
struct BreathingDot: View {
    var tint: Color = Tint.green
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.25))
                .frame(width: 14, height: 14)
                .scaleEffect(pulse ? 1.25 : 0.7)
                .opacity(pulse ? 0 : 0.8)
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
        }
        .frame(width: 14, height: 14)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - The dial
//
// One memorable element: a watch-dial emblem. Brass hairline bezel, sixty
// ticks, a progress arc, and a slow sweep while PureMac is working. It is
// driven by real scan / cleanup progress, so it always means something.

struct DialEmblem: View {
    enum Mode: Equatable {
        case idle(used: Double)
        case scanning(Double)
        case review
        case cleaning(Double)
        case success

        var isWorking: Bool {
            switch self {
            case .scanning, .cleaning: return true
            default: return false
            }
        }
    }

    let mode: Mode
    var size: CGFloat = 190
    var title: String
    var caption: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        switch mode {
        case .idle(let used): return max(0, min(1, used))
        case .scanning(let p), .cleaning(let p): return max(0, min(1, p))
        case .review, .success: return 1
        }
    }

    private var tint: Color {
        switch mode {
        case .idle(let used): return used >= 0.9 ? Tint.orange : Tint.accent
        case .scanning: return Tint.accent
        case .review: return Tint.brass
        case .cleaning: return Tint.orange
        case .success: return Tint.green
        }
    }

    private var arcInset: CGFloat { size * 0.13 }
    private var arcWidth: CGFloat { max(5, size * 0.035) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !mode.isWorking || reduceMotion)) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill(Palette.surface)
                    .shadow(color: .black.opacity(0.09), radius: size * 0.09, y: size * 0.04)
                Circle()
                    .strokeBorder(Tint.brass.opacity(0.6), lineWidth: 1)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    .padding(size * 0.035)

                ticks

                if mode.isWorking && !reduceMotion {
                    sweep(at: seconds)
                }

                Circle()
                    .stroke(Color.primary.opacity(0.07), lineWidth: arcWidth)
                    .padding(arcInset)
                Circle()
                    .trim(from: 0, to: max(0.012, progress))
                    .stroke(tint, style: StrokeStyle(lineWidth: arcWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(arcInset)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.55), value: progress)

                center
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : MotionTokens.gentle, value: mode)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(caption))
        .accessibilityValue(Text(title))
    }

    private var ticks: some View {
        Canvas { (context: GraphicsContext, canvasSize: CGSize) in
            let center = CGPoint(
                x: canvasSize.width / 2,
                y: canvasSize.height / 2
            )

            let radius: CGFloat =
                min(canvasSize.width, canvasSize.height) / 2
                - canvasSize.width * 0.075

            for index in 0..<60 {
                let isMajor = index % 5 == 0

                let angle: Double =
                    (Double(index) / 60.0) * 2.0 * Double.pi
                    - Double.pi / 2.0

                let inset: CGFloat = isMajor
                    ? self.size * 0.05
                    : self.size * 0.028

                let innerRadius: CGFloat = radius - inset

                let path = Self.makeTickPath(
                    center: center,
                    innerRadius: innerRadius,
                    outerRadius: radius,
                    angle: angle
                )

                let tickColor: Color = isMajor
                    ? Tint.brass.opacity(0.85)
                    : Color.primary.opacity(0.16)

                let tickWidth: CGFloat = isMajor ? 1.3 : 0.7

                context.stroke(
                    path,
                    with: .color(tickColor),
                    lineWidth: tickWidth
                )
            }
        }
        .allowsHitTesting(false)
    }

    private static func makeTickPath(
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        angle: Double
    ) -> Path {
        let cosine = CGFloat(cos(angle))
        let sine = CGFloat(sin(angle))

        let startPoint = CGPoint(
            x: center.x + cosine * innerRadius,
            y: center.y + sine * innerRadius
        )
        let endPoint = CGPoint(
            x: center.x + cosine * outerRadius,
            y: center.y + sine * outerRadius
        )

        var path = Path()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        return path
    }

    private func sweep(at seconds: TimeInterval) -> some View {
        let degrees = (seconds * 72).truncatingRemainder(dividingBy: 360)
        return Circle()
            .fill(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: tint.opacity(0), location: 0),
                        .init(color: tint.opacity(0), location: 0.62),
                        .init(color: tint.opacity(0.26), location: 1)
                    ]),
                    center: .center
                )
            )
            .padding(size * 0.2)
            .rotationEffect(.degrees(degrees))
    }

    @ViewBuilder
    private var center: some View {
        if mode == .success {
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.2, weight: .medium))
                .foregroundStyle(Tint.green)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
            VStack(spacing: 2) {
                Text(title)
                    .font(Typo.display(size * 0.15))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text(caption)
                    .font(.system(size: max(9.5, size * 0.055), weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size * 0.5)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: title)
        }
    }
}

// MARK: - Theme picker

struct ThemePicker: View {
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ThemeID.allCases) { id in
                let selected = theme.themeID == id
                Button {
                    withAnimation(MotionTokens.snappy) { theme.themeID = id }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(id.canvasColor)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                            Circle()
                                .fill(id.accentColor)
                                .padding(6)
                            Circle()
                                .fill(id.brassColor)
                                .frame(width: 5, height: 5)
                        }
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle()
                                .strokeBorder(id.brassColor, lineWidth: selected ? 1.5 : 0)
                                .padding(-4)
                        )
                        Text(id.label)
                            .font(.system(size: 10.5, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? .primary : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(id.label))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// Popover content: colour theme + light/dark.
struct AppearancePanel: View {
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Color theme")
                    .font(.system(size: 12, weight: .semibold))
                ThemePicker()
            }
            Divider()
            HStack {
                Text("Appearance")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                AppearancePill(selection: Binding(
                    get: { theme.appearance },
                    set: { theme.appearance = $0 }
                ))
            }
        }
        .padding(16)
        .frame(width: 270)
    }
}
