//
//  ChartsView.swift
//
//  La parte "Grafici" della pagina Dati: una colonna scorrevole di riquadri riassuntivi e grafici,
//  filtrati per calibro e periodo. I numeri vengono da Stats (Core), qui si calcolano e si passano alle schede.
//

import SwiftUI

struct ChartsView: View {
    @EnvironmentObject var store: DataStore

    let filter: CaliberFilter
    let period: Period

    @State private var binSize = 50

    /// Limite da mostrare sul grafico: del calibro scelto, oppure il totale se sono tutti.
    private var limit: Int? {
        if let id = filter.caliberID { return store.config.caliber(id)?.limit }
        return store.config.totalLimit
    }

    private var limitLabel: String {
        guard let limit else { return "" }
        return "Denunciate \(numText(limit))"
    }

    var body: some View {
        let since = period.start()
        let cid = filter.caliberID
        let movements = store.movements

        let summary = Stats.summary(ledger: store.ledger, movements: movements, caliberID: cid, since: since)
        let stock = Stats.stock(rows: store.ledger.rows, caliberID: cid, since: since)
        let shots = Stats.monthly(movements: movements, kind: .shot, caliberID: cid, since: since)
        let adds = Stats.monthly(movements: movements, kind: .added, caliberID: cid, since: since)
        let weapons = Stats.byWeapon(movements: movements, config: store.config, caliberID: cid, since: since, includeEmpty: false)
        let sessions = Stats.sessions(movements: movements, caliberID: cid, since: since)
        let bins = Stats.histogram(values: sessions.map { $0.shots }, binSize: binSize)

        ScrollView {
            VStack(spacing: 18) {
                SummaryStrip(summary: summary)
                StockCard(points: stock, limit: limit, limitLabel: limitLabel)
                MonthlyCard(title: "Colpi sparati per mese",
                            buckets: shots,
                            emptyText: "Nessuno sparo nel periodo",
                            showAverage: true)
                MonthlyCard(title: "Cartucce aggiunte per mese",
                            buckets: adds,
                            emptyText: "Nessuna entrata nel periodo")
                WeaponsCard(items: weapons)
                HistogramCard(bins: bins, sessionCount: sessions.count, binSize: $binSize)
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }
}
