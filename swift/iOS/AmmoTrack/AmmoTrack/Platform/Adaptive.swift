//
//  Adaptive.swift
//
//  Piccoli strumenti per adattare la disposizione allo schermo.
//  Su Mac e su iPad in orizzontale l'interfaccia resta IDENTICA a quella originale;
//  su iPhone e su iPad in verticale cambia solo la disposizione (i controlli vanno a capo,
//  la tabella scorre di lato, i fogli prendono la larghezza dello schermo), mai lo stile.
//

import SwiftUI

enum Adaptive {
    /// Sotto questa larghezza (in punti) la pagina è quella di un iPhone in verticale.
    static let phoneWidth: CGFloat = 600
}

// MARK: - Controlli che vanno a capo

/// Dispone le viste in riga e va a capo quando manca lo spazio (come il "wrap" dei CSS).
/// Serve alle barre dei filtri della pagina Dati, troppo larghe per un iPhone.
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

// MARK: - Modificatori di vista

extension View {

    /// Fogli (Modifica, Importa...): larghezza fissa su Mac, tutta quella del foglio su iPhone e iPad.
    @ViewBuilder
    func sheetWidth(_ width: CGFloat) -> some View {
        #if os(macOS)
        frame(width: width)
        #else
        frame(maxWidth: .infinity)
        #endif
    }

    /// Larghezza fissa su Mac; su iPhone e iPad è solo un massimo (lo schermo può essere più stretto).
    @ViewBuilder
    func macFixedWidth(_ width: CGFloat) -> some View {
        #if os(macOS)
        frame(width: width)
        #else
        frame(maxWidth: width)
        #endif
    }

    /// Su iPhone e iPad il contenuto scorre di lato se è più stretto di `minWidth`. Su Mac non fa nulla.
    @ViewBuilder
    func scrollsBelowWidth(_ minWidth: CGFloat) -> some View {
        #if os(iOS)
        modifier(ScrollsBelowWidth(minWidth: minWidth))
        #else
        self
        #endif
    }

    /// Su iPhone e iPad il contenuto di un foglio scorre se non entra. Su Mac il foglio si adatta al contenuto.
    @ViewBuilder
    func scrollsOnTouch() -> some View {
        #if os(iOS)
        ScrollView { self }
        #else
        self
        #endif
    }
}
