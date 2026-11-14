//
//  Statistics.swift
//  AmmoTrack
//
//  Numeri per i grafici e per i riquadri riassuntivi: giacenza nel tempo, spari e entrate per mese,
//  colpi per arma, distribuzione dei colpi per uscita, autonomia.
//  Una "uscita" è un giorno con almeno uno sparo (tutti i calibri insieme, o quello filtrato).
//

import Foundation

// MARK: - Periodo

nonisolated enum Period: String, CaseIterable, Identifiable, Sendable {
    case threeMonths = "3 mesi"
    case sixMonths = "6 mesi"
    case year = "1 anno"
    case all = "Tutto"

    var id: String { rawValue }

    /// Inizio del periodo (nil = dall'inizio del registro).
    func start(now: Date = Date()) -> Date? {
        let cal = Cal.cal
        let today = cal.startOfDay(for: now)
        switch self {
        case .all: return nil
        case .threeMonths: return cal.date(byAdding: .month, value: -3, to: today)
        case .sixMonths: return cal.date(byAdding: .month, value: -6, to: today)
        case .year: return cal.date(byAdding: .year, value: -1, to: today)
        }
    }
}

// MARK: - Risultati

nonisolated struct MonthBucket: Identifiable, Hashable, Sendable {
    let month: Date
    var reloaded: Int
    var bought: Int
    var total: Int { reloaded + bought }
    var id: Date { month }
}

/// Saldo a fine giornata.
nonisolated struct DayBalance: Identifiable, Hashable, Sendable {
    let day: Date
    let reloaded: Int
    let bought: Int
    var total: Int { reloaded + bought }
    var id: Date { day }
}

nonisolated struct Session: Identifiable, Hashable, Sendable {
    let day: Date
    let shots: Int
    var id: Date { day }
}

nonisolated struct WeaponTotal: Identifiable, Hashable, Sendable {
    let weaponID: String?          // nil = sparate senza arma indicata
    let name: String
    let caliberID: String
    let shots: Int
    let sessions: Int
    let lastDate: Date?

    var id: String { weaponID ?? "none|\(caliberID)" }
}

nonisolated struct HistBin: Identifiable, Hashable, Sendable {
    let start: Int
    let end: Int            // esclusa
    let count: Int
    var id: Int { start }
}

nonisolated struct Summary: Sendable {
    var shots = 0
    var shotsReloaded = 0
    var shotsBought = 0
    var addedReloaded = 0
    var addedBought = 0
    var sessions = 0
    var averagePerSession = 0.0
    var lastSession: Date? = nil
    var stock = Balance()
    /// Colpi al mese nel periodo considerato.
    var monthlyRate = 0.0
    /// Mesi di scorta al ritmo attuale (nil se non si è mai sparato).
    var runwayMonths: Double? = nil
}

// MARK: - Calcoli

nonisolated enum Stats {

    static func matches(_ m: Movement, caliberID: String?, since: Date?) -> Bool {
        if let c = caliberID, m.caliberID != c { return false }
        if let s = since, m.date < s { return false }
        return true
    }

    // MARK: Giacenza nel tempo

    /// Saldo a fine giornata, dal primo movimento (o da `since`) fino a oggi.
    /// Per il grafico a gradino: un punto per giorno in cui c'è stato un movimento, più l'inizio e la fine del periodo.
    static func stock(rows: [LedgerRow], caliberID: String?, since: Date?, until: Date = Date()) -> [DayBalance] {
        let cal = Cal.cal
        var running = Balance()
        var perDay: [(day: Date, balance: Balance)] = []
        for r in rows {
            if let c = caliberID, r.movement.caliberID != c { continue }
            running.apply(r.movement)
            let day = cal.startOfDay(for: r.movement.date)
            if let last = perDay.last, last.day == day {
                perDay[perDay.count - 1] = (day, running)
            } else {
                perDay.append((day, running))
            }
        }
        guard !perDay.isEmpty else { return [] }

        var result: [DayBalance] = []
        if let s = since {
            let start = cal.startOfDay(for: s)
            let before = perDay.last(where: { $0.day < start })?.balance ?? Balance()
            let inRange = perDay.filter { $0.day >= start }
            if inRange.first?.day != start {
                result.append(DayBalance(day: start, reloaded: before.reloaded, bought: before.bought))
            }
            for p in inRange {
                result.append(DayBalance(day: p.day, reloaded: p.balance.reloaded, bought: p.balance.bought))
            }
        } else {
            for p in perDay {
                result.append(DayBalance(day: p.day, reloaded: p.balance.reloaded, bought: p.balance.bought))
            }
        }

        let today = cal.startOfDay(for: until)
        if let last = result.last, last.day < today {
            result.append(DayBalance(day: today, reloaded: last.reloaded, bought: last.bought))
        }
        return result
    }

    // MARK: Mesi

    /// Somma per mese dei movimenti di un tipo (sparo o aggiunta), con gli zeri dei mesi vuoti.
    static func monthly(movements: [Movement], kind: MovementKind, caliberID: String?, since: Date?,
                        until: Date = Date()) -> [MonthBucket] {
        let cal = Cal.cal
        let items = movements.filter { $0.kind == kind && matches($0, caliberID: caliberID, since: since) }
        guard let firstDate = items.map({ $0.date }).min() else { return [] }

        var map: [Date: (reloaded: Int, bought: Int)] = [:]
        for m in items {
            let key = Cal.monthStart(m.date)
            var v = map[key] ?? (0, 0)
            if m.provenance == .reloaded { v.reloaded += m.quantity } else { v.bought += m.quantity }
            map[key] = v
        }

        var cursor = Cal.monthStart(since ?? firstDate)
        let last = Cal.monthStart(until)
        var out: [MonthBucket] = []
        var guardCount = 0
        while cursor <= last && guardCount < 1200 {
            let v = map[cursor] ?? (0, 0)
            out.append(MonthBucket(month: cursor, reloaded: v.reloaded, bought: v.bought))
            guard let next = cal.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        return out
    }

    // MARK: Uscite

    /// Colpi sparati per giorno (solo i giorni con almeno uno sparo).
    static func sessions(movements: [Movement], caliberID: String?, since: Date?) -> [Session] {
        var perDay: [Date: Int] = [:]
        for m in movements where m.kind == .shot && matches(m, caliberID: caliberID, since: since) {
            perDay[Cal.startOfDay(m.date), default: 0] += m.quantity
        }
        return perDay.map { Session(day: $0.key, shots: $0.value) }.sorted { $0.day < $1.day }
    }

    /// Istogramma con bin da `binSize` colpi: [0, 50), [50, 100)...
    static func histogram(values: [Int], binSize: Int) -> [HistBin] {
        guard binSize > 0, !values.isEmpty else { return [] }
        var counts: [Int: Int] = [:]
        for v in values where v >= 0 {
            counts[v / binSize, default: 0] += 1
        }
        guard let maxK = counts.keys.max() else { return [] }
        return (0...maxK).map { k in
            HistBin(start: k * binSize, end: (k + 1) * binSize, count: counts[k] ?? 0)
        }
    }

    // MARK: Armi

    private struct Accumulator {
        var shots = 0
        var days = Set<Date>()
        var last: Date? = nil
    }

    /// Colpi per arma (più "Senza arma" per gli spari senza arma indicata), dal più usato al meno usato.
    static func byWeapon(movements: [Movement], config: Config, caliberID: String?, since: Date?,
                         includeEmpty: Bool) -> [WeaponTotal] {
        var acc: [String: Accumulator] = [:]
        for m in movements where m.kind == .shot && matches(m, caliberID: caliberID, since: since) {
            let key = m.weaponID ?? "none|\(m.caliberID)"
            var a = acc[key] ?? Accumulator()
            a.shots += m.quantity
            a.days.insert(Cal.startOfDay(m.date))
            if let l = a.last {
                if m.date > l { a.last = m.date }
            } else {
                a.last = m.date
            }
            acc[key] = a
        }

        var out: [WeaponTotal] = []
        var used = Set<String>()

        for w in config.weapons {
            if let c = caliberID, w.caliberID != c { continue }
            let a = acc[w.id]
            if a == nil && (!includeEmpty || w.isArchived) { continue }
            used.insert(w.id)
            out.append(WeaponTotal(weaponID: w.id, name: w.name, caliberID: w.caliberID,
                                   shots: a?.shots ?? 0, sessions: a?.days.count ?? 0, lastDate: a?.last))
        }
        // Armi non più in configurazione e spari senza arma.
        for (key, a) in acc where !used.contains(key) {
            if key.hasPrefix("none|") {
                let cid = String(key.dropFirst(5))
                out.append(WeaponTotal(weaponID: nil, name: "Senza arma · \(config.caliberName(cid))", caliberID: cid,
                                       shots: a.shots, sessions: a.days.count, lastDate: a.last))
            } else {
                let cid = movements.first(where: { $0.weaponID == key })?.caliberID ?? ""
                out.append(WeaponTotal(weaponID: key, name: "Arma eliminata", caliberID: cid,
                                       shots: a.shots, sessions: a.days.count, lastDate: a.last))
            }
        }
        return out.sorted { a, b in
            if a.shots != b.shots { return a.shots > b.shots }
            return a.name < b.name
        }
    }

    // MARK: Riepilogo

    static func summary(ledger: Ledger, movements: [Movement], caliberID: String?, since: Date?,
                        now: Date = Date()) -> Summary {
        var s = Summary()
        var days = Set<Date>()
        var firstShot: Date? = nil
        var lastShot: Date? = nil

        for m in movements where matches(m, caliberID: caliberID, since: since) {
            switch m.kind {
            case .shot:
                s.shots += m.quantity
                if m.provenance == .reloaded { s.shotsReloaded += m.quantity } else { s.shotsBought += m.quantity }
                days.insert(Cal.startOfDay(m.date))
                if let f = firstShot { if m.date < f { firstShot = m.date } } else { firstShot = m.date }
                if let l = lastShot { if m.date > l { lastShot = m.date } } else { lastShot = m.date }
            case .added:
                if m.provenance == .reloaded { s.addedReloaded += m.quantity } else { s.addedBought += m.quantity }
            case .opening, .adjustment:
                break
            }
        }

        s.sessions = days.count
        s.lastSession = lastShot
        s.averagePerSession = days.isEmpty ? 0 : Double(s.shots) / Double(days.count)
        s.stock = ledger.balance(for: caliberID)

        if s.shots > 0 {
            let from: Date
            if let since { from = Cal.startOfDay(since) } else { from = Cal.startOfDay(firstShot ?? now) }
            let spanDays = max(30.0, now.timeIntervalSince(from) / 86_400)
            s.monthlyRate = Double(s.shots) / (spanDays / 30.4375)
            if s.monthlyRate > 0 {
                s.runwayMonths = Double(max(s.stock.total, 0)) / s.monthlyRate
            }
        }
        return s
    }
}
