//
//  FolderAccess.swift
//  AmmoTrack
//
//  Dove stanno i dati. La cartella (es. ~/Documents/ARMI, sincronizzata con iCloud Drive) si sceglie una volta
//  e l'app se la ricorda con un "security-scoped bookmark": funziona con App Sandbox attiva (e su iOS)
//  e con l'account Apple gratuito.
//
//  Senza App Sandbox, se non hai scelto nulla, usa direttamente ~/Documents/ARMI.
//  Con App Sandbox compare la schermata "Scegli la cartella dei dati".
//
//  È l'UNICO punto che conosce il percorso: se in futuro cambia (iOS, iCloud container...) si cambia solo qui.
//

import Foundation

nonisolated enum FolderAccess {

    private static let bookmarkKey = "dataFolderBookmark"
    private static let pathKey = "dataFolderPath"

    /// true se l'app gira nella sandbox: ~/Documents/ARMI non è raggiungibile senza il consenso dell'utente.
    static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    /// Cartella predefinita fuori dalla sandbox: ~/Documents/ARMI. Con la sandbox (o su iOS) è nil: va scelta.
    static var defaultFolder: URL? {
        #if os(macOS)
        if isSandboxed { return nil }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("ARMI", isDirectory: true)
        #else
        return nil
        #endif
    }

    private static var creationOptions: URL.BookmarkCreationOptions {
        #if os(macOS)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }

    private static var resolutionOptions: URL.BookmarkResolutionOptions {
        #if os(macOS)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }

    /// La cartella scelta in precedenza, già pronta all'uso (nil se non ce n'è).
    static func restore() -> URL? {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data,
                                  options: resolutionOptions,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale) {
                _ = url.startAccessingSecurityScopedResource()
                if stale { remember(url) }
                return url
            }
        }
        if let path = defaults.string(forKey: pathKey), FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return nil
    }

    /// Ricorda la cartella scelta (e ne tiene aperto l'accesso per tutta la vita dell'app).
    static func remember(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        let defaults = UserDefaults.standard
        if let data = try? url.bookmarkData(options: creationOptions,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil) {
            defaults.set(data, forKey: bookmarkKey)
        }
        defaults.set(url.path, forKey: pathKey)
    }
}
