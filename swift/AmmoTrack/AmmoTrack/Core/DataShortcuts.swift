
//  Created by  Riccardo on 11/21/26.

//  DataShortcuts.swift
//
//  Tastiera della pagina Dati:
//    ↑ ↓         scorrono i movimenti del registro
//    ↩           modifica il movimento selezionato
//    ← →         Registro / Grafici
//    ⌥← ⌥→       calibro (Tutti · 9×21 · 22 LR …)
//    ⌥⇧← ⌥⇧→     periodo (3 mesi · 6 mesi · 1 anno · Tutto)
//
//  Monitor locale dei tasti, come PageShortcuts e quello di EntryView:
//  - agisce solo se questa è la pagina visibile e il tasto arriva alla finestra principale;
//  - se c'è un foglio aperto (editor, importazione, pannelli file) o stai scrivendo in un campo di testo,
//    lascia passare il tasto;
//  - i modificatori devono essere esattamente quelli indicati (⌘← ⌘→ restano del cambio pagina);
//  - tenendo premuto si ripetono solo ↑ ↓; gli altri tasti fanno un passo per pressione.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// I tasti che la pagina Dati ascolta.
nonisolated enum DataKey {
    case up, down                       // ↑ ↓
    case enter                          // ↩
    case left, right                    // ← →
    case caliberLeft, caliberRight      // ⌥← ⌥→
    case periodLeft, periodRight        // ⌥⇧← ⌥⇧→

    var repeats: Bool { self == .up || self == .down }
}

extension View {
    /// Collega i tasti della pagina Dati. `perform` restituisce true se il tasto è stato usato.
    @ViewBuilder
    func dataShortcuts(isActive: Bool, perform: @escaping @MainActor (DataKey) -> Bool) -> some View {
        #if os(macOS)
        modifier(DataShortcuts(isActive: isActive, perform: perform))
        #else
        self
        #endif
    }
}

#if os(macOS)

/// Ricorda in quale finestra sta DataView e se è la pagina visibile (il monitor non vede lo stato della vista).
@MainActor
final class DataShortcutGate {
    weak var window: NSWindow?
    var active = false
}

struct DataShortcuts: ViewModifier {
    let isActive: Bool
    let perform: @MainActor (DataKey) -> Bool

    @State private var monitor: Any? = nil
    @State private var gate = DataShortcutGate()

    func body(content: Content) -> some View {
        let gate = self.gate
        return content
            .background(WindowReader { gate.window = $0 })
            .onAppear {
                gate.active = isActive
                install()
            }
            .onDisappear { remove() }
            .onChange(of: isActive) { _, active in gate.active = active }
    }

    /// 123 = ←, 124 = →, 125 = ↓, 126 = ↑, 36 = invio, 76 = invio del tastierino.
    private nonisolated static func key(code: UInt16, mods: NSEvent.ModifierFlags) -> DataKey? {
        if mods.isEmpty {
            switch code {
            case 126: return .up
            case 125: return .down
            case 123: return .left
            case 124: return .right
            case 36, 76: return .enter
            default: return nil
            }
        }
        if mods == .option {
            switch code {
            case 123: return .caliberLeft
            case 124: return .caliberRight
            default: return nil
            }
        }
        if mods == [.option, .shift] {
            switch code {
            case 123: return .periodLeft
            case 124: return .periodRight
            default: return nil
            }
        }
        return nil
    }

    private func install() {
        guard monitor == nil else { return }
        let gate = self.gate
        let perform = self.perform
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Le frecce portano anche i flag "numericPad" e "function": tengo solo i quattro modificatori veri.
            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard let key = DataShortcuts.key(code: event.keyCode, mods: mods) else { return event }

            let consumed: Bool = MainActor.assumeIsolated {
                guard gate.active,
                      let window = event.window, window === gate.window,
                      window.attachedSheet == nil,
                      !(window.firstResponder is NSText) else { return false }
                if event.isARepeat && !key.repeats { return true }
                return perform(key)
            }
            return consumed ? nil : event
        }
    }

    private func remove() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}

#endif

// MARK: - Azioni (stato e filtri di DataView)

extension DataView {

    /// Stessa molla del pager: la lente dei selettori scorre insieme ai cambi.
    static let slide = Animation.spring(response: 0.48, dampingFraction: 0.90)

    /// true = il tasto è stato usato (e non arriva ad altri).
    func handleKey(_ key: DataKey) -> Bool {
        switch key {
        case .up:           return moveSelection(-1)
        case .down:         return moveSelection(1)
        case .enter:        return editSelected()
        case .left:         stepMode(-1)
        case .right:        stepMode(1)
        case .caliberLeft:  stepCaliber(-1)
        case .caliberRight: stepCaliber(1)
        case .periodLeft:   stepPeriod(-1)
        case .periodRight:  stepPeriod(1)
        }
        return true
    }

    /// ↑ ↓: solo nel Registro. Senza una riga selezionata (o se i filtri l'hanno fatta sparire) parte dalla più recente.
    private func moveSelection(_ delta: Int) -> Bool {
        guard mode == .registry else { return false }
        let rows = filteredRows
        guard !rows.isEmpty else { return false }
        let next: Int
        if let current = rows.firstIndex(where: { $0.id == selection }) {
            next = min(max(current + delta, 0), rows.count - 1)
        } else {
            next = 0
        }
        selection = rows[next].id
        return true
    }

    /// ↩: apre la modifica della riga selezionata. Senza selezione non fa nulla.
    private func editSelected() -> Bool {
        guard mode == .registry,
              let id = selection,
              let row = filteredRows.first(where: { $0.id == id }) else { return false }
        editing = EditorTarget(movement: row.movement)
        return true
    }

    /// ← →: Registro / Grafici. Agli estremi resta dov'è.
    private func stepMode(_ delta: Int) {
        let all = Mode.allCases
        guard let i = all.firstIndex(of: mode), all.indices.contains(i + delta) else { return }
        withAnimation(Self.slide) { mode = all[i + delta] }
    }

    /// ⌥← ⌥→: Tutti, poi i calibri nell'ordine delle Impostazioni.
    private func stepCaliber(_ delta: Int) {
        let options = caliberOptions
        guard let i = options.firstIndex(of: effectiveFilter), options.indices.contains(i + delta) else { return }
        withAnimation(Self.slide) { caliberFilter = options[i + delta] }
    }

    /// ⌥⇧← ⌥⇧→: 3 mesi, 6 mesi, 1 anno, Tutto.
    private func stepPeriod(_ delta: Int) {
        let all = Period.allCases
        guard let i = all.firstIndex(of: period), all.indices.contains(i + delta) else { return }
        withAnimation(Self.slide) { period = all[i + delta] }
    }
}
