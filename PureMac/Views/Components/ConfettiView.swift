import SwiftUI

/// Tasteful one-shot confetti, redesigned away from the old harsh CAEmitter
/// rectangles. A `Canvas` + `TimelineView` particle system: mixed shapes
/// (streamers, discs, rings), a soft brand palette, gentle gravity with a
/// little horizontal sway, a 3D-style tumble, and a graceful fade. Fire with
/// `ConfettiView(trigger:)` — each rising edge fires one burst that quiets
/// itself. Honors Reduce Motion (renders nothing).
struct ConfettiView: View {
    enum Mode {
        /// Pieces spawn above the frame and flutter down (ambient rain).
        case rain
        /// Pieces explode radially from a point (anchored celebration —
        /// pair the origin with the visual element being celebrated).
        case burst(origin: UnitPoint)
    }

    /// Flip to fire a burst. Each rising edge fires once.
    let trigger: Bool
    var mode: Mode = .rain

    @State private var particles: [Particle] = []
    @State private var start: Date?
    @State private var generation = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let duration: TimeInterval = 2.6

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: start == nil)) { timeline in
                Canvas { ctx, size in
                    guard let start else { return }
                    let t = timeline.date.timeIntervalSince(start)
                    guard t <= duration else { return }

                    for particle in particles {
                        draw(particle, at: t, in: size, ctx: ctx)
                    }
                }
            }
            // The parent flips `trigger` (via .toggle()) as a fire pulse, so a
            // burst should play on ANY change — not just the rising edge, which
            // would skip every other cleanup.
            .onChange(of: trigger) { _ in
                fire(in: geo.size)
            }
            .allowsHitTesting(false)
        }
    }

    private func fire(in size: CGSize) {
        guard !reduceMotion, size.width > 0 else { return }

        switch mode {
        case .rain:
            particles = (0..<90).map { _ in Particle.random(width: size.width) }
        case .burst(let origin):
            let point = CGPoint(x: size.width * origin.x, y: size.height * origin.y)
            particles = (0..<90).map { _ in Particle.burst(from: point) }
        }

        start = Date()
        generation += 1
        let currentGeneration = generation

        // Quiet the timeline once the burst has fully faded so we don't keep
        // re-rendering an empty canvas. Guard on generation so a later burst
        // isn't cut short by an earlier burst's cleanup timer.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            guard generation == currentGeneration else { return }
            start = nil
            particles = []
        }
    }

    private func draw(
        _ particle: Particle,
        at time: Double,
        in size: CGSize,
        ctx: GraphicsContext
    ) {
        // Vertical: initial downward velocity + gravity. Horizontal: drift +
        // a sine sway so pieces flutter instead of dropping like stones.
        let x = particle.x0
            + particle.drift * time
            + particle.swayAmp * sin(particle.swayFreq * time + particle.phase)
        let y = particle.y0
            + particle.vy0 * time
            + 0.5 * particle.gravity * time * time

        guard y < size.height + 40 else { return }

        let fade: Double
        if time > particle.fadeStart {
            fade = max(0, 1 - (time - particle.fadeStart) / (duration - particle.fadeStart))
        } else {
            fade = 1
        }
        guard fade > 0.01 else { return }

        let angle = particle.spin * time
        // Tumble: squash one axis on a cosine so pieces appear to flip in 3D.
        let tumble = abs(cos(particle.tumbleSpeed * time + particle.phase))
        let width = particle.size.width * (0.25 + 0.75 * tumble)
        let height = particle.size.height

        var subcontext = ctx
        subcontext.translateBy(x: x, y: y)
        subcontext.rotate(by: .radians(angle))
        subcontext.opacity = fade

        let rect = CGRect(
            x: -width / 2,
            y: -height / 2,
            width: width,
            height: height
        )

        switch particle.shape {
        case .streamer:
            subcontext.fill(
                Path(roundedRect: rect, cornerRadius: min(width, height) * 0.45),
                with: .color(particle.color)
            )
        case .disc:
            let discRect = CGRect(
                x: -height / 2,
                y: -height / 2,
                width: height,
                height: height
            )
            subcontext.fill(Path(ellipseIn: discRect), with: .color(particle.color))
        case .ring:
            let radius = height / 2
            let ring = Path(ellipseIn: CGRect(
                x: -radius,
                y: -radius,
                width: height,
                height: height
            ))
            subcontext.stroke(
                ring,
                with: .color(particle.color),
                lineWidth: max(1.4, height * 0.22)
            )
        }
    }
}

private enum ConfettiShape: CaseIterable {
    case streamer
    case disc
    case ring
}

private struct Particle {
    var x0: CGFloat
    var y0: CGFloat
    var vy0: Double
    var gravity: Double
    var drift: Double
    var swayAmp: Double
    var swayFreq: Double
    var phase: Double
    var spin: Double
    var tumbleSpeed: Double
    var fadeStart: Double
    var color: Color
    var size: CGSize
    var shape: ConfettiShape

    /// Soft, slightly desaturated brand palette — premium, not garish.
    static let palette: [Color] = [
        Color(red: 0.27, green: 0.56, blue: 1.00),  // blue
        Color(red: 0.30, green: 0.80, blue: 0.56),  // green
        Color(red: 1.00, green: 0.66, blue: 0.30),  // amber
        Color(red: 0.62, green: 0.45, blue: 0.92),  // purple
        Color(red: 1.00, green: 0.46, blue: 0.62),  // pink
        Color(red: 0.36, green: 0.80, blue: 0.94),  // cyan
    ]

    /// Radial explosion from a fixed point.
    static func burst(from point: CGPoint) -> Particle {
        let shape = ConfettiShape.allCases.randomElement()!
        let dimensions: CGSize

        switch shape {
        case .streamer:
            dimensions = CGSize(width: .random(in: 5...8), height: .random(in: 11...16))
        case .disc:
            dimensions = CGSize(width: 9, height: .random(in: 7...10))
        case .ring:
            dimensions = CGSize(width: 10, height: .random(in: 9...13))
        }

        let angle = Double.random(in: 0...(2 * .pi))
        let speed = Double.random(in: 160...340)

        return Particle(
            x0: point.x,
            y0: point.y,
            vy0: sin(angle) * speed - .random(in: 140...220),
            gravity: .random(in: 240...340),
            drift: cos(angle) * speed,
            swayAmp: .random(in: 4...14),
            swayFreq: .random(in: 1.4...3.0),
            phase: .random(in: 0...(2 * .pi)),
            spin: .random(in: -6...6),
            tumbleSpeed: .random(in: 2.5...5.5),
            fadeStart: .random(in: 1.0...1.5),
            color: palette.randomElement()!,
            size: dimensions,
            shape: shape
        )
    }

    static func random(width: CGFloat) -> Particle {
        let shape = ConfettiShape.allCases.randomElement()!
        let dimensions: CGSize

        switch shape {
        case .streamer:
            dimensions = CGSize(width: .random(in: 5...8), height: .random(in: 11...16))
        case .disc:
            dimensions = CGSize(width: 9, height: .random(in: 7...10))
        case .ring:
            dimensions = CGSize(width: 10, height: .random(in: 9...13))
        }

        return Particle(
            x0: .random(in: 0...width),
            y0: .random(in: -60 ... -10),
            vy0: .random(in: 90...170),
            gravity: .random(in: 130...210),
            drift: .random(in: -40...40),
            swayAmp: .random(in: 8...26),
            swayFreq: .random(in: 1.4...3.0),
            phase: .random(in: 0...(2 * .pi)),
            spin: .random(in: -5...5),
            tumbleSpeed: .random(in: 2.5...5.5),
            fadeStart: .random(in: 1.3...1.9),
            color: palette.randomElement()!,
            size: dimensions,
            shape: shape
        )
    }
}
