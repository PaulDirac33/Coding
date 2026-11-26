//
//  FolderAccess.swift
//
//  Dove stanno i dati. La cartella (es. iCloud Drive ▸ Documenti ▸ ARMI) si sceglie una volta dall'app File
//  e l'app se la ricorda con un "security-scoped bookmark": funziona con l'ID Apple gratuito, senza capability.
//
//  È l'UNICO punto che conosce il percorso: se in futuro cambia (iCloud container...) si cambia solo qui.
//

import Foundation

nonisolated enum FolderAccess {

    private static let bookmarkKey = "dataFolderBookmark"

    /// La cartella scelta in precedenza, già pronta all'uso (nil se non ce n'è: va scelta).
    static func restore() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                 options: [],
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        if stale { remember(url) }
        return url
    }

    /// Ricorda la cartella scelta (e ne tiene aperto l'accesso per tutta la vita dell'app).
    static func remember(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        if let data = try? url.bookmarkData(options: [],
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
    }
}
