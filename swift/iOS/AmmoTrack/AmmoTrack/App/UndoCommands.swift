//
//  UndoCommands.swift
//
//  Menu Modifica del Mac: Annulla / Ripeti (⌘Z, ⇧⌘Z).
//  Solo macOS. Su iPhone e iPad Annulla e Ripeti stanno nel pulsante «…» in alto (RootView),
//  e con la tastiera dell'iPad valgono gli stessi ⌘Z e ⇧⌘Z.
//

#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Menu Modifica: Annulla / Ripeti

struct UndoCommands: Commands {
    @ObservedObject var store: DataStore

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(store.undoName.map { "Annulla \($0)" } ?? "Annulla") {
                perform(redo: false)
            }
            .keyboardShortcut("z", modifiers: .command)

            Button(store.redoName.map { "Ripeti \($0)" } ?? "Ripeti") {
                perform(redo: true)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
    }

    private func perform(redo: Bool) {
        let window = NSApp.keyWindow

        // Si sta scrivendo in un campo di testo (Impostazioni, editor): ⌘Z annulla la digitazione.
        if let responder = window?.firstResponder, responder is NSText {
            if let um = responder.undoManager {
                if redo {
                    if um.canRedo { um.redo() }
                } else {
                    if um.canUndo { um.undo() }
                }
            }
            return
        }
        // Foglio aperto (editor, importazione, pannelli file): non tocco i dati dietro.
        if window?.sheetParent != nil { return }

        if redo { _ = store.redo() } else { _ = store.undo() }
    }
}
#endif
