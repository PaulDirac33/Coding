//
//  AmmoTrackApp.swift
//  AmmoTrack
//
//  Registro delle cartucce per macOS, iPadOS e iOS: inserimento veloce, registro con i saldi, grafici, armi.
//  Solo framework di sistema: SwiftUI + Swift Charts. Richiede macOS 14 o iOS/iPadOS 17 (o successivi).
//  Con Xcode 26 e il sistema 26 usa il Liquid Glass; sui sistemi precedenti ripiega su materiali traslucidi.
//
//  I dati stanno in una cartella (di norma ~/Documents/ARMI, sincronizzata con iCloud Drive;
//  su iPhone e iPad la stessa cartella, scelta una volta dall'app File):
//    movimenti.csv   il registro (una riga per movimento; i saldi si ricalcolano)
//    armi.json       calibri, limiti, armi e matricole
//    Immagini/       le foto delle armi
//    Backup/         copie di sicurezza automatiche
//
//  NOTA: il codice è suddiviso in cartelle: vedi LEGGIMI.md per la mappa.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - App

@main
struct AmmoTrackApp: App {
    @StateObject private var store = DataStore()

    var body: some Scene {
        WindowGroup("AmmoTrack") {
            RootView()
                .environmentObject(store)
                #if os(macOS)
                .frame(minWidth: 940, minHeight: 600)
                #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)      // lo sfondo arriva fino al bordo alto, senza barra staccata
        .defaultSize(width: 1180, height: 780)
        .commands { UndoCommands(store: store) }
        #endif

        #if os(macOS)
        // Impostazioni (⌘,): cartella dei dati, limiti, calibri, importazione.
        // Su iPhone e iPad si aprono dal pulsante «…» in alto (vedi RootView e SettingsSheet).
        Settings {
            SettingsView()
                .environmentObject(store)
        }
        #endif
    }
}
