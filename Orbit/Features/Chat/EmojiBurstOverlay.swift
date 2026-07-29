import SwiftUI

struct EmojiBurstOverlay: View {
    let effect: BurstEffect
    var onFinished: () -> Void

    private struct Particle: Identifiable {
        let id = UUID()
        let x: CGFloat; let size: CGFloat; let delay: Double
        let duration: Double; let rotation: Double
    }

    @State private var particles: [Particle] = []
    @State private var falling = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Text(effect.emoji)
                        .font(.system(size: p.size))
                        .rotationEffect(.degrees(falling ? p.rotation : 0))
                        .position(x: p.x * geo.size.width,
                                  y: falling ? geo.size.height + 60 : -60)
                        .animation(.easeIn(duration: p.duration).delay(p.delay), value: falling)
                }
            }
        }
        .onAppear {
            particles = (0..<24).map { _ in
                Particle(x: .random(in: 0.05...0.95), size: .random(in: 26...44),
                         delay: .random(in: 0...0.5), duration: .random(in: 1.2...2.0),
                         rotation: .random(in: -180...180))
            }
            DispatchQueue.main.async { falling = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { onFinished() }
        }
    }
}
