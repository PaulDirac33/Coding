//
//  AmmoTrackImportReport.swift
//  AmmoTrack
//
//  Created by  Riccardo on 11/19/26.
//


//
//  AmmoTrackImport.swift
//  AmmoTrack
//
//  Importa un CSV generato dall'esportazione di AmmoTrack (pagina Dati ▸ Esporta):
//  data, ora, calibro, tipo, provenienza, variazione, arma, matricola, saldo_..., nota.
//
//  - Le colonne dei saldi si ignorano: i saldi si ricalcolano dai movimenti.
//  - Il calibro si riconosce dal nome (o dall'id); se manca nell'app viene registrato.
//  - L'arma si riconosce dal nome (e dalla matricola, se c'è); se manca viene registrata.
//  - I movimenti identici a quelli già nel registro non si importano di nuovo.
//

import Foundation

nonisolated struct AmmoTrackImportReport: Sendable {
    /// Movimenti nuovi, pronti da aggiungere al registro.
    var movements: [Movement] = []
    /// Movimenti del file già presenti nel registro (identici): non si importano.
    var duplicates = 0
    var newCalibers: [Caliber] = []
    var newWeapons: [Weapon] = []
    var rowsRead = 0
    var issues: [String] = []
    var fatalError: String? = nil
    var firstDate: Date? = nil
    var lastDate: Date? = nil
}

nonisolated enum AmmoTrackImport {

    static func parse(text: String, config: Config, existing: [Movement]) -> AmmoTrackImportReport {
        var report = AmmoTrackImportReport()

        let rows = CSV.parse(text).filter { row in
            !row.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        guard let header = rows.first else {
            report.fatalError = "Il file è vuoto."
            return report
        }

        var index: [String: Int] = [:]
        for (i, h) in header.enumerated() { index[CSV.normalizeHeader(h)] = i }
        for required in ["data", "calibro", "tipo", "variazione"] where index[required] == nil {
            report.fatalError = "Non è un CSV esportato da AmmoTrack: manca la colonna «\(required)»."
            return report
        }

        // Movimenti già nel registro, contati: servono a non duplicare un file importato due volte.
        var present: [String: Int] = [:]
        for m in existing { present[key(m), default: 0] += 1 }

        var newCalibers: [Caliber] = []
        var newWeapons: [Weapon] = []

        for (offset, row) in rows.enumerated() where offset > 0 {
            func cell(_ name: String) -> String {
                guard let i = index[name], i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            func reject(_ why: String) {
                report.issues.append("Riga \(offset + 1): \(why), riga ignorata.")
            }

            guard let parsed = MovementCSV.parseKind(CSV.normalizeHeader(cell("tipo"))) else {
                reject("tipo non riconosciuto («\(cell("tipo"))»)")
                continue
            }
            let kind = parsed.kind

            guard let day = DateParsing.parseDay(cell("data")) else {
                reject("data non valida («\(cell("data"))»)")
                continue
            }

            let caliberText = cell("calibro")
            guard !caliberText.isEmpty else {
                reject("calibro mancante")
                continue
            }

            guard let delta = NumberParsing.int(cell("variazione")), delta != 0 else {
                reject("variazione non valida («\(cell("variazione"))»)")
                continue
            }
            // Nell'esportazione gli spari hanno la variazione negativa; la quantità di un movimento
            // è sempre positiva (tranne le rettifiche, che hanno il segno).
            let quantity = kind == .adjustment ? delta : abs(delta)

            guard let provenance = MovementCSV.parseProvenance(CSV.normalizeHeader(cell("provenienza"))) ?? parsed.implied else {
                reject("provenienza mancante o non riconosciuta («\(cell("provenienza"))»)")
                continue
            }

            var date = Cal.stamp(day: day, kind: kind)
            var hasTime = false
            if let t = DateParsing.parseTime(cell("ora")) {
                date = Cal.at(day, hour: t.hour, minute: t.minute, second: t.second)
                hasTime = true
            }

            // Solo da qui in poi si registrano calibri e armi nuovi (la riga è valida).
            let caliberID = resolveCaliber(caliberText, config: config, new: &newCalibers)

            var weaponID: String? = nil
            let weaponName = cell("arma")
            if kind == .shot, !weaponName.isEmpty {
                weaponID = resolveWeapon(name: weaponName,
                                         serial: unwrap(cell("matricola")),
                                         caliberID: caliberID,
                                         config: config,
                                         new: &newWeapons)
            }

            let m = Movement(date: date,
                             hasTime: hasTime,
                             kind: kind,
                             provenance: provenance,
                             caliberID: caliberID,
                             quantity: quantity,
                             weaponID: weaponID,
                             note: cell("nota"))

            report.rowsRead += 1
            report.firstDate = min(report.firstDate ?? day, day)
            report.lastDate = max(report.lastDate ?? day, day)

            let k = key(m)
            if let n = present[k], n > 0 {
                present[k] = n - 1
                report.duplicates += 1
            } else {
                report.movements.append(m)
            }
        }

        report.newCalibers = newCalibers
        report.newWeapons = newWeapons
        if report.rowsRead == 0 {
            report.fatalError = "Nessuna riga valida nel file."
        }
        return report
    }

    // MARK: Aiuti

    /// Impronta di un movimento (senza id): due movimenti uguali in tutto sono lo stesso movimento.
    private static func key(_ m: Movement) -> String {
        [isoDay(m.date),
         m.hasTime ? isoTime(m.date) : "-",
         m.kind.rawValue,
         m.provenance.rawValue,
         m.caliberID,
         String(m.quantity),
         m.weaponID ?? "",
         m.note].joined(separator: "|")
    }

    /// Trova il calibro dal nome o dall'id ("9×21", "9x21"); se non c'è lo prepara nuovo.
    private static func resolveCaliber(_ text: String, config: Config, new: inout [Caliber]) -> String {
        let lower = text.lowercased()
        let slug = Caliber.slug(text)
        func match(_ c: Caliber) -> Bool {
            c.id == text || c.id == slug || c.name.lowercased() == lower || Caliber.slug(c.name) == slug
        }
        if let c = config.calibers.first(where: match) ?? new.first(where: match) { return c.id }
        new.append(Caliber(id: slug, name: text, limit: nil, allowsReload: true))
        return slug
    }

    /// Trova l'arma dal nome (stesso calibro); se c'è la matricola, deve essere compatibile.
    /// Se non c'è la prepara nuova.
    private static func resolveWeapon(name: String, serial: String, caliberID: String,
                                      config: Config, new: inout [Weapon]) -> String {
        let lower = name.lowercased()
        let serialLower = serial.lowercased()
        func match(_ w: Weapon) -> Bool {
            guard w.caliberID == caliberID,
                  w.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lower else { return false }
            // Stesso nome ma matricola diversa: è un'altra arma.
            if !serialLower.isEmpty, !w.serial.isEmpty, w.serial.lowercased() != serialLower { return false }
            return true
        }
        if let w = config.weapons.first(where: match) ?? new.first(where: match) { return w.id }
        let weapon = Weapon(name: name, caliberID: caliberID, serial: serial)
        new.append(weapon)
        return weapon.id
    }

    /// L'esportazione scrive le matricole con lo zero iniziale come ="0001" (per Numbers/Excel): tolgo l'involucro.
    private static func unwrap(_ s: String) -> String {
        guard s.count >= 3, s.hasPrefix("=\""), s.hasSuffix("\"") else { return s }
        return String(s.dropFirst(2).dropLast())
    }
}