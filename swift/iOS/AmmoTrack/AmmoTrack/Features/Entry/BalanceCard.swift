//
//  BalanceCard.swift
//
//  I saldi attuali per calibro (ricaricate, comprate, totale) rispetto alle cartucce denunciate,
//  più il totale generale: sono i numeri che prima guardavi nel foglio Numbers.
//  Ricaricate e comprate si riconoscono dai simboli del selettore: ingranaggio oro, carrello rosso.
//  Fermando il mouse sul simbolo, dopo 1 secondo compare il nome (suggerimento sfumato, senza bordo).
//

import SwiftUI

struct BalanceCard: View {
    @EnvironmentObject var store: DataStore

    // Misure della scheda. La barra del limite prende lo spazio che resta:
    // larghezza scheda − 28 (margini) − nome − 2 saldi − "usate/limite" − 4 spazi.
    // Con i valori qui sotto la barra è lunga circa 98 pt.
    private let cardWidth: CGFloat = 390      // come il selettore delle pagine in alto: 3 voci da 128 pt + 2 margini da 3 pt
    private let nameWidth: CGFloat = 44       // "9×21", "22 LR", "Totale"
    private let figureWidth: CGFloat = 54     // simbolo + numero (fino a 1.000)
    private let usageWidth: CGFloat = 80      // "1.000 / 1.000"
    private let rowSpacing: CGFloat = 8
    private let hintDelay: Double = 1.0       // secondi di attesa prima del suggerimento sul simbolo

    var body: some View {
        VStack(spacing: 10) {
            ForEach(store.config.calibers) { c in
                caliberRow(c)
            }
            if store.config.calibers.count > 1 {
                totalRow
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: cardWidth)
        .liquidGlass(cornerRadius: 22)
    }

    /// Simbolo della provenienza (con il suggerimento) e numero.
    private func figure(_ p: Provenance, _ value: Int) -> some View {
        HStack(spacing: 5) {
            SymbolHint(provenance: p, delay: hintDelay)
            Text(numText(value))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(value < 0 ? Palette.danger : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: figureWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(p.label)
        .accessibilityValue(numText(value))
    }

    private func usage(_ total: Int, _ limit: Int?) -> some View {
        let over = limit.map { total > $0 } ?? false
        let text = limit.map { "\(numText(total)) / \(numText($0))" } ?? numText(total)
        return Text(text)
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(over ? Palette.danger : Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(width: usageWidth, alignment: .trailing)
    }

    private func name(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: nameWidth, alignment: .leading)
    }

    private func caliberRow(_ c: Caliber) -> some View {
        let b = store.ledger.balance(for: c.id)
        return HStack(spacing: rowSpacing) {
            name(c.name)
            if c.allowsReload {
                figure(.reloaded, b.reloaded)
            } else {
                Color.clear.frame(width: figureWidth, height: 1)     // il .22 non si ricarica: colonna vuota
            }
            figure(.bought, b.bought)
            LimitBar(value: b.total, limit: c.limit)
            usage(b.total, c.limit)
        }
    }

    private var totalRow: some View {
        let b = store.ledger.balance(for: nil)
        let limit = store.config.totalLimit
        return HStack(spacing: rowSpacing) {
            name("Totale")
            figure(.reloaded, b.reloaded)
            figure(.bought, b.bought)
            LimitBar(value: b.total, limit: limit)
            usage(b.total, limit)
        }
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }
}

// MARK: - Simbolo con suggerimento

/// Il simbolo (ingranaggio o carrello). Se il mouse resta sopra per `delay` secondi compare il nome
/// sopra di esso, con una dissolvenza: capsula scura, ombra morbida, nessun bordo.
/// Se il mouse esce prima, non compare nulla.
private struct SymbolHint: View {
    let provenance: Provenance
    let delay: Double

    @State private var shown = false
    @State private var pending: Task<Void, Never>? = nil

    var body: some View {
        Image(systemName: provenance.symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(provenance.color)
            .frame(width: 14)
            .contentShape(Rectangle())
            .onHover { inside in
                pending?.cancel()
                if inside {
                    pending = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(delay))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.3)) { shown = true }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.15)) { shown = false }
                }
            }
            .onDisappear {
                pending?.cancel()
                shown = false
            }
            #if os(iOS)
            .onTapGesture {
                // Senza mouse non c'è il "fermarsi sopra": un tocco mostra il nome per un istante.
                pending?.cancel()
                withAnimation(.easeOut(duration: 0.2)) { shown = true }
                pending = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.8))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.15)) { shown = false }
                }
            }
            #endif
            .overlay(alignment: .top) { hint }
    }

    private var hint: some View {
        Text(provenance.label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(white: 0.07).opacity(0.92)))
            .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)
            .fixedSize()
            .alignmentGuide(.top) { d in d[.bottom] + 6 }      // sopra il simbolo, a 6 pt di distanza
            .opacity(shown ? 1 : 0)
            .allowsHitTesting(false)
    }
}
