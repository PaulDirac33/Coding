//
//  Ledger.swift
//  AmmoTrack
//
//  Il registro: ordina i movimenti e ricalcola i saldi (ricaricate, comprate, totale) per calibro.
//  I saldi non si salvano mai: se correggi o inserisci una riga vecchia si rifanno da soli.
//

import Foundation

/// Saldo di un calibro (o la somma di più calibri).
nonisolated struct Balance: Hashable, Sendable {
    var reloaded: Int = 0
    var bought: Int = 0

    var total: Int { reloaded + bought }
    var hasNegative: Bool { reloaded < 0 || bought < 0 }

    func value(_ p: Provenance) -> Int {
        p == .reloaded ? reloaded : bought
    }

    mutating func apply(_ m: Movement) {
        switch m.provenance {
        case .reloaded: reloaded += m.delta
        case .bought: bought += m.delta
        }
    }

    static func + (a: Balance, b: Balance) -> Balance {
        Balance(reloaded: a.reloaded + b.reloaded, bought: a.bought + b.bought)
    }
}

/// Un movimento con il saldo del suo calibro subito dopo di esso (come le colonne del foglio Numbers).
nonisolated struct LedgerRow: Identifiable, Hashable, Sendable {
    let movement: Movement
    let after: Balance
    /// true se l'uscita ha portato il saldo di quella provenienza sotto zero: quasi sempre manca un movimento.
    let isOverdrawn: Bool

    var id: String { movement.id }
}

nonisolated struct Ledger: Sendable {
    /// In ordine cronologico (dal più vecchio al più recente).
    let rows: [LedgerRow]
    /// Saldo attuale per calibro.
    let balances: [String: Balance]

    init(movements: [Movement]) {
        let ordered = Ledger.ordered(movements)
        var running: [String: Balance] = [:]
        var out: [LedgerRow] = []
        out.reserveCapacity(ordered.count)
        for m in ordered {
            var b = running[m.caliberID] ?? Balance()
            b.apply(m)
            running[m.caliberID] = b
            let overdrawn = m.delta < 0 && b.value(m.provenance) < 0
            out.append(LedgerRow(movement: m, after: b, isOverdrawn: overdrawn))
        }
        self.rows = out
        self.balances = running
    }

    /// Data e ora; a parità, saldo iniziale → entrate → rettifiche → uscite; a parità ancora, l'ordine del file.
    static func ordered(_ movements: [Movement]) -> [Movement] {
        movements.enumerated().sorted { a, b in
            if a.element.date != b.element.date { return a.element.date < b.element.date }
            let ra = a.element.kind.sortRank
            let rb = b.element.kind.sortRank
            if ra != rb { return ra < rb }
            return a.offset < b.offset
        }.map { $0.element }
    }

    /// Saldo di un calibro; con nil la somma di tutti.
    func balance(for caliberID: String?) -> Balance {
        if let id = caliberID { return balances[id] ?? Balance() }
        return balances.values.reduce(Balance(), +)
    }

    func row(id: String) -> LedgerRow? {
        rows.first { $0.movement.id == id }
    }

    var overdrawnCount: Int {
        rows.filter { $0.isOverdrawn }.count
    }
}
