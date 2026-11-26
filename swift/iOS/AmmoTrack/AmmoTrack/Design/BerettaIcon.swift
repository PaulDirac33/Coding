//
//  BerettaIcon.swift
//
//  Beretta 92FS disegnata in vettoriale, calcata sulla foto di riferimento (versione bronzo).
//  Stessa filosofia di CartridgeIcon: tinta presa da foregroundStyle, tre livelli di opacità
//  (carrello e impugnatura a tinta piena, fusto e canna al 62%), luci e ombre ritagliate nella
//  stessa sagoma, particolari incisi sopra.
//
//  COME È FATTA
//  Tutte le sagome sono in coordinate della foto (1300 × 843 px) dentro `Beretta92`: per correggere
//  un profilo basta spostare i punti lì. La vista scala tutto in base a `height`.
//  Sotto i 56 pt di altezza spariscono i particolari troppo fini (zigrinatura, scritte, vite, logo)
//  perché a quelle dimensioni diventerebbero solo rumore.
//
//  API invariata: BerettaIcon(height:flipped:)
//

import SwiftUI

// MARK: - Scorciatoie per costruire i percorsi

fileprivate extension Path {
    mutating func mv(_ x: CGFloat, _ y: CGFloat) { move(to: CGPoint(x: x, y: y)) }
    mutating func ln(_ x: CGFloat, _ y: CGFloat) { addLine(to: CGPoint(x: x, y: y)) }
    mutating func cv(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat, _ y: CGFloat) {
        addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
    }
}

fileprivate func build(_ body: (inout Path) -> Void) -> Path {
    var p = Path()
    body(&p)
    return p
}

// MARK: - Geometria (px della foto di riferimento)

fileprivate enum Beretta92 {

    /// Porzione di foto che contiene l'arma.
    static let originX: CGFloat = 40
    static let originY: CGFloat = 6
    static let viewWidth: CGFloat = 1250
    static let viewHeight: CGFloat = 820

    static func disc(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }

    // MARK: Pezzi a opacità ridotta (bronzo)

    /// Cane: la parte che sporge dietro il carrello, con l'occhiello.
    static var hammer: Path {
        build { p in
            p.mv(162, 50)
            p.cv(148, 47, 134, 49, 128, 57)             // anello (sperone)
            p.cv(123, 63, 122, 70, 124, 77)
            p.cv(127, 87, 133, 96, 137, 106)            // collo, lungo il retro del carrello
            p.cv(141, 117, 147, 128, 151, 140)
            p.ln(162, 140)
            p.ln(205, 80)
            p.ln(226, 56)
            p.closeSubpath()
            p.addEllipse(in: CGRect(x: 137, y: 59, width: 22, height: 22))
        }
    }

    /// Zigrinatura sulla parte alta dell'anello del cane.
    static var hammerKnurl: Path {
        build { p in
            for deg in stride(from: 205.0, through: 265.0, by: 12.0) {
                let a = deg * Double.pi / 180
                let c = CGFloat(cos(a)), s = CGFloat(sin(a))
                p.mv(148 + 19 * c, 70 + 19 * s)
                p.ln(148 + 25 * c, 70 + 25 * s)
            }
        }
    }
    static var hammerHole: Path { disc(148, 70, 11) }

    /// Canna: la fascia scoperta sopra il carrello e la bocca che sporge davanti.
    static var barrel: Path {
        build { p in
            p.mv(584, 47)
            p.ln(1272, 47)
            p.cv(1281, 47, 1286, 55, 1286, 66)
            p.ln(1286, 112)
            p.cv(1286, 124, 1281, 130, 1272, 130)
            p.ln(584, 130)
            p.closeSubpath()
        }
    }

    /// Fusto: coda del carrello, dorsale, fronte dell'impugnatura, ponticello con la sua apertura (even-odd).
    static var frame: Path {
        build { p in
            p.mv(190, 120)
            p.ln(140, 125)
            p.cv(134, 150, 128, 178, 114, 201)          // dorso del "corno" posteriore
            p.cv(100, 216, 80, 224, 58, 231)
            p.cv(48, 235, 42, 248, 46, 256)             // punta
            p.cv(46, 262, 52, 267, 62, 267)
            p.cv(80, 268, 100, 267, 112, 272)           // sotto il corno
            p.cv(130, 280, 150, 298, 158, 312)
            p.cv(166, 325, 168, 338, 167, 350)          // dorsale
            p.cv(166, 375, 150, 405, 133, 430)
            p.ln(44, 670)
            p.cv(41, 690, 40, 715, 41, 740)             // spigolo in basso, arrotondato
            p.cv(42, 755, 45, 770, 52, 781)
            p.cv(54, 784, 58, 784, 64, 784)
            p.ln(370, 783)
            p.cv(375, 782, 375, 765, 371, 740)          // fronte dell'impugnatura
            p.cv(371, 700, 382, 620, 406, 540)
            p.cv(414, 515, 421, 495, 436, 474)
            p.cv(452, 463, 465, 457, 480, 457)          // fondo del ponticello
            p.cv(505, 457, 520, 462, 535, 466)
            p.cv(555, 470, 575, 472, 595, 472)
            p.ln(625, 471)
            p.cv(655, 468, 690, 458, 714, 449)
            p.cv(730, 443, 757, 436, 765, 425)
            p.ln(766, 365)
            p.cv(768, 345, 786, 312, 818, 290)          // raccordo concavo col fusto
            p.cv(835, 280, 850, 276, 872, 272)
            p.ln(1150, 257)
            p.ln(1150, 130)
            p.ln(190, 120)
            p.closeSubpath()
            // apertura del ponticello
            p.mv(504, 296)
            p.ln(692, 293)
            p.cv(722, 302, 740, 334, 739, 372)
            p.cv(739, 402, 731, 420, 716, 431)
            p.cv(698, 443, 672, 449, 645, 452)
            p.cv(605, 456, 565, 455, 534, 449)
            p.cv(496, 442, 470, 426, 463, 404)
            p.cv(456, 382, 452, 352, 466, 325)
            p.cv(476, 310, 490, 301, 504, 296)
            p.closeSubpath()
        }
    }

    /// Il ventre arrotondato del fusto sotto la canna: più scuro della faccia piana con la scritta.
    static var dustBelly: Path {
        build { p in
            p.mv(798, 272)
            p.cv(815, 254, 840, 238, 870, 230)
            p.cv(900, 223, 930, 223, 965, 222)
            p.ln(1150, 216)
            p.ln(1150, 257)
            p.ln(872, 272)
            p.cv(850, 276, 835, 280, 818, 290)
            p.closeSubpath()
        }
    }
    /// Lo spigolo fra la faccia piana e il ventre.
    static var dustEdge: Path {
        build { p in
            p.mv(798, 272)
            p.cv(815, 254, 840, 238, 870, 230)
            p.cv(900, 223, 930, 223, 965, 222)
            p.ln(1150, 216)
        }
    }

    // MARK: Pezzi a tinta piena (nero)

    static var slide: Path {
        build { p in
            p.mv(212, 46)
            p.ln(584, 40)
            p.ln(584, 96)           // finestra di espulsione: da qui la canna resta scoperta
            p.ln(1000, 82)
            p.ln(1105, 80)
            p.cv(1130, 80, 1146, 70, 1153, 60)
            p.ln(1153, 176)
            p.ln(172, 176)
            p.cv(150, 172, 146, 150, 160, 118)
            p.cv(172, 92, 192, 66, 212, 46)
            p.closeSubpath()
        }
    }

    /// Torretta anteriore del carrello e frontale nero del fusto sotto di essa.
    static var frontBlock: Path {
        build { p in
            p.mv(1150, 98)
            p.ln(1150, 50)
            p.cv(1150, 40, 1155, 34, 1165, 33)
            p.ln(1232, 33)
            p.cv(1236, 34, 1239, 40, 1239, 50)
            p.ln(1239, 246)
            p.ln(1150, 246)
            p.closeSubpath()
        }
    }

    /// Mirino: lama d'acciaio con la sommità arrotondata.
    static var frontSight: Path {
        build { p in
            p.mv(1170, 34)
            p.ln(1177, 14)
            p.cv(1195, 8, 1220, 14, 1233, 34)
            p.closeSubpath()
        }
    }

    /// Faccia anteriore del carrello, inclinata, che prende la luce.
    static var frontFacet: Path {
        build { p in
            p.mv(1160, 88)
            p.ln(1187, 72)
            p.ln(1240, 72)
            p.ln(1240, 157)
            p.ln(1207, 152)
            p.ln(1157, 167)
            p.closeSubpath()
        }
    }

    /// Fascia chiara sotto il carrello, sul frontale del fusto.
    static var frontBand: Path {
        build { p in
            p.mv(1152, 174); p.ln(1240, 174); p.ln(1240, 200); p.ln(1152, 200); p.closeSubpath()
        }
    }

    /// La fiancata lucida del carrello (più chiara del dorso nero).
    static var slidePlate: Path {
        build { p in
            p.mv(203, 103)
            p.ln(1135, 100)
            p.ln(1135, 168)
            p.ln(143, 168)
            p.closeSubpath()
        }
    }

    /// Asola allungata sul dorso del carrello.
    static var topSlot: Path { Path(roundedRect: CGRect(x: 382, y: 52, width: 203, height: 20), cornerRadius: 10) }
    static var topSlotInner: Path { Path(roundedRect: CGRect(x: 392, y: 58, width: 183, height: 8), cornerRadius: 4) }
    static var topScrew: Path { disc(336, 51, 7) }

    static var rearSight: Path {
        build { p in
            p.mv(255, 44)
            p.ln(265, 16)
            p.cv(268, 8, 286, 7, 291, 15)
            p.ln(304, 44)
            p.closeSubpath()
        }
    }

    static var grip: Path {
        build { p in
            p.mv(148, 204)
            p.ln(148, 192)
            p.cv(148, 187, 152, 184, 160, 184)
            p.ln(458, 184)
            p.cv(466, 184, 470, 190, 470, 200)
            p.cv(470, 230, 450, 250, 420, 262)
            p.cv(402, 350, 330, 620, 306, 758)          // fronte
            p.cv(305, 770, 298, 777, 284, 777)
            p.ln(112, 777)
            p.cv(90, 777, 74, 766, 71, 748)
            p.cv(100, 650, 185, 380, 214, 296)          // dorso
            p.cv(190, 282, 150, 262, 148, 204)
            p.closeSubpath()
        }
    }

    /// Zona zigrinata della guancetta (con la rientranza intorno al pulsante di sgancio).
    static var panel: Path {
        build { p in
            p.mv(262, 266)
            p.ln(417, 262)
            p.ln(417, 340)
            p.cv(412, 362, 388, 372, 374, 392)
            p.cv(358, 412, 352, 440, 354, 470)
            p.cv(350, 530, 325, 640, 296, 730)
            p.cv(293, 738, 288, 742, 280, 742)
            p.ln(102, 740)
            p.cv(92, 740, 88, 736, 90, 730)
            p.cv(125, 570, 180, 420, 205, 350)
            p.cv(220, 325, 240, 295, 262, 266)
            p.closeSubpath()
        }
    }

    /// Spalla scavata in alto sulla guancetta, dove poggia il pollice.
    static var scoop: Path {
        build { p in
            p.mv(160, 188)
            p.ln(300, 188)
            p.cv(300, 215, 262, 250, 210, 290)
            p.cv(190, 270, 160, 240, 150, 200)
            p.closeSubpath()
        }
    }
    static var scoopEdge: Path { build { p in p.mv(300, 190); p.cv(300, 215, 262, 250, 210, 290) } }

    /// Il bordo rialzato in basso, sopra la base del caricatore.
    static var gripFlange: Path { build { p in p.mv(98, 760); p.cv(160, 746, 240, 746, 298, 758) } }

    /// Zigrinatura a rombi: due famiglie di linee oblique ritagliate nella guancetta.
    static func checker(spacing s: CGFloat, rising: Bool) -> Path {
        build { p in
            if rising {                                   // x - y = c
                var c: CGFloat = -700
                while c < 200 { p.mv(c + 250, 250); p.ln(c + 770, 770); c += s }
            } else {                                      // x + y = c
                var c: CGFloat = 340
                while c < 1200 { p.mv(c - 250, 250); p.ln(c - 770, 770); c += s }
            }
        }
    }

    static var magBase: Path {
        build { p in
            p.mv(139, 783)
            p.ln(376, 783)
            p.ln(378, 816)
            p.cv(378, 822, 374, 824, 366, 824)
            p.ln(148, 816)
            p.cv(138, 815, 133, 811, 133, 803)
            p.ln(133, 788)
            p.cv(133, 785, 135, 783, 139, 783)
            p.closeSubpath()
        }
    }

    static var magHighlight: Path { build { p in p.mv(138, 790); p.ln(372, 791) } }
    static var magStep: Path { build { p in p.mv(345, 786); p.ln(345, 820) } }
    static var magBottom: Path { build { p in p.mv(150, 811); p.ln(366, 819) } }
    static var magLeftEdge: Path { build { p in p.mv(138, 788); p.ln(138, 806) } }

    /// Anello del cordino: un cappio a "U" scuro che pende dal fondo del fusto. La parte alta sta
    /// dietro la striscia di bronzo; il foro è una mezzaluna col lato piatto in alto (even-odd).
    static var lanyardRing: Path {
        build { p in
            p.mv(62, 775)
            p.ln(62, 790)
            p.cv(62, 803, 74, 813, 93, 813)
            p.cv(112, 813, 125, 802, 125, 788)
            p.ln(125, 775)
            p.closeSubpath()
            p.mv(77, 779)
            p.ln(106, 779)
            p.ln(106, 788)
            p.cv(106, 795, 99, 801, 92, 801)
            p.cv(84, 801, 77, 796, 77, 788)
            p.closeSubpath()
        }
    }

    /// Mezzaluna scura sotto la guancetta, sopra il fondo dell'impugnatura.
    static var gripFoot: Path {
        build { p in
            p.mv(76, 772)
            p.cv(120, 754, 230, 750, 298, 768)
            p.ln(298, 777)
            p.ln(76, 777)
            p.closeSubpath()
        }
    }

    // MARK: Comandi

    static var decocker: Path {
        build { p in
            p.mv(246, 100)
            p.cv(240, 78, 246, 62, 266, 58)
            p.ln(330, 72)
            p.cv(342, 76, 346, 92, 340, 108)
            p.cv(336, 120, 318, 124, 300, 122)
            p.ln(262, 122)
            p.cv(252, 120, 248, 110, 246, 100)
            p.closeSubpath()
        }
    }

    static var decockerPivot: Path { disc(243, 74, 20) }

    static var decockerSlot: Path {
        Path(roundedRect: CGRect(x: 290, y: 86, width: 48, height: 20), cornerRadius: 10)
    }

    static var safety: Path {
        build { p in
            p.mv(510, 198)
            p.ln(606, 192)
            p.cv(618, 192, 622, 205, 614, 217)
            p.ln(598, 236)
            p.ln(540, 238)
            p.ln(522, 248)
            p.ln(458, 252)
            p.ln(458, 236)
            p.ln(500, 224)
            p.cv(496, 212, 498, 202, 510, 198)
            p.closeSubpath()
        }
    }

    static var takedown: Path { disc(718, 203, 24) }
    static var slideStop: Path { Path(roundedRect: CGRect(x: 720, y: 236, width: 58, height: 30), cornerRadius: 15) }
    static var pin: Path { disc(574, 258, 7) }
    static var magRelease: Path { Path(roundedRect: CGRect(x: 384, y: 392, width: 64, height: 58), cornerRadius: 20) }

    static var trigger: Path {
        build { p in
            p.mv(532, 294)
            p.ln(592, 294)
            p.cv(591, 300, 588, 306, 586, 314)          // pad in alto
            p.ln(585, 344)                              // collo dritto
            p.cv(585, 352, 588, 358, 592, 366)          // curva dell'uncino
            p.cv(598, 380, 606, 390, 616, 399)
            p.cv(627, 408, 638, 414, 648, 419)
            p.ln(649, 425)
            p.cv(648, 430, 642, 432, 634, 430)          // punta
            p.cv(620, 427, 608, 420, 598, 410)
            p.cv(584, 396, 574, 382, 566, 368)
            p.cv(560, 358, 553, 354, 552, 344)
            p.ln(552, 318)
            p.cv(551, 314, 545, 308, 538, 301)
            p.cv(535, 298, 533, 296, 532, 294)
            p.closeSubpath()
        }
    }

    // MARK: Particolari incisi

    /// Zigrinatura posteriore del carrello.
    static var serrations: Path {
        build { p in
            var x: CGFloat = 340
            while x < 553 {
                p.mv(x + 20, 104)
                p.ln(x, 172)
                x += 9.5
            }
        }
    }

    static var slideTopEdge: Path { build { p in p.mv(216, 43); p.ln(584, 38) } }
    static var slideSideEdge: Path { build { p in p.mv(165, 101); p.ln(1150, 99) } }
    static var slideBottomEdge: Path { build { p in p.mv(172, 176); p.ln(1150, 176) } }
    static var portWall: Path { build { p in p.mv(584, 40); p.ln(584, 98) } }
    static var crown: Path { build { p in p.mv(1262, 52); p.ln(1262, 121) } }
    static var frontSplit: Path { build { p in p.mv(1150, 140); p.ln(1243, 140) } }

    /// Le scritte "MOD.98FS – CAL.9x21 IMI – PATENTED" e "WARNING: …" rese come tratteggio a parole.
    static var slideText1: Path { build { p in p.mv(700, 123); p.ln(993, 123) } }
    static var slideText2: Path { build { p in p.mv(611, 147); p.ln(1091, 147) } }
    static var frameText: Path { build { p in p.mv(880, 193); p.ln(1110, 193) } }
    static let textDash: [CGFloat] = [8, 3, 5, 3, 11, 4, 6, 3, 9, 7]

    static var indicatorDot: Path { disc(267, 150, 9) }

    // Logo: medaglione con il tridente e la scritta P. BERETTA, ricalcato sulla foto.
    static var logoRim: Path { disc(273, 453, 63.5) }
    static var logoGroove: Path { disc(273, 453, 58.5) }

    /// Una lancia del tridente: punta di freccia, asta e barbe in fondo.
    private static func prong(tip: CGPoint, dir: CGPoint, length: CGFloat) -> Path {
        func q(_ s: CGFloat, _ w: CGFloat) -> CGPoint {
            CGPoint(x: tip.x + dir.x * s + dir.y * w, y: tip.y + dir.y * s - dir.x * w)
        }
        var side: [(CGFloat, CGFloat)] = [(9, 5.0), (10.5, 3.2), (length - 13, 3.2)]
        var s = length - 13
        for _ in 0..<3 {
            side.append((s + 1.0, 6.4))
            side.append((s + 3.2, 3.2))
            s += 4.3
        }
        var path = Path()
        path.move(to: q(0, 0))
        for (a, w) in side { path.addLine(to: q(a, w)) }
        path.addLine(to: q(length + 1.5, 0))
        for (a, w) in side.reversed() { path.addLine(to: q(a, -w)) }
        path.closeSubpath()
        return path
    }

    static var prongs: Path {
        build { p in
            p.addPath(prong(tip: CGPoint(x: 260.0, y: 410.7), dir: CGPoint(x: -0.241, y: 0.970), length: 50.1))
            p.addPath(prong(tip: CGPoint(x: 282.9, y: 410.0), dir: CGPoint(x: -0.254, y: 0.968), length: 59.0))
            p.addPath(prong(tip: CGPoint(x: 300.7, y: 421.4), dir: CGPoint(x: -0.207, y: 0.979), length: 51.8))
        }
    }

    /// Arco di ellisse (angoli in gradi, y verso il basso).
    private static func arc(_ p: inout Path, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                            from: Double, to: Double) {
        let steps = 28
        for i in 0...steps {
            let a = (from + (to - from) * Double(i) / Double(steps)) * Double.pi / 180
            let pt = CGPoint(x: cx + rx * CGFloat(cos(a)), y: cy + ry * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
    }

    /// Gli anelli aperti attorno alle due lance laterali e l'anello in basso.
    static var tridentRings: Path {
        build { p in
            arc(&p, 252.6, 438.1, 13.1, 12.6, from: 265, to: 134)
            arc(&p, 252.6, 438.1, 13.1, 12.6, from: -38, to: 68)
            arc(&p, 294.3, 450.4, 13.9, 13.7, from: 255, to: 144)
            arc(&p, 294.3, 450.4, 13.9, 13.7, from: -55, to: 82)
            arc(&p, 267.9, 465.7, 14.6, 13.6, from: 300, to: 615)
        }
    }

    private static func glyph(_ c: Character) -> [[(CGFloat, CGFloat)]] {
        switch c {
        case "P": return [[(0, 1), (0, 0), (0.9, 0), (0.9, 0.5), (0, 0.5)]]
        case "B": return [[(0, 1), (0, 0), (0.85, 0), (0.85, 0.5), (0, 0.5)],
                          [(0.85, 0.5), (0.95, 0.5), (0.95, 1), (0, 1)]]
        case "E": return [[(0.9, 0), (0, 0), (0, 1), (0.9, 1)], [(0, 0.5), (0.7, 0.5)]]
        case "R": return [[(0, 1), (0, 0), (0.9, 0), (0.9, 0.5), (0, 0.5)], [(0.4, 0.5), (0.95, 1)]]
        case "T": return [[(0, 0), (1, 0)], [(0.5, 0), (0.5, 1)]]
        case "A": return [[(0, 1), (0.5, 0), (1, 1)], [(0.2, 0.65), (0.8, 0.65)]]
        default: return []
        }
    }

    /// "P. BERETTA" ad arco lungo il bordo basso del medaglione, con le cime delle lettere verso il centro.
    static var logoLetters: Path {
        build { p in
            let letters: [(Character, Double)] = [("P", -71), (".", -66), ("B", -52), ("E", -33), ("R", -19),
                                                  ("E", -4), ("T", 11), ("T", 25), ("A", 43)]
            let radius: CGFloat = 42, w: CGFloat = 7, h: CGFloat = 9
            for (ch, deg) in letters {
                let f = deg * Double.pi / 180
                let sn = CGFloat(sin(f)), cs = CGFloat(cos(f))
                let c = CGPoint(x: 273 + radius * sn, y: 453 + radius * cs)
                func at(_ gx: CGFloat, _ gy: CGFloat) -> CGPoint {
                    CGPoint(x: c.x + (gx - 0.5) * w * cs + (0.5 - gy) * h * (-sn),
                            y: c.y + (gx - 0.5) * w * (-sn) + (0.5 - gy) * h * (-cs))
                }
                if ch == "." {
                    let d = at(0.5, 0.92)
                    p.addEllipse(in: CGRect(x: d.x - 1.5, y: d.y - 1.5, width: 3, height: 3))
                    continue
                }
                for line in glyph(ch) {
                    for (i, g) in line.enumerated() {
                        if i == 0 { p.move(to: at(g.0, g.1)) } else { p.addLine(to: at(g.0, g.1)) }
                    }
                }
            }
        }
    }

    /// Marcature sul fusto: riquadro "CT", "N" e il piccolo simbolo.
    static var frameMarks: Path {
        build { p in
            p.addRect(CGRect(x: 655, y: 241, width: 26, height: 18))
            p.mv(633, 262); p.ln(633, 252); p.ln(641, 262); p.ln(641, 252)
            p.addRect(CGRect(x: 693, y: 241, width: 10, height: 8))
            p.addRect(CGRect(x: 693, y: 252, width: 10, height: 8))
            p.mv(661, 246); p.ln(661, 254); p.mv(668, 246); p.ln(675, 246); p.ln(675, 254)
        }
    }
    static var frameDots: Path {
        build { p in
            p.addEllipse(in: CGRect(x: 631, y: 243, width: 4, height: 4))
            p.addEllipse(in: CGRect(x: 638, y: 243, width: 4, height: 4))
        }
    }

    /// Zigrinatura sul davanti del ponticello.
    static var guardTicks: Path {
        build { p in
            var y: CGFloat = 358
            while y < 414 { p.mv(760, y); p.ln(770, y + 2); y += 5 }
        }
    }

    /// Spigolo chiaro del fusto, sotto il carrello.
    static var frameEdge: Path { build { p in p.mv(472, 185); p.ln(1150, 183) } }

    // Viti delle guancette
    static var screwTop: Path { disc(312, 333, 24) }
    static var screwBottom: Path { disc(219, 678, 24) }
    static var screwTopSlot: Path { build { p in p.mv(296, 343); p.ln(328, 323) } }
    static var screwBottomSlot: Path { build { p in p.mv(211, 661); p.ln(228, 696) } }
}

// MARK: - Luci

fileprivate enum Light {
    /// Acciaio: riflesso in alto, ombra in basso.
    static var metal: Gradient {
        Gradient(stops: [
            .init(color: Color.white.opacity(0.50), location: 0.00),
            .init(color: Color.white.opacity(0.12), location: 0.35),
            .init(color: Color.clear, location: 0.60),
            .init(color: Color.black.opacity(0.32), location: 1.00)
        ])
    }

    /// Fiancata del carrello: bordo alto lucido, poi opaco, in basso più scura.
    static var slide: Gradient {
        Gradient(stops: [
            .init(color: Color.white.opacity(0.36), location: 0.00),
            .init(color: Color.white.opacity(0.10), location: 0.16),
            .init(color: Color.clear, location: 0.50),
            .init(color: Color.black.opacity(0.30), location: 1.00)
        ])
    }

    /// Canna cilindrica, come il bossolo delle cartucce.
    static var cylinder: Gradient {
        Gradient(stops: [
            .init(color: Color.black.opacity(0.30), location: 0.00),
            .init(color: Color.white.opacity(0.10), location: 0.12),
            .init(color: Color.white.opacity(0.48), location: 0.26),
            .init(color: Color.white.opacity(0.06), location: 0.42),
            .init(color: Color.clear, location: 0.60),
            .init(color: Color.black.opacity(0.28), location: 0.82),
            .init(color: Color.black.opacity(0.55), location: 1.00)
        ])
    }

    /// Fiancata del carrello: schiarita uniforme con un po' di riflesso in alto.
    static var plate: Gradient {
        Gradient(stops: [
            .init(color: Color.white.opacity(0.30), location: 0.00),
            .init(color: Color.white.opacity(0.17), location: 0.50),
            .init(color: Color.white.opacity(0.06), location: 1.00)
        ])
    }

    /// Ventre del fusto: scuro in basso, quasi nullo allo spigolo.
    static var belly: Gradient {
        Gradient(stops: [
            .init(color: Color.black.opacity(0.06), location: 0.00),
            .init(color: Color.black.opacity(0.22), location: 0.55),
            .init(color: Color.black.opacity(0.44), location: 1.00)
        ])
    }

    /// Guancetta bombata: ombra sul bordo di sinistra, riflesso stretto, ombra a destra.
    static var panelSheen: Gradient {
        Gradient(stops: [
            .init(color: Color.black.opacity(0.26), location: 0.00),
            .init(color: Color.white.opacity(0.16), location: 0.22),
            .init(color: Color.white.opacity(0.05), location: 0.42),
            .init(color: Color.clear, location: 0.62),
            .init(color: Color.black.opacity(0.34), location: 1.00)
        ])
    }

    static var frame: Gradient {
        Gradient(stops: [
            .init(color: Color.white.opacity(0.24), location: 0.00),
            .init(color: Color.clear, location: 0.40),
            .init(color: Color.black.opacity(0.26), location: 1.00)
        ])
    }

    static var grip: Gradient {
        Gradient(stops: [
            .init(color: Color.white.opacity(0.14), location: 0.00),
            .init(color: Color.clear, location: 0.40),
            .init(color: Color.black.opacity(0.30), location: 1.00)
        ])
    }
}

// MARK: - Vista

/// Beretta 92FS illustrata. Prende il colore da foregroundStyle.
struct BerettaIcon: View {
    var height: CGFloat = 80
    /// true = specchiata orizzontalmente (canna a sinistra).
    var flipped: Bool = false
    /// Larghezza / altezza dell'icona (circa 1,52).
    static var aspectRatio: CGFloat { Beretta92.viewWidth / Beretta92.viewHeight }

    // MARK: Scala

    private var unit: CGFloat { height / Beretta92.viewHeight }
    private var width: CGFloat { Beretta92.viewWidth * unit }
    /// Sotto questa altezza i particolari fini diventano rumore e non si disegnano.
    private var detailed: Bool { height >= 56 }

    /// Da px della foto a punti nella vista.
    private func place(_ path: Path) -> Path {
        path.applying(CGAffineTransform(scaleX: unit, y: unit)
            .translatedBy(x: -Beretta92.originX, y: -Beretta92.originY))
    }

    // MARK: Mattoncini

    /// Un pezzo: tinta piena (con la sua opacità), poi luce ritagliata nella stessa sagoma.
    private func piece(_ source: Path, tint: Double = 1, evenOdd: Bool = false,
                       light: Gradient, from: UnitPoint = .top, to: UnitPoint = .bottom) -> some View {
        let path = place(source)
        let box = path.boundingRect
        let rule = FillStyle(eoFill: evenOdd)
        return ZStack {
            path.fill(style: rule).opacity(tint)
            Rectangle()
                .fill(LinearGradient(gradient: light, startPoint: from, endPoint: to))
                .frame(width: box.width, height: box.height)
                .position(x: box.midX, y: box.midY)
                .mask { path.fill(Color.black, style: rule) }
        }
    }

    private func ink(_ source: Path, _ color: Color, evenOdd: Bool = false) -> some View {
        place(source).fill(color, style: FillStyle(eoFill: evenOdd))
    }

    /// Linea incisa. `px` è lo spessore in pixel della foto.
    private func trace(_ source: Path, _ color: Color, _ px: CGFloat,
                       dash: [CGFloat] = [], cap: CGLineCap = .round) -> some View {
        place(source).stroke(color, style: StrokeStyle(lineWidth: max(0.3, px * unit),
                                                       lineCap: cap,
                                                       dash: dash.map { $0 * unit }))
    }

    /// Dà volume ai bordi, come una superficie tondeggiante: scurisce il perimetro e
    /// accende il lato verso la luce (in alto a sinistra), tutto sfumato e ritagliato nella sagoma.
    private func rounded(_ source: Path, depth: CGFloat, shade: Double = 0.34, shine: Double = 0.22,
                         evenOdd: Bool = false) -> some View {
        let path = place(source)
        let rule = FillStyle(eoFill: evenOdd)
        let d = depth * unit
        let lit = path.applying(CGAffineTransform(translationX: depth * 0.45 * unit, y: depth * 0.45 * unit))
        return ZStack {
            path.stroke(Color.black.opacity(shade), style: StrokeStyle(lineWidth: 2 * d, lineJoin: .round))
                .blur(radius: d * 0.55)
            lit.stroke(Color.white.opacity(shine), style: StrokeStyle(lineWidth: d, lineJoin: .round))
                .blur(radius: d * 0.40)
        }
        .mask { path.fill(Color.black, style: rule) }
    }

    /// Un comando d'acciaio (leva, perno, pulsante): luce, bordo scuro.
    private func lever(_ source: Path) -> some View {
        ZStack {
            piece(source, light: Light.metal)
            ink(source, Color.white.opacity(0.16))
            trace(source, Color.black.opacity(0.55), 2.4)
        }
    }

    private func screw(_ disc: Path, slot: Path) -> some View {
        ZStack {
            piece(disc, light: Light.metal)
            ink(disc, Color.white.opacity(0.14))
            trace(disc, Color.black.opacity(0.60), 2.6)
            trace(slot, Color.black.opacity(0.75), 5)
        }
    }

    // MARK: Gruppi

    /// Cane e canna, dietro al carrello.
    private var barrelGroup: some View {
        ZStack {
            piece(Beretta92.hammer, evenOdd: true, light: Light.metal)
            ink(Beretta92.hammer, Color.white.opacity(0.16), evenOdd: true)
            rounded(Beretta92.hammer, depth: 7, shade: 0.34, shine: 0.22, evenOdd: true)
            trace(Beretta92.hammer, Color.black.opacity(0.60), 2.4)
            trace(Beretta92.hammerHole, Color.black.opacity(0.45), 2)
            if detailed { trace(Beretta92.hammerKnurl, Color.black.opacity(0.50), 2) }
            piece(Beretta92.barrel, tint: 0.62, light: Light.cylinder)
            trace(Beretta92.crown, Color.black.opacity(0.45), 3)
        }
    }

    private var frameGroup: some View {
        ZStack {
            piece(Beretta92.frame, tint: 0.62, evenOdd: true, light: Light.frame,
                  from: .topLeading, to: .bottomTrailing)
            rounded(Beretta92.frame, depth: 16, shade: 0.42, shine: 0.26, evenOdd: true)
            // Ventre tondo del fusto sotto la canna: più scuro verso il basso, con lo spigolo che prende la luce.
            piece(Beretta92.dustBelly, tint: 0, light: Light.belly)
            trace(Beretta92.dustEdge, Color.white.opacity(0.26), 3.2)
            place(Beretta92.dustEdge)
                .applying(CGAffineTransform(translationX: 0, y: 4 * unit))
                .stroke(Color.black.opacity(0.22), style: StrokeStyle(lineWidth: max(0.3, 3 * unit)))
            trace(Beretta92.frame, Color.black.opacity(0.40), 2.4)
            trace(Beretta92.frameEdge, Color.white.opacity(0.24), 3)
            if detailed {
                trace(Beretta92.frameText, Color.black.opacity(0.42), 9,
                      dash: Beretta92.textDash, cap: .butt)
                trace(Beretta92.frameMarks, Color.black.opacity(0.42), 2)
                ink(Beretta92.frameDots, Color.black.opacity(0.42))
                trace(Beretta92.guardTicks, Color.black.opacity(0.55), 2)
            }
        }
    }
    /// La guancetta con un buco dove sta il medaglione (even-odd).
    private var checkerClip: Path {
        var cut = place(Beretta92.panel)
        cut.addPath(place(Beretta92.logoRim))
        return cut
    }

    private var checkering: some View {
        let spacing = max(15, 2.6 / unit)
        return ZStack {
            trace(Beretta92.checker(spacing: spacing, rising: true), Color.black.opacity(0.55), 1.7, cap: .butt)
            trace(Beretta92.checker(spacing: spacing, rising: false), Color.white.opacity(0.20), 1.7, cap: .butt)
        }
        .mask { checkerClip.fill(Color.black, style: FillStyle(eoFill: true)) }
    }

    private var logo: some View {
        ZStack {
            // Bordo rialzato, gola scura e fondo piatto (più chiaro) del medaglione.
            ink(Beretta92.logoRim, Color.white.opacity(0.10))
            trace(Beretta92.logoRim, Color.white.opacity(0.30), 2.6)
            ink(Beretta92.logoGroove, Color.white.opacity(0.13))
            trace(Beretta92.logoGroove, Color.black.opacity(0.55), 2.4)
            // Il tridente in rilievo: anelli sotto, lance sopra.
            trace(Beretta92.tridentRings, Color.black.opacity(0.62), 3.4)
            trace(Beretta92.tridentRings, Color.white.opacity(0.26), 1.2)
            ink(Beretta92.prongs, Color.white.opacity(0.28))
            trace(Beretta92.prongs, Color.black.opacity(0.62), 1.8)
            // Scritta.
            trace(Beretta92.logoLetters, Color.black.opacity(0.58), 3)
        }
    }

    private var gripGroup: some View {
        ZStack {
            piece(Beretta92.grip, light: Light.grip, from: .leading, to: .trailing)
            rounded(Beretta92.grip, depth: 15, shade: 0.34, shine: 0.20)
            piece(Beretta92.panel, tint: 0, light: Light.panelSheen, from: .leading, to: .trailing)
            trace(Beretta92.grip, Color.white.opacity(0.18), 2.2)
            ink(Beretta92.scoop, Color.white.opacity(0.07))
            trace(Beretta92.scoopEdge, Color.white.opacity(0.22), 3)
            ink(Beretta92.gripFoot, Color.black.opacity(0.30))
            trace(Beretta92.gripFlange, Color.white.opacity(0.22), 3)
            if detailed {
                checkering
                trace(Beretta92.panel, Color.white.opacity(0.22), 2.6)
                screw(Beretta92.screwTop, slot: Beretta92.screwTopSlot)
                screw(Beretta92.screwBottom, slot: Beretta92.screwBottomSlot)
                logo
            } else {
                ink(Beretta92.panel, Color.white.opacity(0.10))
            }
        }
    }

    /// Anello del cordino: sta dietro al fondo del fusto.
    private var lanyardGroup: some View {
        ZStack {
            piece(Beretta92.lanyardRing, evenOdd: true, light: Light.grip,
                  from: .topLeading, to: .bottomTrailing)
            rounded(Beretta92.lanyardRing, depth: 7, shade: 0.36, shine: 0.20, evenOdd: true)
            trace(Beretta92.lanyardRing, Color.black.opacity(0.45), 2)
        }
    }

    private var magazineGroup: some View {
        ZStack {
            piece(Beretta92.magBase, light: Light.metal)
            rounded(Beretta92.magBase, depth: 9, shade: 0.30, shine: 0.20)
            trace(Beretta92.magBase, Color.black.opacity(0.50), 2.2)
            trace(Beretta92.magHighlight, Color.white.opacity(0.30), 3)
            trace(Beretta92.magLeftEdge, Color.white.opacity(0.22), 2.4)
            trace(Beretta92.magStep, Color.black.opacity(0.45), 2.4)
            trace(Beretta92.magBottom, Color.white.opacity(0.16), 2.6)
        }
    }

    private var slideDetails: some View {
        ZStack {
            // Fiancata lucida: più chiara del dorso nero.
            piece(Beretta92.slidePlate, tint: 0, light: Light.plate)
            // Faccia anteriore e fascia chiara sul frontale.
            ink(Beretta92.frontFacet, Color.white.opacity(0.13))
            trace(Beretta92.frontFacet, Color.white.opacity(0.22), 2.4)
            ink(Beretta92.frontBand, Color.white.opacity(0.12))
            // Bordi: spigolo alto lucido, passaggio fra dorso e fiancata, taglio sul fusto.
            trace(Beretta92.slideTopEdge, Color.white.opacity(0.50), 3)
            trace(Beretta92.slideSideEdge, Color.white.opacity(0.32), 2.6)
            trace(Beretta92.slideBottomEdge, Color.black.opacity(0.55), 2.6)
            trace(Beretta92.portWall, Color.black.opacity(0.50), 3)
            trace(Beretta92.frontSplit, Color.white.opacity(0.18), 2.4)
            if detailed { slideFineDetails }
        }
    }

    /// Particolari fini del carrello (solo a dimensioni grandi).
    private var slideFineDetails: some View {
        ZStack {
            ZStack {
                // Asola sul dorso del carrello e vitina.
                ink(Beretta92.topSlot, Color.white.opacity(0.10))
                ink(Beretta92.topSlotInner, Color.black.opacity(0.40))
                trace(Beretta92.topSlot, Color.white.opacity(0.28), 2.2)
                ink(Beretta92.topScrew, Color.white.opacity(0.28))
                trace(Beretta92.topScrew, Color.black.opacity(0.60), 2.2)
                // Indicatore di colpo in canna.
                ink(Beretta92.indicatorDot, Color.white.opacity(0.62))
                trace(Beretta92.indicatorDot, Color.black.opacity(0.70), 2.4)
            }
            ZStack {
                // Zigrinatura posteriore: un tratto scuro e uno chiaro accanto, come un rilievo.
                trace(Beretta92.serrations, Color.black.opacity(0.58), 3.4, cap: .butt)
                place(Beretta92.serrations)
                    .applying(CGAffineTransform(translationX: 3.4 * unit, y: 0))
                    .stroke(Color.white.opacity(0.20), style: StrokeStyle(lineWidth: max(0.3, 1.8 * unit)))
                // Scritte incise.
                trace(Beretta92.slideText1, Color.white.opacity(0.38), 9, dash: Beretta92.textDash, cap: .butt)
                trace(Beretta92.slideText2, Color.white.opacity(0.38), 9, dash: Beretta92.textDash, cap: .butt)
            }
        }
    }

    private var slideGroup: some View {
        ZStack {
            piece(Beretta92.rearSight, light: Light.slide)
            piece(Beretta92.slide, light: Light.slide)
            piece(Beretta92.frontBlock, light: Light.slide)
            rounded(Beretta92.slide, depth: 9, shade: 0.30, shine: 0.20)
            rounded(Beretta92.frontBlock, depth: 12, shade: 0.34, shine: 0.20)
            piece(Beretta92.frontSight, light: Light.metal)
            ink(Beretta92.frontSight, Color.white.opacity(0.18))
            slideDetails
        }
    }

    private var controlsGroup: some View {
        ZStack {
            // Leva sicura/abbatticane sul carrello, con la sua asola scura.
            lever(Beretta92.decockerPivot)
            lever(Beretta92.decocker)
            ink(Beretta92.decockerSlot, Color.black.opacity(0.70))
            // Sul fusto.
            lever(Beretta92.safety)
            lever(Beretta92.takedown)
            lever(Beretta92.slideStop)
            lever(Beretta92.pin)
            lever(Beretta92.magRelease)
            // Grilletto, dentro l'apertura del ponticello.
            piece(Beretta92.trigger, light: Light.metal, from: .leading, to: .trailing)
            trace(Beretta92.trigger, Color.black.opacity(0.50), 2)
        }
    }

    // MARK: Corpo

    var body: some View {
        ZStack {
            barrelGroup
            lanyardGroup
            frameGroup
            gripGroup
            magazineGroup
            slideGroup
            controlsGroup
        }
        .frame(width: width, height: height)
        .scaleEffect(x: flipped ? -1 : 1, y: 1)
        .accessibilityLabel("Icona realistica di una pistola semiautomatica")
    }
}

// MARK: - Anteprima (per controllare il disegno a varie dimensioni)

#Preview("Beretta 92") {
    VStack(spacing: 28) {
        BerettaIcon(height: 320)
        HStack(alignment: .center, spacing: 28) {
            BerettaIcon(height: 150)
            BerettaIcon(height: 80, flipped: true)
            BerettaIcon(height: 46)
            BerettaIcon(height: 24)
        }
    }
    .foregroundStyle(Color(white: 0.72))
    .padding(40)
    .background(Color(white: 0.06))
}
