//
//  MovementCSV.swift
//  AmmoTrack
//
//  movimenti.csv: una riga per movimento, colonne lette per nome (l'ordine non conta,
//  si possono aggiungere colonne in futuro senza rompere nulla).
//
//  id,data,ora,tipo,provenienza,calibro,quantita,arma,arma_nome,nota
//
//  - data      AAAA-MM-GG
//  - ora       HH:MM:SS (vuota per i movimenti di cui si conosce solo il giorno)
//  - tipo      iniziale | aggiunta | sparo | rettifica
//  - provenienza  ricaricate | comprate
//  - calibro   id del calibro (es. 9x21, 22lr)
//  - arma      id dell'arma (arma_nome è solo informativa, per leggere il file in Numbers)
//

import Foundation

nonisolated struct MovementLoad: Sendable {
    var movements: [Movement] = []
    /// Righe non valide, ignorate.
    var skipped = 0
    /// Descrizione delle prime righe scartate (o del problema dell'intestazione).
    var notes: [String] = []
    /// false se il file non si riesce a interpretare: in quel caso non va mai sovrascritto.
    var isValid = true
}

nonisolated enum MovementCSV {

    static let columns = ["id", "data", "ora", "tipo", "provenienza", "calibro", "quantita", "arma", "arma_nome", "nota"]

    // MARK: Scrittura

    static func encode(_ movements: [Movement], weapons: [Weapon]) -> String {
        var names: [String: String] = [:]
        for w in weapons where names[w.id] == nil { names[w.id] = w.name }

        var lines: [String] = [CSV.line(columns)]
        for m in movements {
            let weaponName: String = m.weaponID.flatMap { names[$0] } ?? ""
            let fields: [String] = [
                m.id,
                isoDay(m.date),
                m.hasTime ? isoTime(m.date) : "",
                m.kind.rawValue,
                m.provenance.rawValue,
                m.caliberID,
                String(m.quantity),
                m.weaponID ?? "",
                weaponName,
                m.note
            ]
            lines.append(CSV.line(fields))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: Lettura

    private static func parseKind(_ s: String) -> (kind: MovementKind, implied: Provenance?)? {
        switch s {
        case "iniziale", "saldo iniziale", "saldo", "opening": return (.opening, nil)
        case "aggiunta", "aggiunte", "entrata", "add", "added": return (.added, nil)
        case "ricarica", "ricaricata", "ricaricate": return (.added, .reloaded)
        case "acquisto", "acquistata", "acquistate", "comprata", "comprate": return (.added, .bought)
        case "sparo", "spari", "sparata", "sparate", "uscita", "shot": return (.shot, nil)
        case "rettifica", "adjust", "adjustment": return (.adjustment, nil)
        default: return nil
        }
    }

    private static func parseProvenance(_ s: String) -> Provenance? {
        switch s {
        case "ricaricate", "ricaricata", "ricarica", "r": return .reloaded
        case "comprate", "comprata", "acquistate", "acquistata", "acquisto", "c": return .bought
        default: return nil
        }
    }

    static func decode(_ text: String, weapons: [Weapon]) -> MovementLoad {
        var load = MovementLoad()
        let rows = CSV.parse(text).filter { row in
            !row.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        guard let header = rows.first else { return load }        // file vuoto: valido, senza movimenti

        var index: [String: Int] = [:]
        for (i, h) in header.enumerated() { index[CSV.normalizeHeader(h)] = i }
        for required in ["data", "tipo", "calibro", "quantita"] where index[required] == nil {
            load.isValid = false
            load.notes.append("Intestazione non riconosciuta in movimenti.csv: manca la colonna «\(required)».")
            return load
        }

        var seen = Set<String>()

        for (offset, row) in rows.enumerated() where offset > 0 {
            func cell(_ name: String) -> String {
                guard let i = index[name], i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            func reject(_ why: String) {
                load.skipped += 1
                if load.notes.count < 5 { load.notes.append("Riga \(offset + 1): \(why)") }
            }

            let kindText = CSV.normalizeHeader(cell("tipo"))
            guard let parsed = parseKind(kindText) else {
                reject("tipo non riconosciuto («\(cell("tipo"))»)")
                continue
            }
            let kind = parsed.kind

            guard let day = DateParsing.parseDay(cell("data")) else {
                reject("data non valida («\(cell("data"))»)")
                continue
            }

            let caliberID = cell("calibro")
            guard !caliberID.isEmpty else {
                reject("calibro mancante")
                continue
            }

            guard let quantity = NumberParsing.int(cell("quantita")) else {
                reject("quantità non valida («\(cell("quantita"))»)")
                continue
            }
            if kind == .adjustment {
                guard quantity != 0 else { reject("rettifica a zero"); continue }
            } else {
                guard quantity > 0 else { reject("quantità non positiva (\(quantity))"); continue }
            }

            let provenanceText = CSV.normalizeHeader(cell("provenienza"))
            guard let provenance = parseProvenance(provenanceText) ?? parsed.implied else {
                reject("provenienza mancante o non riconosciuta («\(cell("provenienza"))»)")
                continue
            }

            var date = Cal.stamp(day: day, kind: kind)
            var hasTime = false
            if let t = DateParsing.parseTime(cell("ora")) {
                date = Cal.at(day, hour: t.hour, minute: t.minute, second: t.second)
                hasTime = true
            }

            // Arma: id; in mancanza, nome o matricola scritti a mano.
            let weaponToken = cell("arma")
            let weaponName = cell("arma_nome")
            var weaponID: String? = nil
            if !weaponToken.isEmpty || !weaponName.isEmpty {
                if !weaponToken.isEmpty, let w = weapons.first(where: { $0.id == weaponToken }) {
                    weaponID = w.id
                } else {
                    let probe = (weaponToken.isEmpty ? weaponName : weaponToken).lowercased()
                    if let w = weapons.first(where: { $0.name.lowercased() == probe || $0.serial.lowercased() == probe }) {
                        weaponID = w.id
                    } else if !weaponToken.isEmpty {
                        weaponID = weaponToken          // arma non riconosciuta: conservo il riferimento
                    }
                }
            }

            let rawID = cell("id")
            var id = rawID.isEmpty ? "r\(offset)" : rawID
            if seen.contains(id) { id += "-dup\(offset)" }
            seen.insert(id)

            load.movements.append(Movement(id: id,
                                           date: date,
                                           hasTime: hasTime,
                                           kind: kind,
                                           provenance: provenance,
                                           caliberID: caliberID,
                                           quantity: quantity,
                                           weaponID: weaponID,
                                           note: cell("nota")))
        }
        return load
    }

    // MARK: Esportazione leggibile (con i saldi, per Numbers/Excel)

    static let exportColumns = ["data", "ora", "calibro", "tipo", "provenienza", "variazione", "arma",
                                "matricola", "saldo_ricaricate", "saldo_comprate", "saldo_totale", "nota"]

    static func exportCSV(rows: [LedgerRow], config: Config) -> String {
        var lines: [String] = [CSV.line(exportColumns)]
        for r in rows {
            let m = r.movement
            let weapon = config.weapon(m.weaponID)
            let fields: [String] = [
                isoDay(m.date),
                m.hasTime ? isoTime(m.date) : "",
                config.caliberName(m.caliberID),
                m.title,
                m.provenance.label.lowercased(),
                String(m.delta),
                weapon?.name ?? "",
                weapon?.serial ?? "",
                String(r.after.reloaded),
                String(r.after.bought),
                String(r.after.total),
                m.note
            ]
            lines.append(CSV.line(fields))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
