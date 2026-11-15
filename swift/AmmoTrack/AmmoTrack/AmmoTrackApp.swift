//
//  AmmoTrackApp.swift
//  AmmoTrack
//
//  Registro delle cartucce per macOS: inserimento veloce da tastiera, registro con i saldi, grafici, armi.
//  Solo framework di sistema: SwiftUI + Swift Charts. Richiede macOS 14 o successivo.
//  Con macOS 26 (Tahoe) e Xcode 26 usa il Liquid Glass; sui sistemi precedenti ripiega su materiali traslucidi.
//
//  I dati stanno in una cartella (di norma ~/Documents/ARMI, sincronizzata con iCloud Drive):
//    movimenti.csv   il registro (una riga per movimento; i saldi si ricalcolano)
//    armi.json       calibri, limiti, armi e matricole
//    Immagini/       le foto delle armi
//    Backup/         copie di sicurezza automatiche
//
//  NOTA: il codice è suddiviso in più file: vedi README.md per la mappa.
//

import SwiftUI

// MARK: - App

@main
struct AmmoTrackApp: App {
    @StateObject private var store = DataStore()

    var body: some Scene {
        WindowGroup("AmmoTrack") {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 940, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)      // lo sfondo arriva fino al bordo alto, senza barra staccata
        .defaultSize(width: 1180, height: 780)

        #if os(macOS)
        // Impostazioni (⌘,): cartella dei dati, limiti, calibri, importazione.
        Settings {
            SettingsView()
                .environmentObject(store)
        }
        #endif
    }
}
