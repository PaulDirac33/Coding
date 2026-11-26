//
//  CamoBackground.swift
//
//  Mimetica scura disegnata a codice: chiazze organiche verde-nero, oliva scuro e terra scura su fondo quasi nero.
//  Il seme è fisso: il disegno è sempre lo stesso, e si ridisegna solo se cambia la dimensione dello schermo.
//  Per regolarla: i colori e le dimensioni delle chiazze stanno in `CamoPainter.layers`.
//

import SwiftUI

struct CamoBackground: View {
    var body: some View {
        Canvas { context, size in
            CamoPainter.paint(in: &context, size: size)
        }
    }
}

/// Generatore di numeri casuali con seme: stessa sequenza a ogni avvio.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

nonisolated enum CamoPainter {

    /// Uno strato di chiazze: colore, quante (su uno schermo da iPhone) e raggio in frazione del lato corto.
    struct Layer {
        let red: Double
        let green: Double
        let blue: Double
        let count: Int
        let minRadius: CGFloat
        let maxRadius: CGFloat
    }

    /// Fondo quasi nero con una punta di verde.
    static let base = (red: 0.040, green: 0.048, blue: 0.036)

    /// Dal più grande e chiaro al più piccolo e scuro, così le chiazze piccole stanno sopra a quelle grandi.
    static let layers: [Layer] = [
        Layer(red: 0.070, green: 0.085, blue: 0.060, count: 16, minRadius: 0.18, maxRadius: 0.36),   // verde-nero
        Layer(red: 0.105, green: 0.125, blue: 0.085, count: 16, minRadius: 0.10, maxRadius: 0.24),   // oliva scuro
        Layer(red: 0.135, green: 0.118, blue: 0.085, count: 11, minRadius: 0.06, maxRadius: 0.17),   // terra scura
        Layer(red: 0.028, green: 0.032, blue: 0.026, count: 20, minRadius: 0.04, maxRadius: 0.13)    // quasi nero
    ]

    static func paint(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .color(Color(red: base.red, green: base.green, blue: base.blue)))

        let shortSide = min(size.width, size.height)
        // Più schermo = più chiazze, così la densità resta la stessa su iPhone e iPad.
        let density = max(0.6, Double(size.width * size.height) / (390 * 844))
        var rng = SeededGenerator(seed: 20_261_120)

        for layer in layers {
            let count = max(4, Int((Double(layer.count) * density).rounded()))
            let color = Color(red: layer.red, green: layer.green, blue: layer.blue)
            for _ in 0..<count {
                let cx = CGFloat.random(in: -0.05...1.05, using: &rng) * size.width
                let cy = CGFloat.random(in: -0.05...1.05, using: &rng) * size.height
                let radius = CGFloat.random(in: layer.minRadius...layer.maxRadius, using: &rng) * shortSide
                let stretch = CGFloat.random(in: 1.0...1.7, using: &rng)
                let turn = CGFloat.random(in: 0...(2 * .pi), using: &rng)
                let path = blob(center: CGPoint(x: cx, y: cy), radius: radius, stretch: stretch, turn: turn, rng: &rng)
                context.fill(path, with: .color(color))
            }
        }

        // Bordi più scuri: lo sguardo resta al centro e il vetro ha più contrasto vicino ai bordi.
        let vignette = Gradient(colors: [Color.clear, Color.black.opacity(0.55)])
        context.fill(Path(rect),
                     with: .radialGradient(vignette,
                                           center: CGPoint(x: size.width / 2, y: size.height * 0.45),
                                           startRadius: shortSide * 0.55,
                                           endRadius: max(size.width, size.height) * 0.85))
    }

    /// Una chiazza: ellisse irregolare, con i bordi ammorbiditi da curve.
    static func blob(center: CGPoint, radius: CGFloat, stretch: CGFloat, turn: CGFloat,
                     rng: inout SeededGenerator) -> Path {
        let count = Int.random(in: 9...13, using: &rng)
        var points: [CGPoint] = []
        for i in 0..<count {
            let angle = CGFloat(i) / CGFloat(count) * 2 * .pi
            let jitter = CGFloat.random(in: 0.60...1.30, using: &rng)
            let x = cos(angle) * radius * jitter * stretch
            let y = sin(angle) * radius * jitter / stretch
            points.append(CGPoint(x: center.x + x * cos(turn) - y * sin(turn),
                                  y: center.y + x * sin(turn) + y * cos(turn)))
        }
        var path = Path()
        let last = points[count - 1]
        let first = points[0]
        path.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
        for i in 0..<count {
            let p = points[i]
            let next = points[(i + 1) % count]
            path.addQuadCurve(to: CGPoint(x: (p.x + next.x) / 2, y: (p.y + next.y) / 2), control: p)
        }
        path.closeSubpath()
        return path
    }
}
