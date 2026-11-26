//
//  DataStore.swift
//  AmmoTrack
//
//  Lo "store" dell'app: legge e scrive movimenti.csv e armi.json, espone i movimenti, il registro con i saldi
//  e la configurazione. Rilegge i file da solo quando cambiano (controllo ogni secondo, come nell'altra app),
//  quindi anche le modifiche fatte da fuori (iCloud, terminale, Numbers) compaiono subito.
//
//  Ogni scrittura: rilegge il file da disco, applica la modifica e lo riscrive in modo atomico
//  (così non si perdono righe aggiunte altrove nel frattempo), con copia di sicurezza prima.
//  Se un file non si riesce a leggere, l'app NON lo sovrascrive mai.
//

import Foundation
import Combine
import CoreGraphics

@MainActor
final class DataStore: ObservableObject {

    // MARK: Stato pubblicato

    @Published private(set) var config: Config = Config.standard
    @Published private(set) var movements: [Movement] = []
    @Published private(set) var ledger: Ledger = Ledger(movements: [])
    @Published private(set) var folderURL: URL? = nil
    /// true finché non c'è una cartella dei dati (compare la schermata di scelta).
    @Published private(set) var needsFolder = false
    /// Problema di lettura o scrittura, da mostrare in rosso.
    @Published private(set) var message: String? = nil
    /// Avviso non bloccante (es. righe del CSV ignorate).
    @Published private(set) var notice: String? = nil
    /// Nome dell'azione che ⌘Z annullerebbe (es. "Sparo 50"); nil = niente da annullare.
    @Published private(set) var undoName: String? = nil
    /// Nome dell'azione che ⇧⌘Z ripristinerebbe; nil = niente da ripetere.
    @Published private(set) var redoName: String? = nil

    // MARK: Stato interno

    private var files: ArchiveFiles? = nil
    private var started = false
    private var movementsStamp: FileStamp? = nil
    private var configStamp: FileStamp? = nil
    private var movementsWritable = true
    private var configWritable = true
    private var skippedRows = 0
    private var configProblem: String? = nil
    private var movementsProblem: String? = nil
    private var imageCache: [String: CGImage] = [:]
    private var undoStack: [UndoStep] = []
    private var redoStack: [UndoStep] = []
    private let undoLimit = 100

    init() {}

    // MARK: Avvio e cartella

    /// Apre la cartella salvata (o quella predefinita). Si può chiamare più volte.
    func start() {
        guard !started else { return }
        started = true
        if let url = FolderAccess.restore() {
            open(url)
        } else {
            needsFolder = true
        }
    }

    /// Usa una nuova cartella (scelta dall'utente) e la ricorda.
    func chooseFolder(_ url: URL) {
        FolderAccess.remember(url)
        started = true
        imageCache.removeAll()
        clearUndo()          // le pile si riferiscono alla cartella vecchia
        open(url)
    }

    private func open(_ url: URL) {
        folderURL = url
        needsFolder = false
        let f = ArchiveFiles(folder: url)
        do {
            try f.prepare()
        } catch {
            files = nil
            movementsProblem = describe(error, path: url.path)
            updateMessage()
            return
        }
        files = f
        movementsStamp = nil
        configStamp = nil
        movementsProblem = nil
        configProblem = nil
        refresh(force: true)
    }

    // MARK: Lettura

    /// Rilegge i file solo se sono cambiati (o se force == true).
    func refresh(force: Bool = false) {
        guard let f = files else { return }

        let cs = f.stamp(of: f.configURL)
        if force || cs != configStamp {
            loadConfig(f)
            configStamp = f.stamp(of: f.configURL)
        }

        let ms = f.stamp(of: f.movementsURL)
        if force || ms != movementsStamp {
            loadMovements(f)
            movementsStamp = f.stamp(of: f.movementsURL)
        }
        updateMessage()
    }

    private func loadConfig(_ f: ArchiveFiles) {
        do {
            if let c = try f.loadConfig() {
                if c != config { config = c }
            } else {
                // Primo avvio (o file vuoto): scrivo la configurazione predefinita.
                let standard = Config.standard
                try f.saveConfig(standard, backup: false)
                config = standard
            }
            configWritable = true
            configProblem = nil
        } catch {
            configWritable = false
            configProblem = "armi.json non è leggibile (\(error.localizedDescription)). Non lo modifico: correggilo o ripristina una copia da Backup/."
        }
    }

    private func loadMovements(_ f: ArchiveFiles) {
        do {
            guard let text = try f.loadMovementsText() else {
                // File mancante: lo creo con la sola intestazione.
                try f.saveMovements(text: MovementCSV.encode([], weapons: []), backup: .none)
                skippedRows = 0
                movementsWritable = true
                movementsProblem = nil
                notice = nil
                apply(movements: [])
                return
            }
            let load = MovementCSV.decode(text, weapons: config.weapons)
            if !load.isValid {
                movementsWritable = false
                movementsProblem = load.notes.first ?? "movimenti.csv non è interpretabile."
                apply(movements: [])
                return
            }
            movementsWritable = true
            movementsProblem = nil
            skippedRows = load.skipped
            if load.skipped > 0 {
                let first = load.notes.first ?? ""
                notice = "\(load.skipped) righe di movimenti.csv non valide sono state ignorate. \(first)"
            } else {
                notice = nil
            }
            apply(movements: load.movements)
            registerUnknownCalibers()
        } catch {
            movementsWritable = false
            movementsProblem = describe(error, path: f.movementsURL.path)
        }
    }

    private func apply(movements list: [Movement]) {
        movements = list
        ledger = Ledger(movements: list)
    }

    private func updateMessage() {
        let m = movementsProblem ?? configProblem
        if message != m { message = m }
    }

    /// Se il CSV contiene calibri che non sono in armi.json (es. aggiunti a mano) li registro, senza limite.
    private func registerUnknownCalibers() {
        let known = Set(config.calibers.map { $0.id })
        let unknown = Set(movements.map { $0.caliberID }).subtracting(known)
        guard !unknown.isEmpty, configWritable else { return }
        _ = mutateConfig(undoName: nil) { cfg in
            for id in unknown.sorted() {
                cfg.calibers.append(Caliber(id: id, name: id, limit: nil, allowsReload: true))
            }
            return nil
        }
    }

    // MARK: Movimenti

    /// Rilegge il CSV da disco, applica `change`, lo riscrive in modo atomico (con copia di sicurezza).
    /// Restituisce un messaggio d'errore, oppure nil se è andato tutto bene.
    private func mutateMovements(backup: BackupMode, undoName: String?,
                                 _ change: (inout [Movement]) -> String?) -> String? {
        guard let f = files else { return "Cartella dei dati non disponibile." }
        guard movementsWritable else {
            return "movimenti.csv non è leggibile: non lo modifico per non perdere dati."
        }

        var current: [Movement] = []
        do {
            if let text = try f.loadMovementsText() {
                let load = MovementCSV.decode(text, weapons: config.weapons)
                guard load.isValid else { return load.notes.first ?? "movimenti.csv non è interpretabile." }
                current = load.movements
                skippedRows = load.skipped
            }
        } catch {
            return describe(error, path: f.movementsURL.path)
        }

        // File vuoto ma in memoria ci sono dati: qualcosa non va (es. sincronizzazione iCloud in corso).
        if current.isEmpty && !movements.isEmpty && skippedRows == 0 {
            return "Il file dei movimenti risulta vuoto mentre l'app ha dei dati: non lo sovrascrivo. Aspetta la sincronizzazione o riavvia l'app."
        }

        let before = current                                            // NUOVO

        if let error = change(&current) { return error }

        // Se c'erano righe illeggibili (che nella riscrittura andrebbero perse) la copia è sempre obbligatoria.
        let mode: BackupMode = skippedRows > 0 ? .always : backup
        do {
            try f.saveMovements(text: MovementCSV.encode(current, weapons: config.weapons), backup: mode)
        } catch {
            return describe(error, path: f.movementsURL.path)
        }
        apply(movements: current)
        movementsStamp = f.stamp(of: f.movementsURL)
        registerUnknownCalibers()

        // NUOVO: ricordo cosa è cambiato, per ⌘Z
        if let name = undoName {
            let diff = MovementDiff(from: before, to: current)
            if !diff.isEmpty { record(name, .movements(diff)) }
        }
        return nil
    }

    /// Aggiunge un movimento in fondo al registro.
    /// Con `allowOverdraw: false` rifiuta gli spari che porterebbero un saldo sotto zero.
    @discardableResult
    func add(_ m: Movement, allowOverdraw: Bool = true) -> String? {
        mutateMovements(backup: .dailyIfNeeded,
                        undoName: "\(m.title) \(numText(m.quantity))") { list in
            if !allowOverdraw, let problem = overdrawProblem(adding: m, to: list) { return problem }
            list.append(m)
            return nil
        }
    }

    /// Se aggiungere `m` porterebbe sotto zero un saldo che ora non lo è, descrive il problema; altrimenti nil.
    /// Si basa sul registro in ordine cronologico, quindi vale anche per i giorni passati: uno sparo vecchio
    /// che farebbe andare in negativo uno sparo successivo viene rifiutato. Le entrate non possono mai farlo.
    private func overdrawProblem(adding m: Movement, to list: [Movement]) -> String? {
        guard m.delta < 0 else { return nil }
        let already = Set(Ledger(movements: list).rows.filter { $0.isOverdrawn }.map { $0.id })
        let rows = Ledger(movements: list + [m]).rows
        guard let broken = rows.first(where: { $0.isOverdrawn && !already.contains($0.id) }) else { return nil }

        let name = config.caliberName(m.caliberID)
        let kind = m.provenance.label.lowercased()
        if broken.id == m.id {
            // Il saldo dopo lo sparo è negativo: prima ce n'erano quantità + saldo.
            let available = max(broken.after.value(m.provenance) + m.quantity, 0)
            let when = m.hasTime ? "" : " al \(dayText(m.date))"
            return "Non hai abbastanza \(kind) \(name)\(when): servono \(numText(m.quantity)), ne hai \(numText(available))."
        }
        return "Non registrato: il saldo \(kind) \(name) andrebbe sotto zero il \(dayText(broken.movement.date))."
    }

    func update(_ m: Movement) -> String? {
        mutateMovements(backup: .always, undoName: "Modifica movimento") { list in
            guard let i = list.firstIndex(where: { $0.id == m.id }) else { return "Il movimento non esiste più." }
            list[i] = m
            return nil
        }
    }

    func delete(ids: Set<String>) -> String? {
        let name = ids.count == 1 ? "Eliminazione movimento" : "Eliminazione di \(ids.count) movimenti"
        return mutateMovements(backup: .always, undoName: name) { list in
            list.removeAll { ids.contains($0.id) }
            return nil
        }
    }

    /// Importa dei movimenti (es. dal foglio Numbers). Se `replacingPrefix` è indicato, prima toglie i movimenti
    /// con quel prefisso di id (una precedente importazione dello stesso foglio): non si duplica nulla.
    func importMovements(_ list: [Movement], replacingPrefix: String?) -> String? {
        mutateMovements(backup: .always,
                        undoName: "Importazione di \(numText(list.count)) movimenti") { current in
            if let prefix = replacingPrefix {
                current.removeAll { $0.id.hasPrefix(prefix) }
            }
            let existing = Set(current.map { $0.id })
            current.append(contentsOf: list.filter { !existing.contains($0.id) })
            return nil
        }
    }
    /// Importa un CSV di AmmoTrack: prima registra i calibri e le armi che non ci sono ancora,
    /// poi aggiunge i movimenti. Per ⌘Z sono due passi: prima si annullano i movimenti, poi le armi.
    func importAmmoTrack(_ report: AmmoTrackImportReport) -> String? {
        let calibers = report.newCalibers
        let weapons = report.newWeapons
        if !calibers.isEmpty || !weapons.isEmpty {
            let failure = mutateConfig(undoName: "Importazione di armi e calibri") { cfg in
                for c in calibers where !cfg.calibers.contains(where: { $0.id == c.id }) {
                    cfg.calibers.append(c)
                }
                for w in weapons where !cfg.weapons.contains(where: { $0.id == w.id }) {
                    cfg.weapons.append(w)
                }
                return nil
            }
            if let failure { return failure }
        }
        return importMovements(report.movements, replacingPrefix: nil)
    }

    // MARK: Annulla / Ripeti (⌘Z, ⇧⌘Z)

    /// Annulla l'ultima azione. Restituisce un messaggio d'errore, oppure nil.
    @discardableResult
    func undo() -> String? {
        guard let step = undoStack.last else { return nil }
        if let error = replay(step, reversed: true) {
            notice = error
            return error
        }
        undoStack.removeLast()
        redoStack.append(step)
        syncUndoState()
        return nil
    }

    /// Ripete l'ultima azione annullata.
    @discardableResult
    func redo() -> String? {
        guard let step = redoStack.last else { return nil }
        if let error = replay(step, reversed: false) {
            notice = error
            return error
        }
        redoStack.removeLast()
        undoStack.append(step)
        syncUndoState()
        return nil
    }

    /// Rifà (o disfa) un passo scrivendo i file. Non registra nulla nelle pile.
    private func replay(_ step: UndoStep, reversed: Bool) -> String? {
        switch step.change {
        case .movements(let diff):
            let d = reversed ? diff.inverted : diff
            return mutateMovements(backup: .dailyIfNeeded, undoName: nil) { list in
                d.apply(to: &list)
                return nil
            }
        case .config(let before, let after):
            let target = reversed ? before : after
            return mutateConfig(undoName: nil) { cfg in
                cfg = target
                return nil
            }
        }
    }

    private func record(_ name: String, _ change: UndoChange) {
        undoStack.append(UndoStep(name: name, change: change))
        if undoStack.count > undoLimit { undoStack.removeFirst(undoStack.count - undoLimit) }
        redoStack.removeAll()                       // una nuova azione cancella il "ripeti"
        syncUndoState()
    }

    private func clearUndo() {
        undoStack.removeAll()
        redoStack.removeAll()
        syncUndoState()
    }

    private func syncUndoState() {
        undoName = undoStack.last?.name
        redoName = redoStack.last?.name
    }

    // MARK: Configurazione (calibri, limiti, armi)

    /// Rilegge armi.json da disco, applica `change` e lo riscrive (con copia di sicurezza).
    /// `undoName` è il nome dell'azione nel menu Annulla (nil = non annullabile).
    func mutateConfig(undoName: String? = "Modifica impostazioni",
                      _ change: (inout Config) -> String?) -> String? {
        guard let f = files else { return "Cartella dei dati non disponibile." }
        guard configWritable else { return "armi.json non è leggibile: non lo modifico per non perdere dati." }

        var current = config
        do {
            if let c = try f.loadConfig() { current = c }
        } catch {
            return "armi.json non è leggibile (\(error.localizedDescription))."
        }
        let before = current                                            // NUOVO
        if let error = change(&current) { return error }
        do {
            try f.saveConfig(current, backup: true)
        } catch {
            return describe(error, path: f.configURL.path)
        }
        config = current
        configStamp = f.stamp(of: f.configURL)
        if let name = undoName, current != before {                     // NUOVO
            record(name, .config(before: before, after: current))
        }
        return nil
    }

    func isCaliberUsed(_ id: String) -> Bool {
        movements.contains { $0.caliberID == id } || config.weapons.contains { $0.caliberID == id }
    }

    func movementCount(forWeapon id: String) -> Int {
        movements.filter { $0.weaponID == id }.count
    }

    // MARK: Armi e immagini

    /// Salva (o crea) un'arma. `newImage` è un JPEG già pronto, `newLogo` un PNG; i `remove…` tolgono quelli attuali.
    func saveWeapon(_ weapon: Weapon, newImage: Data?, removeImage: Bool,
                    newLogo: Data? = nil, removeLogo: Bool = false) -> String? {
        guard let f = files else { return "Cartella dei dati non disponibile." }
        var w = weapon
        let isNew = config.weapon(weapon.id) == nil

        if let data = newImage {
            let name = "\(w.id)-\(Int(Date().timeIntervalSince1970)).jpg"
            do {
                try f.writeImage(data, name: name)
            } catch {
                return describe(error, path: f.imagesURL.path)
            }
            w.imageFile = name
        } else if removeImage {
            w.imageFile = nil
        }

        var writtenLogo: String? = nil
        if let data = newLogo {
            let name = "\(w.id)-logo-\(Int(Date().timeIntervalSince1970)).png"
            do {
                try f.writeImage(data, name: name)
            } catch {
                if newImage != nil, let written = w.imageFile { f.deleteImage(name: written) }
                return describe(error, path: f.imagesURL.path)
            }
            w.logoFile = name
            writtenLogo = name
        } else if removeLogo {
            w.logoFile = nil
        }

        let saved = w
        let error = mutateConfig(undoName: isNew ? "Nuova arma" : "Modifica arma") { cfg in
            if let i = cfg.weapons.firstIndex(where: { $0.id == saved.id }) {
                cfg.weapons[i] = saved
            } else {
                cfg.weapons.append(saved)
            }
            return nil
        }

        if error != nil {
            // salvataggio fallito: tolgo i file appena scritti
            if newImage != nil, let name = saved.imageFile { f.deleteImage(name: name) }
            if let name = writtenLogo { f.deleteImage(name: name) }
        }
        return error
    }
    /// Elimina un'arma solo se non ha movimenti; altrimenti va archiviata.
    func deleteWeapon(_ id: String) -> String? {
        let n = movementCount(forWeapon: id)
        if n > 0 {
            return "L'arma ha \(n) movimenti nel registro: non si può eliminare. Archiviala per toglierla dal selettore."
        }
        return mutateConfig(undoName: "Eliminazione arma") { cfg in
            cfg.weapons.removeAll { $0.id == id }
            return nil
        }
    }

    func setArchived(_ id: String, _ archived: Bool) -> String? {
        mutateConfig(undoName: archived ? "Archivia arma" : "Ripristina arma") { cfg in
            guard let i = cfg.weapons.firstIndex(where: { $0.id == id }) else { return "Arma non trovata." }
            cfg.weapons[i].isArchived = archived
            return nil
        }
    }

    /// Foto dell'arma ridimensionata (con cache in memoria).
    func image(for weapon: Weapon?, maxPixel: Int) -> CGImage? {
        guard let weapon, let name = weapon.imageFile, let f = files else { return nil }
        let key = "\(name)@\(maxPixel)"
        if let cached = imageCache[key] { return cached }
        let url = f.imagesURL.appendingPathComponent(name)
        guard let image = ImageTools.cgImage(fromFile: url, maxPixel: maxPixel) else { return nil }
        imageCache[key] = image
        return image
    }
    /// Decodifica in anticipo foto e loghi delle armi (alle misure che usano il banner e le schede), una alla volta:
    /// fra l'una e l'altra lo schermo può aggiornarsi. Così il banner armi non deve leggerli dal disco mentre si apre.
    func warmImages() async {
        for weapon in config.weapons where !weapon.isArchived {
            _ = logo(for: weapon, maxPixel: 96)
            await Task.yield()
            _ = logo(for: weapon, maxPixel: 102)
            await Task.yield()
            _ = image(for: weapon, maxPixel: 900)
            await Task.yield()
        }
    }

    /// Logo dell'arma (PNG con trasparenza), con cache in memoria.
    func logo(for weapon: Weapon?, maxPixel: Int) -> CGImage? {
        guard let weapon, let name = weapon.logoFile, let f = files else { return nil }
        let key = "\(name)@\(maxPixel)"
        if let cached = imageCache[key] { return cached }
        let url = f.imagesURL.appendingPathComponent(name)
        guard let image = ImageTools.cgImage(fromFile: url, maxPixel: maxPixel) else { return nil }
        imageCache[key] = image
        return image
    }

    // MARK: Errori

    private func describe(_ error: Error, path: String) -> String {
        if let e = error as? CocoaError {
            switch e.code {
            case .fileReadNoPermission, .fileWriteNoPermission:
                return "Permesso negato su \(path). Scegli di nuovo la cartella (Impostazioni ▸ Cambia cartella): l'accesso si perde se la cartella viene spostata o l'app viene reinstallata."
            case .fileReadNoSuchFile:
                return "File non trovato: \(path)"
            default:
                break
            }
        }
        return "\(error.localizedDescription) (\(path))"
    }
}
