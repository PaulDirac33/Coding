//
//  BalanceCard.swift
//
//  I saldi attuali per calibro (ricaricate, comprate, totale) rispetto alle cartucce denunciate,
//  più il totale generale: sono i numeri che prima guardavi nel foglio Numbers.
//

import SwiftUI

struct BalanceCard: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        VStack(spacing: 10) {
            ForEach(store.config.calibers) { c in
                caliberRow(c)
            }
            if store.config.calibers.count > 1 {
                totalRow
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: 700)
        .liquidGlass(cornerRadius: 22)
    }

    private func figure(_ title: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption)
                .foregroundStyle(Palette.muted)
            Text(numText(value))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(value < 0 ? Palette.danger : Color.white)
        }
        .frame(width: 134, alignment: .leading)
    }

    private func usage(_ total: Int, _ limit: Int?) -> some View {
        let over = limit.map { total > $0 } ?? false
        let text = limit.map { "\(numText(total)) / \(numText($0))" } ?? numText(total)
        return Text(text)
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .foregroundStyle(over ? Palette.danger : Color.white)
            .frame(width: 104, alignment: .trailing)
    }

    private func caliberRow(_ c: Caliber) -> some View {
        let b = store.ledger.balance(for: c.id)
        return HStack(spacing: 14) {
            Text(c.name)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 70, alignment: .leading)
            if c.allowsReload {
                figure("Ricaricate", b.reloaded, Palette.reloaded)
            } else {
                Color.clear.frame(width: 134, height: 1)
            }
            figure("Comprate", b.bought, Palette.bought)
            LimitBar(value: b.total, limit: c.limit)
            usage(b.total, c.limit)
        }
    }

    private var totalRow: some View {
        let b = store.ledger.balance(for: nil)
        let limit = store.config.totalLimit
        return HStack(spacing: 14) {
            Text("Totale")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 70, alignment: .leading)
            figure("Ricaricate", b.reloaded, Palette.reloaded)
            figure("Comprate", b.bought, Palette.bought)
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
