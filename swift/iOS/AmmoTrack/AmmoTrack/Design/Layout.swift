//
//  Layout.swift
//
//  Piccoli strumenti di disposizione: controlli che vanno a capo quando manca lo spazio,
//  contenuto che scorre di lato se è più largo dello schermo, tastiera numerica.
//

import SwiftUI
import UIKit

// MARK: - Controlli che vanno a capo

/// Dispone le viste in riga e va a capo quando manca lo spazio (come il "wrap" dei CSS).
/// Serve alla barra dei filtri della pagina Dati, troppo larga per un iPhone.
struct FlowLayout: Layout {
    var spacing: CGFloat = 12
    var lineSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil))
            if x > 0 && x + size.width > maxWidth + 0.5 {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: usedWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX && x + size.width > bounds.maxX + 0.5 {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Contenuto che scorre di lato se lo spazio non basta

/// Se lo spazio è meno di `minWidth` il contenuto resta largo `minWidth` e scorre di lato,
/// invece di stringersi (la tabella del registro su iPhone). Con spazio a sufficienza non cambia nulla.
struct ScrollsBelowWidth: ViewModifier {
    let minWidth: CGFloat
    @State private var available: CGFloat = .infinity

    func body(content: Content) -> some View {
        ZStack {
            if available < minWidth {
                ScrollView(.horizontal) {
                    content
                        .frame(width: minWidth)
                }
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { available = $0 }
    }
}

extension View {
    /// Il contenuto scorre di lato se è più stretto di `minWidth`.
    func scrollsBelowWidth(_ minWidth: CGFloat) -> some View {
        modifier(ScrollsBelowWidth(minWidth: minWidth))
    }

    /// Il contenuto di un foglio scorre se non entra nello schermo.
    func scrollsOnTouch() -> some View {
        ScrollView { self }
    }

    /// Tastiera numerica sui campi dei numeri. `signed`: con anche il segno meno (per le rettifiche).
    func numericKeyboard(signed: Bool = false) -> some View {
        keyboardType(signed ? .numbersAndPunctuation : .numberPad)
    }
}

/// Chiude la tastiera a schermo.
func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
