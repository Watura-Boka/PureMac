import SwiftUI

struct EmptyStateView: View {
    let title: LocalizedStringKey
    let systemImage: String
    let description: LocalizedStringKey
    var action: (() -> Void)?
    var actionLabel: LocalizedStringKey?
    /// Icon tint. Positive states pass a colour (e.g. green for "All Clean");
    /// neutral states use the theme accent.
    var tint: Color?

    @State private var appeared = false
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ title: LocalizedStringKey, systemImage: String, description: LocalizedStringKey,
         action: (() -> Void)? = nil, actionLabel: LocalizedStringKey? = nil, tint: Color? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.action = action
        self.actionLabel = actionLabel
        self.tint = tint
    }

    private var color: Color { tint ?? Tint.accent }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Palette.surface)
                    .frame(width: 104, height: 104)
                    .shadow(color: .black.opacity(0.07), radius: 14, y: 6)
                Circle()
                    .strokeBorder(Tint.brass.opacity(0.55), lineWidth: 1)
                    .frame(width: 104, height: 104)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    .frame(width: 92, height: 92)
                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(color)
            }
            // One quiet entrance, then a barely-there breath. Both skipped
            // under Reduce Motion.
            .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .scaleEffect(breathing ? 1.025 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(MotionTokens.settle) { appeared = true }
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }

            Text(title)
                .font(Typo.display(21))
                .staggered(0, baseDelay: 0.08)
            Text(description)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .staggered(1, baseDelay: 0.08)
            if let action, let label = actionLabel {
                Button(action: action) { Text(label) }
                    .buttonStyle(GlowProminentButtonStyle())
                    .padding(.top, 4)
                    .staggered(2, baseDelay: 0.08)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
