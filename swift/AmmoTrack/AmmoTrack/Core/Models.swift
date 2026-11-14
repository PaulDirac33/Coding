//
//  Models.swift
//  AmmoTrack
//
//  Modelli di dominio: movimenti, calibri, armi, configurazione.
//  Solo Foundation: lo stesso codice gira su Mac e iPhone ed è testabile.
//
//  NOTA: i tipi del Core sono marcati `nonisolated` così funzionano con qualunque
//  impostazione di "Default Actor Isolation" del progetto (Xcode 26 usa MainActor per i nuovi progetti).
//

import Foundation

// MARK: - Tipi di movimento

/// Che cosa è successo alle cartucce.
nonisolated enum MovementKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case opening = "iniziale"        // saldo iniziale (una volta, all'inizio del registro)
    case added = "aggiunta"          // entrata: ricaricate o comprate
    case shot = "sparo"              // uscita: sparate
    case adjustment = "rettifica"    // correzione dell'inventario, con segno (+/-)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .opening: return "Saldo iniziale"
        case .added: return "Aggiunta"
        case .shot: return "Sparo"
        case .adjustment: return "Rettifica"
        }
    }

    /// Ordine a parità di istante: prima il saldo iniziale, poi le entrate, poi le uscite.
    var sortRank: Int {
        switch self {
        case .opening: return 0
        case .added: return 1
        case .adjustment: return 2
        case .shot: return 3
        }
    }
}

/// Da dove vengono le cartucce (o da quali si è sparato).
nonisolated enum Provenance: String, Codable, CaseIterable, Identifiable, Sendable {
    case reloaded = "ricaricate"
    case bought = "comprate"

    var id: String { rawValue }
    var label: String { self == .reloaded ? "Ricaricate" : "Comprate" }
}

// MARK: - Movimento

/// Una riga del registro. La quantità è sempre positiva (tranne le rettifiche, che hanno il segno):
/// il verso lo decide `kind`. I saldi non si salvano: si ricalcolano dai movimenti.
nonisolated struct Movement: Identifiable, Hashable, Sendable {
    var id: String
    /// Data e ora. Se `hasTime` è false l'ora è solo convenzionale (serve a ordinare i movimenti dello stesso giorno).
    var date: Date
    var hasTime: Bool
    var kind: MovementKind
    var provenance: Provenance
    var caliberID: String
    var quantity: Int
    var weaponID: String?
    var note: String

    init(id: String = UUID().uuidString,
         date: Date,
         hasTime: Bool,
         kind: MovementKind,
         provenance: Provenance,
         caliberID: String,
         quantity: Int,
         weaponID: String? = nil,
         note: String = "") {
        self.id = id
        self.date = date
        self.hasTime = hasTime
        self.kind = kind
        self.provenance = provenance
        self.caliberID = caliberID
        self.quantity = quantity
        self.weaponID = weaponID
        self.note = note
    }

    /// Variazione del saldo: + entra, - esce.
    var delta: Int {
        switch kind {
        case .opening, .added, .adjustment: return quantity
        case .shot: return -quantity
        }
    }

    /// "Sparo", "Ricarica", "Acquisto", "Saldo iniziale", "Rettifica".
    var title: String {
        switch kind {
        case .opening: return "Saldo iniziale"
        case .added: return provenance == .reloaded ? "Ricarica" : "Acquisto"
        case .shot: return "Sparo"
        case .adjustment: return "Rettifica"
        }
    }
}

// MARK: - Calibro

nonisolated struct Caliber: Identifiable, Codable, Hashable, Sendable {
    /// Identificatore stabile usato nel CSV (es. "9x21", "22lr"). Il nome si può cambiare, l'id no.
    var id: String
    var name: String
    /// Cartucce denunciate per questo calibro (nil = nessun limite).
    var limit: Int?
    /// false per il .22 LR: non si ricarica, quindi sparisce la scelta ricaricate/comprate.
    var allowsReload: Bool
    /// Nome per esteso, mostrato nel banner dell'Inserimento (es. "9 x 21 mm IMI"). nil = si usa `name`.
    var fullName: String?

    init(id: String, name: String, limit: Int? = nil, allowsReload: Bool = true, fullName: String? = nil) {
        self.id = id
        self.name = name
        self.limit = limit
        self.allowsReload = allowsReload
        self.fullName = fullName
    }

    enum CodingKeys: String, CodingKey { case id, name, limit, allowsReload, fullName }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let identifier = try c.decodeIfPresent(String.self, forKey: .id) ?? "calibro"
        self.id = identifier
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? identifier
        self.limit = try c.decodeIfPresent(Int.self, forKey: .limit)
        self.allowsReload = try c.decodeIfPresent(Bool.self, forKey: .allowsReload) ?? true
        self.fullName = try c.decodeIfPresent(String.self, forKey: .fullName)
    }
    /// Nome per esteso se c'è, altrimenti quello breve.
    var displayName: String {
        let t = (fullName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? name : t
    }

    /// ".22 LR" → "22lr", "9x21" → "9x21": minuscolo, solo lettere e cifre.
    static func slug(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        let cleaned = folded.filter { $0.isLetter || $0.isNumber }
        return cleaned.isEmpty ? "calibro" : cleaned
    }
}

// MARK: - Arma

nonisolated struct Weapon: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    /// Il calibro è incorporato nell'arma. Con un kit di conversione crea un'arma separata.
    var caliberID: String
    var serial: String          // matricola
    var notes: String
    /// Nome del file immagine dentro la cartella "Immagini" (nil = nessuna immagine).
    var imageFile: String?
    /// Un'arma archiviata sparisce dal selettore ma conserva lo storico.
    var isArchived: Bool

    init(id: String = UUID().uuidString,
         name: String = "",
         caliberID: String,
         serial: String = "",
         notes: String = "",
         imageFile: String? = nil,
         isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.caliberID = caliberID
        self.serial = serial
        self.notes = notes
        self.imageFile = imageFile
        self.isArchived = isArchived
    }

    enum CodingKeys: String, CodingKey { case id, name, caliberID, serial, notes, imageFile, isArchived }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.caliberID = try c.decodeIfPresent(String.self, forKey: .caliberID) ?? ""
        self.serial = try c.decodeIfPresent(String.self, forKey: .serial) ?? ""
        self.notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.imageFile = try c.decodeIfPresent(String.self, forKey: .imageFile)
        self.isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}

// MARK: - Configurazione (armi.json)

nonisolated struct Config: Codable, Equatable, Sendable {
    var version: Int
    /// Limite complessivo (tutti i calibri insieme). nil = nessun limite.
    var totalLimit: Int?
    var calibers: [Caliber]
    var weapons: [Weapon]

    init(version: Int = 1, totalLimit: Int? = nil, calibers: [Caliber], weapons: [Weapon] = []) {
        self.version = version
        self.totalLimit = totalLimit
        self.calibers = calibers
        self.weapons = weapons
    }

    /// Configurazione del primo avvio: 9x21 (600) e .22 LR (400), totale 1000.
    static var standard: Config {
        Config(version: 1,
               totalLimit: 1000,
               calibers: [Caliber(id: "9x21", name: "9x21", limit: 600, allowsReload: true, fullName: "9 x 21 mm IMI"),
                          Caliber(id: "22lr", name: "22 LR", limit: 400, allowsReload: false, fullName: ".22 Long Rifle")],
               weapons: [])
    }

    enum CodingKeys: String, CodingKey { case version, totalLimit, calibers, weapons }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.totalLimit = try c.decodeIfPresent(Int.self, forKey: .totalLimit)
        self.calibers = try c.decodeIfPresent([Caliber].self, forKey: .calibers) ?? []
        self.weapons = try c.decodeIfPresent([Weapon].self, forKey: .weapons) ?? []
    }

    func caliber(_ id: String) -> Caliber? {
        calibers.first { $0.id == id }
    }

    func weapon(_ id: String?) -> Weapon? {
        guard let id else { return nil }
        return weapons.first { $0.id == id }
    }

    /// Armi non archiviate di un calibro, nell'ordine del file.
    func activeWeapons(for caliberID: String) -> [Weapon] {
        weapons.filter { $0.caliberID == caliberID && !$0.isArchived }
    }

    func caliberName(_ id: String) -> String {
        caliber(id)?.name ?? id
    }
    func caliberLongName(_ id: String) -> String {
        caliber(id)?.displayName ?? id
    }

    mutating func setLimit(_ limit: Int?, for caliberID: String) {
        guard let i = calibers.firstIndex(where: { $0.id == caliberID }) else { return }
        let value = limit.flatMap { $0 > 0 ? $0 : nil }
        calibers[i].limit = value
    }
}

// MARK: - Filtro per calibro (Registro e grafici)

nonisolated enum CaliberFilter: Hashable, Sendable {
    case all
    case caliber(String)

    /// nil = tutti i calibri.
    var caliberID: String? {
        switch self {
        case .all: return nil
        case .caliber(let id): return id
        }
    }
}
