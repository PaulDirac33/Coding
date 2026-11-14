//
//  FolderSetupView.swift
//
//  Primo avvio con App Sandbox attiva: si sceglie una volta la cartella dei dati (es. Documents/ARMI)
//  e l'app se la ricorda. Su iOS sarà lo stesso gesto, dal selettore file di iCloud Drive.
//

import SwiftUI
import UniformTypeIdentifiers

struct FolderSetupView: View {
    @EnvironmentObject var store: DataStore

    @State private var choosing = false
    @State private var error: String? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "folder")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Palette.muted)
                Text("Scegli la cartella dei dati")
                    .font(.title2.weight(.semibold))
                Text("Qui l'app salva movimenti.csv, armi.json, le foto delle armi e i backup. Scegli la tua cartella ARMI in Documenti (se è sincronizzata con iCloud Drive, i dati lo saranno).")
                    .font(.callout)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    choosing = true
                } label: {
                    Text("Scegli la cartella…")
                        .frame(minWidth: 160)
                }
                .controlSize(.large)
                .glassProminentButton()
                ErrorLine(text: error)
            }
            .padding(30)
            .frame(width: 440)
            .liquidGlass(cornerRadius: 26)
        }
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                store.chooseFolder(url)
            case .failure(let failure):
                error = failure.localizedDescription
            }
        }
    }
}
