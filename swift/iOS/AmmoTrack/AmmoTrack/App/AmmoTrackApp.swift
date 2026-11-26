//
//  AmmoTrackApp.swift
//  AmmoTrack
//
//  Registro delle cartucce per iPhone e iPad: inserimento veloce con la tastiera numerica, registro con i saldi,
//  grafici, armi. Solo framework di sistema: SwiftUI + Swift Charts. Richiede iOS / iPadOS 26 (Liquid Glass).
//
//  I dati stanno in una cartella (di norma iCloud Drive ▸ Documenti ▸ ARMI, la stessa dell'app per Mac),
//  scelta una volta dall'app File:
//    movimenti.csv   il registro (una riga per movimento; i saldi si ricalcolano)
//    armi.json       calibri, limiti, armi e matricole
//    Immagini/       le foto delle armi
//    Backup/         copie di sicurezza automatiche
//
//  NOTA: il codice è suddiviso in cartelle: vedi LEGGIMI.md per la mappa.
//

import SwiftUI

@main
struct AmmoTrackApp: App {
    @StateObject private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
