import SwiftUI

struct ParticleEmitterConfig {
    var count: Int = 60
    var spawnRate: Double = 20
    var lifetime: ClosedRange<Double> = 1.5...3.0
    var velocity: ClosedRange<CGFloat> = 30...80
    var angleRange: ClosedRange<Double> = (-.pi / 2 - 0.3)...(-.pi / 2 + 0.3)
    var gravity: CGFloat = -40
    var size: ClosedRange<CGFloat> = 1.5...3.5
    var color: Color = Color.unbound.accent
    var fadeOutStart: Double = 0.6
    var spread: CGFloat = 60

    static let embers = ParticleEmitterConfig(
        count: 80, spawnRate: 25,
        lifetime: 2.0...3.8,
        velocity: 20...60,
        angleRange: (-.pi / 2 - 0.4)...(-.pi / 2 + 0.4),
        gravity: -35,
        size: 1.0...2.5,
        color: Color.unbound.impact,
        spread: 120
    )

    static let sparks = ParticleEmitterConfig(
        count: 40, spawnRate: 80,
        lifetime: 0.4...0.9,
        velocity: 120...260,
        angleRange: 0...(.pi * 2),
        gravity: 120,
        size: 1.5...3.0,
        color: Color.unbound.accent,
        spread: 10
    )

    static let shatter = ParticleEmitterConfig(
        count: 60, spawnRate: 600,
        lifetime: 0.5...1.0,
        velocity: 200...420,
        angleRange: 0...(.pi * 2),
        gravity: 220,
        size: 2.0...4.5,
        color: Color.unbound.textPrimary,
        spread: 8
    )
}

private struct Particle {
    let id: UUID
    let birth: TimeInterval
    let lifetime: Double
    let origin: CGPoint
    let velocity: CGVector
    let size: CGFloat
    let hueShift: Double
}

struct ParticleEmitter: View {
    var config: ParticleEmitterConfig
    var isActive: Bool = true

    @State private var particles: [Particle] = []
    @State private var lastSpawn: TimeInterval = 0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
                let now = ctx.date.timeIntervalSinceReferenceDate
                let origin = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                Canvas { canvas, size in
                    for p in particles {
                        let age = now - p.birth
                        guard age <= p.lifetime else { continue }
                        let t = age / p.lifetime
                        let fade: Double
                        if t < config.fadeOutStart {
                            fade = 1.0
                        } else {
                            fade = 1.0 - (t - config.fadeOutStart) / (1.0 - config.fadeOutStart)
                        }
                        let x = p.origin.x + p.velocity.dx * CGFloat(age)
                        let y = p.origin.y + p.velocity.dy * CGFloat(age) + 0.5 * config.gravity * CGFloat(age * age)
                        let rect = CGRect(x: x - p.size / 2, y: y - p.size / 2, width: p.size, height: p.size)
                        canvas.fill(Path(ellipseIn: rect), with: .color(config.color.opacity(fade)))
                    }
                }
                .onChange(of: now) { _, newValue in
                    tick(now: newValue, origin: origin)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func tick(now: TimeInterval, origin: CGPoint) {
        particles.removeAll { now - $0.birth > $0.lifetime }
        guard isActive else { return }
        if lastSpawn == 0 { lastSpawn = now }
        let toSpawn = Int((now - lastSpawn) * config.spawnRate)
        guard toSpawn > 0 else { return }
        lastSpawn = now
        for _ in 0..<min(toSpawn, config.count) {
            let angle = Double.random(in: config.angleRange)
            let speed = CGFloat.random(in: config.velocity)
            let jitterX = CGFloat.random(in: -config.spread...config.spread)
            let jitterY = CGFloat.random(in: -config.spread / 3...config.spread / 3)
            particles.append(Particle(
                id: UUID(),
                birth: now,
                lifetime: Double.random(in: config.lifetime),
                origin: CGPoint(x: origin.x + jitterX, y: origin.y + jitterY),
                velocity: CGVector(dx: CGFloat(cos(angle)) * speed, dy: CGFloat(sin(angle)) * speed),
                size: CGFloat.random(in: config.size),
                hueShift: Double.random(in: -0.05...0.05)
            ))
        }
        if particles.count > config.count * 4 {
            particles.removeFirst(particles.count - config.count * 4)
        }
    }
}

#Preview("Embers") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        ParticleEmitter(config: .embers)
    }
}

#Preview("Sparks") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        ParticleEmitter(config: .sparks)
    }
}
