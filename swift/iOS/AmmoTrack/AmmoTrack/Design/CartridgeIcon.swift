//
//  CartridgeIcon.swift
//
//  Le cartucce dell'app (tasto dell'arma, miniature, schede senza foto), disegnate in scala reale:
//  palla a tinta piena, bossolo al 62%, colore preso da foregroundStyle.
//
//  QUOTE (mm)
//    9x21 IMI, massimi C.I.P. (TAB. IV): totale 29,75 · bossolo 21,15 · palla 9,03 · collo 9,63 · base 9,93 · orlo 9,96 × 1,27
//               gola dell'estrattore: la rampa finisce a 2,98 dal fondello (E), fondo Ø 8,79 (E1),
//               parte piana almeno 0,90 (e), rampa a 35° rispetto all'asse (δ), smusso del fondello 0,30 a 45° (f, β)
//    .22 LR     misure del disegno originale, lasciate invariate: totale 25,4 · bossolo 15,6 · palla 5,7 · orlo 7,1 × 1,1
//               (a pochi centesimi di millimetro dai massimi C.I.P., TAB. V: bossolo 15,57 · palla 5,72 · orlo 7,06 × 1,09)
//
//  La gola del 9x21 è ricavata da E, E1 e δ: profondità (9,93 − 8,79) / 2 = 0,57, rampa lunga 0,57 / tan 35° = 0,81,
//  quindi la parte piana viene 2,98 − 1,27 − 0,81 = 0,90, cioè proprio la quota "e" della tabella.
//
//  NON vengono da C.I.P. (scelte di disegno, si regolano nelle due costanti `CartridgeSpec` qui sotto):
//    la forma della palla (ogiva e punta: quella del disegno originale), le scanalature della palla del .22,
//    gli smussi del fondello del .22, il piccolo smusso sullo spigolo dell'orlo e la riga fra palla e bossolo.
//  Attenzione: nella tabella del .22 la quota G = 1,94 (e r = 0,25) è della CAMERA, non della palla,
//  quindi non dice dove finisce il tratto cilindrico.
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
    let overall: CGFloat              // L6: lunghezza totale della cartuccia
    let caseLength: CGFloat           // L3: lunghezza del bossolo
    let rimDiameter: CGFloat          // R1: diametro dell'orlo / fondello
    let rimThickness: CGFloat         // R: spessore dell'orlo / fondello
    let baseDiameter: CGFloat         // P1: diametro del bossolo vicino al fondello
    let neckDiameter: CGFloat         // diametro del bossolo alla bocca
    let bulletDiameter: CGFloat       // G1: diametro della palla

    // Gola dell'estrattore (C.I.P. E, E1, δ). extractorEnd = 0: la gola non c'è (percussione anulare).
    let extractorEnd: CGFloat         // E: dal piano del fondello a dove la rampa torna al diametro del corpo
    let grooveFloorDiameter: CGFloat  // E1: diametro sul fondo della gola
    let grooveRampAngle: CGFloat      // δ: angolo della rampa rispetto all'asse, in gradi
    let baseChamfer: CGFloat          // f: smusso del fondello (a 45°)

    // Forma della palla (scelte di disegno: C.I.P. non la prescrive)
    let noseLength: CGFloat           // dalla punta fin dove l'ogiva diventa cilindro
    let tipRadius: CGFloat            // arrotondamento della punta
    let lubeGrooves: [CGFloat]        // quota (y) delle scanalature della palla

    /// Dove comincia il bossolo (la bocca).
    var mouthY: CGFloat { overall - caseLength }
    /// Dove comincia la faccia superiore dell'orlo.
    var flangeTopY: CGFloat { overall - rimThickness }

    // Gola dell'estrattore
    var hasExtractorGroove: Bool { extractorEnd > 0 }
    /// Fine della rampa dal lato del corpo (quota E dal fondello).
    var rampEndY: CGFloat { overall - extractorEnd }
    /// Profondità della gola per lato, rispetto al corpo.
    var grooveDepth: CGFloat { (baseDiameter - grooveFloorDiameter) / 2 }
    /// Lunghezza assiale della rampa: profondità / tan δ.
    var rampLength: CGFloat {
        guard grooveRampAngle > 0 else { return 0 }
        return grooveDepth / tan(grooveRampAngle * .pi / 180)
    }
    /// Dove la rampa incontra la parte piana sul fondo della gola.
    var rampStartY: CGFloat { rampEndY + rampLength }

    static let nineByTwentyOne = CartridgeSpec(
        overall: 29.75, caseLength: 21.15, rimDiameter: 9.96, rimThickness: 1.27,
        baseDiameter: 9.93, neckDiameter: 9.63, bulletDiameter: 9.03,
        extractorEnd: 2.98, grooveFloorDiameter: 8.79, grooveRampAngle: 35, baseChamfer: 0.30,
        noseLength: 6.0, tipRadius: 1.8, lubeGrooves: [])

    static let twentyTwoLR = CartridgeSpec(
        overall: 25.4, caseLength: 15.6, rimDiameter: 7.1, rimThickness: 1.1,
        baseDiameter: 5.74, neckDiameter: 5.74, bulletDiameter: 5.70,
        extractorEnd: 0, grooveFloorDiameter: 0, grooveRampAngle: 0, baseChamfer: 0.15,
        noseLength: 4.9, tipRadius: 1.25, lubeGrooves: [6.1, 7.6])
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
/// sul diametro giusto (l'orlo è più largo del fondo della gola).
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
    /// true = cartuccia coricata: ruotata di 90° in senso antiorario (punta a sinistra).
    /// L'ingombro diventa `height` in larghezza e lo spessore della cartuccia in altezza.
    var horizontal = false
    /// true = il fondello poggia sul bordo basso dell'ingombro; false = la cartuccia è centrata in verticale
    /// (il .22, più corto del 9x21, ha allora la base più in alto).
    var restsOnBottom = false
    /// Spazio (mm) fra la bocca del bossolo e la palla: è la sottile riga che le separa.
    /// Si toglie dal tratto cilindrico della palla. Mettilo a 0 per la palla incastrata nel bossolo senza stacco.
    private static let mouthGap: CGFloat = 0.35
    /// Piccolo smusso (mm) sullo spigolo superiore dell'orlo. Non è una quota C.I.P.: 0 = spigolo vivo.
    private static let rimEdgeBreak: CGFloat = 0.08

    // MARK: Scala

    private var spec: CartridgeSpec { style.spec }

    /// Punti per millimetro: il 9x21 occupa tutta l'altezza.
    private var unit: CGFloat { height / CartridgeSpec.nineByTwentyOne.overall }
    private var width: CGFloat { spec.rimDiameter * unit }
    /// Margine in alto: il .22, più corto, resta centrato in verticale.
    /// Margine in alto: il .22, più corto, resta centrato in verticale (o poggiato in basso con `restsOnBottom`).
    private var top: CGFloat {
        let free = height - spec.overall * unit
        return restsOnBottom ? free : free / 2
    }

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

    /// Il bossolo, dalla bocca al fondello. Con la gola dell'estrattore (9x21) il profilo è:
    /// corpo conico → rampa a δ → fondo piano della gola → faccia dell'orlo → orlo → smusso del fondello.
    private var casePath: Path {
        let s = spec
        let base = s.baseDiameter / 2
        let neck = s.neckDiameter / 2
        let rim = s.rimDiameter / 2
        let bottom = s.overall
        let flangeTop = s.flangeTopY
        let chamfer = s.baseChamfer
        let edge = Self.rimEdgeBreak

        var half: [CGPoint] = [CGPoint(x: neck, y: s.mouthY)]
        if s.hasExtractorGroove {
            let floor = s.grooveFloorDiameter / 2
            half.append(CGPoint(x: base, y: s.rampEndY))          // fine del corpo conico (E)
            half.append(CGPoint(x: floor, y: s.rampStartY))       // rampa fino al fondo della gola (E1, δ)
            half.append(CGPoint(x: floor, y: flangeTop))          // parte piana (e), poi la faccia dell'orlo
        } else {
            half.append(CGPoint(x: base, y: flangeTop))
        }
        half.append(CGPoint(x: rim - edge, y: flangeTop))
        half.append(CGPoint(x: rim, y: flangeTop + edge))
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
        if s.hasExtractorGroove {
            return [
                LightBand(y0: s.mouthY, y1: s.rampEndY, radius: s.baseDiameter / 2),                              // corpo
                LightBand(y0: s.rampEndY, y1: s.rampStartY,
                          radius: (s.baseDiameter + s.grooveFloorDiameter) / 4),                                  // rampa: raggio medio
                LightBand(y0: s.rampStartY, y1: s.flangeTopY, radius: s.grooveFloorDiameter / 2),                 // fondo della gola
                LightBand(y0: s.flangeTopY, y1: s.overall, radius: s.rimDiameter / 2)                             // orlo
            ]
        }
        return [LightBand(y0: s.mouthY, y1: s.flangeTopY, radius: s.baseDiameter / 2),
                LightBand(y0: s.flangeTopY, y1: s.overall, radius: s.rimDiameter / 2)]
    }

    /// Le scanalature della palla di piombo (.22 LR).
    private var bulletMarks: [DarkMark] {
        spec.lubeGrooves.map { DarkMark(y0: $0 - 0.22, y1: $0 + 0.22, darkness: 0.45) }
    }

    private var caseMarks: [DarkMark] {
        let s = spec
        // Piccola ombra subito sotto la bocca, dove la palla entra nel bossolo.
        var marks = [DarkMark(y0: s.mouthY, y1: s.mouthY + 0.6, darkness: 0.30)]
        if s.hasExtractorGroove {
            marks.append(DarkMark(y0: s.rampEndY, y1: s.rampStartY, darkness: 0.16))      // rampa della gola
            marks.append(DarkMark(y0: s.rampStartY, y1: s.flangeTopY, darkness: 0.38))    // fondo della gola
        } else {
            marks.append(DarkMark(y0: s.flangeTopY - 0.3, y1: s.flangeTopY, darkness: 0.25))   // sopra l'orlo
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
                        .fill(LinearGradient(gradient: lighting,
                                             startPoint: horizontal ? .trailing : .leading,
                                             endPoint: horizontal ? .leading : .trailing))
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
        let drawing = ZStack {
            piece(bulletPath, tint: 1.0, lights: bulletLights, marks: bulletMarks)
            piece(casePath, tint: 0.62, lights: caseLights, marks: caseMarks)
        }
        .frame(width: width, height: height)

        if horizontal {
            // rotationEffect non cambia l'ingombro: lo scambio io, altrimenti il layout resterebbe verticale.
            drawing
                .rotationEffect(.degrees(-90))      // negativo = antiorario
                .frame(width: height, height: width)
        } else {
            drawing
        }
    }
}

// MARK: - Anteprime (per controllare il disegno a varie dimensioni)

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

/// Il fondello a grande scala: serve a controllare la gola dell'estrattore del 9x21.
#Preview("Fondello 9x21") {
    CartridgeIcon(style: .pistol, height: 900)
        .frame(height: 260, alignment: .bottom)
        .clipped()
        .foregroundStyle(Palette.muted)
        .padding(40)
        .background(Color(white: 0.06))
}
