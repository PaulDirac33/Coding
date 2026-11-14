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

    static let reloaded = Color(red: 0.91, green: 0.69, blue: 0.27)   // oro
    static let bought = Color(red: 0.88, green: 0.34, blue: 0.30)     // rosso
    static let warning = Color.orange
    static let danger = Color(red: 0.95, green: 0.36, blue: 0.36)
}
