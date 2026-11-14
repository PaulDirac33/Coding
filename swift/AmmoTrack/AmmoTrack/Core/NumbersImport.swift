//
//  NumbersImport.swift
//  AmmoTrack
//
//  Importa il CSV esportato dal foglio Numbers (9x21 con ricaricate/comprate, .22 solo comprate).
//
//  Dal foglio si prendono SOLO la data e le colonne dei movimenti (AGGIUNTE / SPARATE).
//  Le colonne RICARICATE, COMPRATE e TOTALE sono saldi: servono soltanto al CONTROLLO.
//  L'app rifà tutta la catena dai movimenti e la confronta riga per riga col foglio:
//  se un numero non torna, te lo segnala (errore di import o vecchio errore di battitura nel foglio).
//
//  - Il saldo di partenza della prima riga diventa un movimento "saldo iniziale" (uno per provenienza).
//    Se la prima riga non ha saldo di partenza (come nel .22) ma ha un TOTALE, l'importo implicito
//    (TOTALE meno i movimenti della riga) diventa il saldo iniziale.
//  - Le righe senza movimenti (es. "5 May 2025, 400, , 400") non creano nulla, ma si controllano lo stesso.
//  - Le date si leggono in vari formati: "18 December 2022", "21 Nov 2025", "1 Mar 26", ISO...
//  - Un giorno con aggiunte e spari insieme diventa più movimenti: prima le entrate, poi le uscite.
//  - Gli id sono deterministici (num-<calibro>-<riga>-<tipo>): importare di nuovo lo stesso foglio
//    sostituisce l'importazione precedente di quel calibro invece di duplicarla.
//

import Foundation

nonisolated struct NumbersImportReport: Sendable {
    var caliberID: String
    var movements: [Movement] = []
    var rowsRead = 0
    var rowsChecked = 0
    var issues: [String] = []
    var fatalError: String? = nil
    var sheetFinalTotal: Int? = nil
    var firstDate: Date? = nil
    var lastDate: Date? = nil

    init(caliberID: String) {
        self.caliberID = caliberID
    }

    var idPrefix: String { NumbersImport.idPrefix(for: caliberID) }

    /// Il saldo che risulta dai movimenti importati.
    var finalBalance: Balance {
        var b = Balance()
        for m in movements { b.apply(m) }
        return b
    }

    var isConsistent: Bool { fatalError == nil && issues.isEmpty }
}

nonisolated enum NumbersImport {

    static func idPrefix(for caliberID: String) -> String {
        "num-\(caliberID)-"
    }

    // MARK: Colonne

    private struct Layout {
        var startReloaded: Int? = nil
        var startBought: Int? = nil
        var addReloaded: Int? = nil
        var addBought: Int? = nil
        var addPlain: Int? = nil
        var shotReloaded: Int? = nil
        var shotBought: Int? = nil
        var shotPlain: Int? = nil
        var total: Int? = nil

        static func normalize(_ s: String) -> String {
            s.uppercased()
                .folding(options: .diacriticInsensitive, locale: nil)
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
        }

        /// La prima colonna è sempre la data (la sua intestazione è "Denunciate: 600").
        init(header: [String]) {
            for (i, raw) in header.enumerated() where i > 0 {
                let h = Layout.normalize(raw)
                if h == "TOTALE" { total = i }
                else if h == "RICARICATE" { startReloaded = i }
                else if h == "COMPRATE" { startBought = i }
                else if h.contains("AGGIUNT") && h.contains("RICARIC") { addReloaded = i }
                else if h.contains("AGGIUNT") && h.contains("COMPRAT") { addBought = i }
                else if h.contains("AGGIUNT") { addPlain = i }
                else if h.contains("SPARAT") && h.contains("RICARIC") { shotReloaded = i }
                else if h.contains("SPARAT") && h.contains("COMPRAT") { shotBought = i }
                else if h.contains("SPARAT") { shotPlain = i }
            }
        }

        func number(_ row: [String], _ index: Int?) -> Int? {
            guard let i = index, i < row.count else { return nil }
            return NumberParsing.int(row[i])
        }
    }

    private static func isHeader(_ row: [String]) -> Bool {
        let cells = row.map { Layout.normalize($0) }
        let hasTotal = cells.contains("TOTALE")
        let hasMovement = cells.contains { $0.contains("SPARAT") || $0.contains("AGGIUNT") }
        return hasTotal && hasMovement
    }

    private static func pad3(_ n: Int) -> String {
        n < 10 ? "00\(n)" : (n < 100 ? "0\(n)" : "\(n)")
    }

    private static func make(caliber: Caliber, number: Int, code: String, day: Date,
                             kind: MovementKind, provenance: Provenance, quantity: Int, note: String) -> Movement {
        Movement(id: "\(idPrefix(for: caliber.id))\(pad3(number))-\(code)",
                 date: Cal.stamp(day: day, kind: kind),
                 hasTime: false,
                 kind: kind,
                 provenance: provenance,
                 caliberID: caliber.id,
                 quantity: quantity,
                 weaponID: nil,
                 note: note)
    }

    // MARK: Import

    static func parse(text: String, caliber: Caliber) -> NumbersImportReport {
        var report = NumbersImportReport(caliberID: caliber.id)
        let rows = CSV.parse(text)

        guard let headerIndex = rows.firstIndex(where: { isHeader($0) }) else {
            report.fatalError = "Non trovo l'intestazione del foglio (servono colonne come SPARATE e TOTALE)."
            return report
        }
        let layout = Layout(header: rows[headerIndex])
        // Colonne SPARATE/AGGIUNTE senza indicazione: con la sola colonna COMPRATE (il .22) sono acquistate.
        let defaultProvenance: Provenance =
            (layout.startReloaded != nil && layout.startBought == nil) ? .reloaded : .bought

        var first = true
        var curR = 0                 // saldo che il foglio "dovrebbe" avere in questo punto
        var curB = 0
        var number = 0               // numero della riga dati (1, 2, 3...), per gli id

        for lineIndex in (headerIndex + 1)..<rows.count {
            let row = rows[lineIndex]
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }

            let lineNo = lineIndex + 1
            let dateText = row.first ?? ""
            guard let day = DateParsing.parseDay(dateText) else {
                report.issues.append("Riga \(lineNo): data non riconosciuta («\(dateText)»), riga ignorata.")
                continue
            }
            number += 1
            report.rowsRead += 1
            if report.firstDate == nil { report.firstDate = day }
            report.lastDate = day
            let label = "Riga \(lineNo) (\(dateText))"

            let startR = layout.number(row, layout.startReloaded)
            let startB = layout.number(row, layout.startBought)
            var addR = layout.number(row, layout.addReloaded) ?? 0
            var addB = layout.number(row, layout.addBought) ?? 0
            var shotR = layout.number(row, layout.shotReloaded) ?? 0
            var shotB = layout.number(row, layout.shotBought) ?? 0
            if let p = layout.number(row, layout.addPlain) {
                if defaultProvenance == .reloaded { addR += p } else { addB += p }
            }
            if let p = layout.number(row, layout.shotPlain) {
                if defaultProvenance == .reloaded { shotR += p } else { shotB += p }
            }
            let sheetTotal = layout.number(row, layout.total)

            let negatives: [(String, Int)] = [("aggiunte ricaricate", addR), ("aggiunte comprate", addB),
                                              ("sparate ricaricate", shotR), ("sparate comprate", shotB)]
            for (name, value) in negatives where value < 0 {
                report.issues.append("\(label): valore negativo in «\(name)» (\(value)), ignorato.")
            }
            addR = max(addR, 0)
            addB = max(addB, 0)
            shotR = max(shotR, 0)
            shotB = max(shotB, 0)

            if first {
                first = false
                var openR = startR ?? 0
                var openB = startB ?? 0
                // Prima riga senza saldo di partenza ma con TOTALE (il .22): il saldo iniziale è implicito.
                if let t = sheetTotal, startR == nil, startB == nil {
                    let implicit = t - (addR + addB - shotR - shotB)
                    if implicit != 0 {
                        if defaultProvenance == .reloaded { openR += implicit } else { openB += implicit }
                    }
                }
                if openR > 0 {
                    report.movements.append(make(caliber: caliber, number: number, code: "ini-ric", day: day,
                                                 kind: .opening, provenance: .reloaded, quantity: openR,
                                                 note: "Saldo iniziale dal foglio Numbers"))
                } else if openR < 0 {
                    report.issues.append("\(label): saldo iniziale ricaricate negativo (\(openR)), ignorato.")
                }
                if openB > 0 {
                    report.movements.append(make(caliber: caliber, number: number, code: "ini-com", day: day,
                                                 kind: .opening, provenance: .bought, quantity: openB,
                                                 note: "Saldo iniziale dal foglio Numbers"))
                } else if openB < 0 {
                    report.issues.append("\(label): saldo iniziale comprate negativo (\(openB)), ignorato.")
                }
                curR = openR
                curB = openB
            } else if startR != nil || startB != nil {
                // Controllo della catena: il saldo di partenza deve essere quello di fine riga precedente.
                let gotR = startR ?? 0
                let gotB = startB ?? 0
                if gotR != curR {
                    report.issues.append("\(label): ricaricate di partenza \(gotR), ma dai movimenti precedenti risultano \(curR).")
                    curR = gotR
                }
                if gotB != curB {
                    report.issues.append("\(label): comprate di partenza \(gotB), ma dai movimenti precedenti risultano \(curB).")
                    curB = gotB
                }
            }

            // I movimenti della riga: prima le entrate, poi le uscite.
            if addR > 0 {
                report.movements.append(make(caliber: caliber, number: number, code: "agg-ric", day: day,
                                             kind: .added, provenance: .reloaded, quantity: addR, note: ""))
            }
            if addB > 0 {
                report.movements.append(make(caliber: caliber, number: number, code: "agg-com", day: day,
                                             kind: .added, provenance: .bought, quantity: addB, note: ""))
            }
            if shotR > 0 {
                report.movements.append(make(caliber: caliber, number: number, code: "spa-ric", day: day,
                                             kind: .shot, provenance: .reloaded, quantity: shotR, note: ""))
            }
            if shotB > 0 {
                report.movements.append(make(caliber: caliber, number: number, code: "spa-com", day: day,
                                             kind: .shot, provenance: .bought, quantity: shotB, note: ""))
            }
            curR += addR - shotR
            curB += addB - shotB

            // Controllo di fine riga: TOTALE = saldo di partenza + entrate - uscite.
            if let t = sheetTotal {
                report.rowsChecked += 1
                report.sheetFinalTotal = t
                if t != curR + curB {
                    report.issues.append("\(label): TOTALE nel foglio \(t), calcolato \(curR + curB).")
                }
            }
        }

        if report.rowsRead == 0 {
            report.fatalError = "Nessuna riga con una data valida sotto l'intestazione."
        }
        return report
    }
}
