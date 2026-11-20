//
//  ArchiveFiles.swift
//  AmmoTrack
//
//  I file dell'archivio dentro la cartella scelta (es. Documents/ARMI):
//
//    movimenti.csv   il registro
//    armi.json       calibri, limiti, armi e matricole
//    Immagini/       le foto delle armi
//    Backup/         copie di sicurezza datate
//
//  SCRITTURA ATOMICA: il nuovo contenuto va prima in un file temporaneo e poi sostituisce l'originale
//  in un solo passaggio. Se l'app si chiude o il Mac si spegne a metà, resta il file vecchio intero
//  oppure quello nuovo intero, mai uno a metà.
//
//  COPIA DI SICUREZZA: prima di ogni modifica o cancellazione (e una volta al giorno prima del primo
//  inserimento) il file attuale viene copiato in Backup/ con data e ora. Si tengono le ultime copie.
//

import Foundation

nonisolated struct FileStamp: Equatable, Sendable {
    var modified: Date?
    var size: UInt64?
}

nonisolated enum BackupMode: Sendable {
    /// Nessuna copia (file appena creato).
    case none
    /// Una copia al giorno, prima della prima scrittura (per i semplici inserimenti).
    case dailyIfNeeded
    /// Una copia a ogni scrittura (modifiche, cancellazioni, importazioni).
    case always
}

/// Il file è su iCloud Drive ma non è ancora stato scaricato su questo dispositivo.
nonisolated struct ICloudDownloadPending: LocalizedError, Sendable {
    let name: String

    var errorDescription: String? {
        "«\(name)» è su iCloud e non è ancora stato scaricato: attendi qualche istante (nel frattempo l'app non lo modifica)."
    }
}

nonisolated struct ArchiveFiles: Sendable {
    let folder: URL

    static let movementsName = "movimenti.csv"
    static let configName = "armi.json"
    static let imagesFolder = "Immagini"
    static let backupFolder = "Backup"

    var movementsURL: URL { folder.appendingPathComponent(ArchiveFiles.movementsName) }
    var configURL: URL { folder.appendingPathComponent(ArchiveFiles.configName) }
    var imagesURL: URL { folder.appendingPathComponent(ArchiveFiles.imagesFolder, isDirectory: true) }
    var backupURL: URL { folder.appendingPathComponent(ArchiveFiles.backupFolder, isDirectory: true) }

    /// Crea la cartella e le sottocartelle se mancano.
    func prepare() throws {
        let fm = FileManager.default
        for url in [folder, imagesURL, backupURL] where !fm.fileExists(atPath: url.path) {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    func stamp(of url: URL) -> FileStamp? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return FileStamp(modified: attrs[.modificationDate] as? Date,
                         size: (attrs[.size] as? NSNumber)?.uint64Value)
    }

    // MARK: Lettura

    private func readData(_ url: URL) throws -> Data? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            // iCloud Drive: un file non ancora scaricato può esserci solo come segnaposto ".nome.icloud".
            // Non è "assente": avvio il download e lo segnalo, così l'app non ne crea uno nuovo al suo posto.
            let placeholder = url.deletingLastPathComponent()
                .appendingPathComponent(".\(url.lastPathComponent).icloud")
            if fm.fileExists(atPath: placeholder.path) {
                try? fm.startDownloadingUbiquitousItem(at: url)
                throw ICloudDownloadPending(name: url.lastPathComponent)
            }
            return nil
        }
        return try Data(contentsOf: url)
    }

    /// Testo del file, o nil se il file non esiste.
    func readText(_ url: URL) throws -> String? {
        guard let data = try readData(url) else { return nil }
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    func loadMovementsText() throws -> String? {
        try readText(movementsURL)
    }

    /// nil se armi.json non esiste (o è vuoto); lancia un errore se non si riesce a interpretarlo.
    func loadConfig() throws -> Config? {
        guard let data = try readData(configURL) else { return nil }
        if data.isEmpty { return nil }
        return try JSONDecoder().decode(Config.self, from: data)
    }

    // MARK: Scrittura

    func saveMovements(text: String, backup: BackupMode) throws {
        switch backup {
        case .none:
            break
        case .always:
            try makeBackup(of: movementsURL, prefix: "movimenti", ext: "csv", keep: 60, onlyIfNoneToday: false)
        case .dailyIfNeeded:
            do {
                try makeBackup(of: movementsURL, prefix: "movimenti", ext: "csv", keep: 60, onlyIfNoneToday: true)
            } catch {
                // La copia giornaliera è "al meglio": se fallisce non blocco l'inserimento.
            }
        }
        try Data(text.utf8).write(to: movementsURL, options: .atomic)
    }

    func saveConfig(_ config: Config, backup: Bool) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(config)
        if backup {
            try makeBackup(of: configURL, prefix: "armi", ext: "json", keep: 30, onlyIfNoneToday: false)
        }
        try data.write(to: configURL, options: .atomic)
    }

    func writeImage(_ data: Data, name: String) throws {
        try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        try data.write(to: imagesURL.appendingPathComponent(name), options: .atomic)
    }

    func deleteImage(name: String) {
        try? FileManager.default.removeItem(at: imagesURL.appendingPathComponent(name))
    }

    // MARK: Copie di sicurezza

    func makeBackup(of url: URL, prefix: String, ext: String, keep: Int, onlyIfNoneToday: Bool) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        if let size = stamp(of: url)?.size, size == 0 { return }
        try fm.createDirectory(at: backupURL, withIntermediateDirectories: true)

        let all = (try? fm.contentsOfDirectory(atPath: backupURL.path)) ?? []
        let existing = all.filter { $0.hasPrefix(prefix + "-") && $0.hasSuffix("." + ext) }

        let now = Date()
        if onlyIfNoneToday {
            let today = String(compactStamp(now).prefix(8))          // "AAAAMMGG"
            if existing.contains(where: { $0.hasPrefix("\(prefix)-\(today)") }) { return }
        }

        let name = "\(prefix)-\(compactStamp(now)).\(ext)"
        let destination = backupURL.appendingPathComponent(name)
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: url, to: destination)

        // Tengo solo le ultime `keep` copie.
        let names = Array(Set(existing + [name])).sorted()
        if names.count > keep {
            for old in names.prefix(names.count - keep) {
                try? fm.removeItem(at: backupURL.appendingPathComponent(old))
            }
        }
    }
}
