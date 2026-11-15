//
//  CartridgeIcon.swift
//
//  Le cartucce dell'app (tasto dell'arma, miniature, schede senza foto), disegnate in scala reale:
//  stessa grafica di prima (palla a tinta piena, bossolo al 62%, colore preso da foregroundStyle),
//  ma con le quote vere delle due cartucce e qualche particolare in più.
//
//  QUOTE (mm), massimi C.I.P. riportati da Wikipedia e dai cataloghi:
//    9x21 IMI   palla 9,03 · collo 9,63 · base 9,93 · orlo 9,96 × 1,27 · bossolo 21,15 · totale 29,75
//    .22 LR     palla 5,7  · corpo 5,7 (5,74) · orlo 7,1 × 1,1 · bossolo 15,6 · totale 25,4
//  Sono stime (non vengono dalle tabelle C.I.P.): la gola dell'estrattore, gli smussi, il profilo
//  dell'ogiva e le scanalature della palla del .22. Si regolano nelle due costanti `CartridgeSpec` qui sotto.
//
//  Le due cartucce hanno la stessa scala: il 9x21 riempie esattamente `height`, il .22 LR resta più
//  corto e più stretto in proporzione, come nella realtà.
//

import SwiftUI

// MARK: - Quale cartuccia

/// Quale cartuccia disegnare. Un calibro non ricaricabile (il 22 LR) è a percussione anulare: bossolo con l'orlo.
enum CartridgeStyle {
    case pistol     // 9x21 e simili: bossolo dritto, leggermente conico, con la gola dell'estrattore
    case rimfire    // 22 LR: orlo largo alla base, palla di piombo con le scanalature, spessa come il bossolo

    fileprivate var spec: CartridgeSpec {
        switch self {
        case .pistol: return .nineByTwentyOne
        case .rimfire: return .twentyTwoLR
        }
    }
}

extension Caliber {
    var cartridgeStyle: CartridgeStyle { allowsReload ? .pistol : .rimfire }
}

// MARK: - Misure

/// Tutte le misure in millimetri. Le quote verticali (y) si contano dalla punta della palla verso il fondello.
fileprivate struct CartridgeSpec {
    // Quote C.I.P.
    let overall: CGFloat          // lunghezza totale della cartuccia
    let caseLength: CGFloat       // lunghezza del bossolo
    let rimDiameter: CGFloat      // diametro dell'orlo
    let rimThickness: CGFloat     // spessore dell'orlo
    let baseDiameter: CGFloat     // diametro del bossolo vicino al fondello
    let neckDiameter: CGFloat     // diametro del bossolo alla bocca
    let bulletDiameter: CGFloat   // diametro della palla

    // Forma della palla (stime)
    let noseLength: CGFloat       // dalla punta fin dove l'ogiva diventa cilindro
    let tipRadius: CGFloat        // arrotondamento della punta

    // Particolari (stime)
    let grooveWidth: CGFloat      // gola dell'estrattore: larghezza (0 = non c'è)
    let grooveDepth: CGFloat      // gola dell'estrattore: profondità per lato
    let baseChamfer: CGFloat      // smusso del fondello
    let lubeGrooves: [CGFloat]    // quota (y) delle scanalature della palla

    /// Dove comincia il bossolo (la bocca).
    var mouthY: CGFloat { overall - caseLength }

    static let nineByTwentyOne = CartridgeSpec(
        overall: 29.75, caseLength: 21.15, rimDiameter: 9.96, rimThickness: 1.27,
        baseDiameter: 9.93, neckDiameter: 9.63, bulletDiameter: 9.03,
        noseLength: 6.0, tipRadius: 1.8,
        grooveWidth: 0.80, grooveDepth: 0.42, baseChamfer: 0.30, lubeGrooves: [])

    static let twentyTwoLR = CartridgeSpec(
        overall: 25.4, caseLength: 15.6, rimDiameter: 7.1, rimThickness: 1.1,
        baseDiameter: 5.74, neckDiameter: 5.74, bulletDiameter: 5.70,
        noseLength: 4.9, tipRadius: 1.25,
        grooveWidth: 0, grooveDepth: 0, baseChamfer: 0.15, lubeGrooves: [6.1, 7.6])
}

// MARK: - Geometria

/// Naso della palla: ogiva tangente con la punta arrotondata (come una palla FMJ o una palla di piombo tonda).
/// Restituisce i punti della metà destra, dalla punta (0, 0) al raccordo con la parte cilindrica (r, length);
/// x = distanza dall'asse, y = quota dalla punta, in mm.
fileprivate func nosePoints(radius r: CGFloat, length: CGFloat, tip rt: CGFloat,
                            tipSteps: Int = 8, ogiveSteps: Int = 20) -> [CGPoint] {
    // Raggio dell'arco dell'ogiva, in modo che raccordi la punta (raggio rt) e il cilindro (raggio r).
    let bigR = ((length - rt) * (length - rt) - rt * rt + r * r) / (2 * (r - rt))
    let ogiveCenter = CGPoint(x: -(bigR - r), y: length)
    let tipCenter = CGPoint(x: 0, y: rt)

    // Punto in cui la calotta della punta e l'ogiva si toccano.
    var dx = tipCenter.x - ogiveCenter.x
    var dy = tipCenter.y - ogiveCenter.y
    let d = hypot(dx, dy)
    dx /= d
    dy /= d
    let tangent = atan2(dy, dx)

    var points: [CGPoint] = []
    let start = -CGFloat.pi / 2                       // la punta, sull'asse
    for i in 0...tipSteps {
        let a = start + (tangent - start) * CGFloat(i) / CGFloat(tipSteps)
        points.append(CGPoint(x: tipCenter.x + rt * cos(a), y: tipCenter.y + rt * sin(a)))
    }
    for i in 1...ogiveSteps {
        let a = tangent * (1 - CGFloat(i) / CGFloat(ogiveSteps))
        points.append(CGPoint(x: ogiveCenter.x + bigR * cos(a), y: ogiveCenter.y + bigR * sin(a)))
    }
    return points
}

/// Chiude la sagoma: metà destra dall'alto in basso, poi la sua immagine speculare dal basso in alto.
fileprivate func symmetricPath(_ half: [CGPoint], map: (CGPoint) -> CGPoint) -> Path {
    var path = Path()
    guard let first = half.first else { return path }
    path.move(to: map(first))
    for p in half.dropFirst() { path.addLine(to: map(p)) }
    for p in half.reversed() { path.addLine(to: map(CGPoint(x: -p.x, y: p.y))) }
    path.closeSubpath()
    return path
}

/// Fascia verticale (mm) con il raggio del pezzo che attraversa: serve a far cadere luce e ombra
/// sul diametro giusto (l'orlo del .22 è più largo del suo bossolo).
fileprivate struct LightBand {
    let y0: CGFloat
    let y1: CGFloat
    let radius: CGFloat
}

/// Segno scuro su tutta la larghezza (gola, bocca, scanalature).
fileprivate struct DarkMark {
    let y0: CGFloat
    let y1: CGFloat
    let darkness: Double
}

// MARK: - Vista

/// Cartuccia in scala reale. Prende il colore da foregroundStyle.
struct CartridgeIcon: View {
    var style: CartridgeStyle = .pistol
    var height: CGFloat = 24

    /// Spazio (mm) fra la bocca del bossolo e la palla: è la sottile riga che le separa, come nel disegno di prima.
    /// Mettilo a 0 per la palla incastrata nel bossolo senza stacco.
    private static let mouthGap: CGFloat = 0.35

    // MARK: Scala

    private var spec: CartridgeSpec { style.spec }

    /// Punti per millimetro: il 9x21 occupa tutta l'altezza.
    private var unit: CGFloat { height / CartridgeSpec.nineByTwentyOne.overall }
    private var width: CGFloat { spec.rimDiameter * unit }
    /// Margine in alto: il .22, più corto, resta centrato in verticale.
    private var top: CGFloat { (height - spec.overall * unit) / 2 }

    /// Da millimetri (x dall'asse, y dalla punta) a punti nella vista.
    private func pt(_ p: CGPoint) -> CGPoint {
        CGPoint(x: width / 2 + p.x * unit, y: top + p.y * unit)
    }

    // MARK: Sagome

    private var bulletEnd: CGFloat { spec.mouthY - Self.mouthGap }

    private var bulletPath: Path {
        let s = spec
        var half = nosePoints(radius: s.bulletDiameter / 2, length: s.noseLength, tip: s.tipRadius)
        half.append(CGPoint(x: s.bulletDiameter / 2, y: bulletEnd))
        return symmetricPath(half, map: { pt($0) })
    }

    private var casePath: Path {
        let s = spec
        let base = s.baseDiameter / 2
        let neck = s.neckDiameter / 2
        let rim = s.rimDiameter / 2
        let bottom = s.overall
        let flangeTop = bottom - s.rimThickness
        let chamfer = s.baseChamfer

        // Dalla bocca verso il fondello (il bossolo del 9x21 è appena conico: 9,63 → 9,93).
        var half: [CGPoint] = [CGPoint(x: neck, y: s.mouthY)]
        if s.grooveWidth > 0 {
            let grooveTop = flangeTop - s.grooveWidth
            let grooveRadius = base - s.grooveDepth
            half.append(CGPoint(x: base, y: grooveTop))
            half.append(CGPoint(x: grooveRadius, y: grooveTop + 0.22))
            half.append(CGPoint(x: grooveRadius, y: flangeTop - 0.02))
        } else {
            half.append(CGPoint(x: base, y: flangeTop))
        }
        half.append(CGPoint(x: rim - 0.08, y: flangeTop))
        half.append(CGPoint(x: rim, y: flangeTop + 0.08))
        half.append(CGPoint(x: rim, y: bottom - chamfer))
        half.append(CGPoint(x: rim - chamfer, y: bottom))
        return symmetricPath(half, map: { pt($0) })
    }

    // MARK: Luci e segni

    private var bulletLights: [LightBand] {
        [LightBand(y0: 0, y1: bulletEnd, radius: spec.bulletDiameter / 2)]
    }

    private var caseLights: [LightBand] {
        let s = spec
        let flangeTop = s.overall - s.rimThickness
        if s.grooveWidth > 0 {
            return [LightBand(y0: s.mouthY, y1: s.overall, radius: s.rimDiameter / 2)]
        }
        return [LightBand(y0: s.mouthY, y1: flangeTop, radius: s.baseDiameter / 2),
                LightBand(y0: flangeTop, y1: s.overall, radius: s.rimDiameter / 2)]
    }

    /// Le scanalature della palla di piombo (.22 LR).
    private var bulletMarks: [DarkMark] {
        spec.lubeGrooves.map { DarkMark(y0: $0 - 0.22, y1: $0 + 0.22, darkness: 0.45) }
    }

    private var caseMarks: [DarkMark] {
        let s = spec
        let flangeTop = s.overall - s.rimThickness
        // Piccola ombra subito sotto la bocca, dove la palla entra nel bossolo.
        var marks = [DarkMark(y0: s.mouthY, y1: s.mouthY + 0.6, darkness: 0.30)]
        if s.grooveWidth > 0 {
            marks.append(DarkMark(y0: flangeTop - s.grooveWidth, y1: flangeTop, darkness: 0.38))   // gola dell'estrattore
        } else {
            marks.append(DarkMark(y0: flangeTop - 0.3, y1: flangeTop, darkness: 0.25))             // sopra l'orlo
        }
        return marks
    }

    /// Luce da sinistra: bordo in ombra, riflesso stretto, zona neutra, ombra a destra. Cilindro metallico.
    private var lighting: Gradient {
        Gradient(stops: [
            .init(color: Color.black.opacity(0.35), location: 0.00),
            .init(color: Color.white.opacity(0.10), location: 0.14),
            .init(color: Color.white.opacity(0.42), location: 0.26),
            .init(color: Color.white.opacity(0.06), location: 0.40),
            .init(color: Color.clear, location: 0.60),
            .init(color: Color.black.opacity(0.22), location: 0.82),
            .init(color: Color.black.opacity(0.50), location: 1.00)
        ])
    }

    /// Un pezzo: tinta piena (con la sua opacità), poi luci e segni scuri ritagliati nella stessa sagoma.
    private func piece(_ path: Path, tint: Double, lights: [LightBand], marks: [DarkMark]) -> some View {
        ZStack {
            path.fill().opacity(tint)
            ZStack {
                ForEach(lights.indices, id: \.self) { i in
                    let band = lights[i]
                    Rectangle()
                        .fill(LinearGradient(gradient: lighting, startPoint: .leading, endPoint: .trailing))
                        .frame(width: band.radius * 2 * unit, height: (band.y1 - band.y0) * unit)
                        .position(x: width / 2, y: top + (band.y0 + band.y1) / 2 * unit)
                }
                ForEach(marks.indices, id: \.self) { i in
                    let mark = marks[i]
                    Rectangle()
                        .fill(Color.black.opacity(mark.darkness))
                        .frame(width: width, height: (mark.y1 - mark.y0) * unit)
                        .position(x: width / 2, y: top + (mark.y0 + mark.y1) / 2 * unit)
                }
            }
            .mask { path.fill(Color.black) }
        }
    }

    // MARK: Corpo

    var body: some View {
        ZStack {
            piece(bulletPath, tint: 1.0, lights: bulletLights, marks: bulletMarks)
            piece(casePath, tint: 0.62, lights: caseLights, marks: caseMarks)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Anteprima (per controllare il disegno a varie dimensioni)

#Preview("Cartucce") {
    HStack(alignment: .center, spacing: 36) {
        ForEach([22.0, 34.0, 46.0, 120.0, 260.0], id: \.self) { h in
            HStack(spacing: 10) {
                CartridgeIcon(style: .pistol, height: CGFloat(h))
                CartridgeIcon(style: .rimfire, height: CGFloat(h))
            }
        }
    }
    .foregroundStyle(Palette.muted)
    .padding(40)
    .background(Color(white: 0.06))
}
