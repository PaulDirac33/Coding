//
//  SettingsSheet.swift
//
//  Impostazioni su iPhone e iPad: lo stesso SettingsView del Mac, in un foglio con il pulsante «Fine».
//  Si apre dal pulsante «…» in alto (RootView). Solo iOS: su Mac le Impostazioni sono la finestra ⌘, .
//

#if os(iOS)
import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SettingsView()
                .navigationTitle("Impostazioni")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fine") { dismiss() }
                    }
                }
        }
    }
}
#endif
