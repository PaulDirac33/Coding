//
//  Palette.swift
//
//  Colori usati dai grafici e dall'interfaccia.
//  Oro = ricaricate, rosso = comprate: sono i colori delle colonne del foglio Numbers.
//

import SwiftUI

enum Palette {
    static let line = Color.white.opacity(0.10)
    static let grid = Color.white.opacity(0.08)
    static let muted = Color(red: 0.62, green: 0.65, blue: 0.72)
    static let data = Color(white: 0.92)                         // barre e istogramma (bianco / grigio chiaro)
    static let avg = Color.blue                                  // blu di sistema

    private static let reloadedRGB = (r: 0.91, g: 0.69, b: 0.27)   // oro
    private static let boughtRGB = (r: 0.88, g: 0.34, b: 0.30)     // rosso
    static let reloaded = Color(red: reloadedRGB.r, green: reloadedRGB.g, blue: reloadedRGB.b)
    static let bought = Color(red: boughtRGB.r, green: boughtRGB.g, blue: boughtRGB.b)

    /// Colore fra ricaricate (t = 0, oro) e comprate (t = 1, rosso), interpolato in RGB.
    /// Serve ai tasti: la tinta del vetro non si anima da sola, quindi la calcolo io a ogni fotogramma.
    static func provenanceTint(_ t: Double) -> Color {
        let k = min(max(t, 0), 1)
        return Color(red: reloadedRGB.r + (boughtRGB.r - reloadedRGB.r) * k,
                     green: reloadedRGB.g + (boughtRGB.g - reloadedRGB.g) * k,
                     blue: reloadedRGB.b + (boughtRGB.b - reloadedRGB.b) * k)
    }
    /// Verde militare, quello della mimetica ma più chiaro dello sfondo: pulsanti principali e icone attive.
    static let militaryGreen = Color(red: 0.34, green: 0.43, blue: 0.25)
    /// Lo stesso verde, più chiaro: tinta generale dell'app (barra delle pagine, interruttori, testi dei pulsanti).
    static let militaryGreenLight = Color(red: 0.58, green: 0.72, blue: 0.42)
    static let warning = Color.orange
    static let danger = Color(red: 0.95, green: 0.36, blue: 0.36)
}
