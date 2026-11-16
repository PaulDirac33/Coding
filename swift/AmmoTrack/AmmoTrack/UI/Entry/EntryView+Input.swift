//
//  EntryView+Input.swift
//
//  EntryView: tastiera, registrazione del movimento, annulla.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

extension EntryView {

    // MARK: Messaggi

    func fail(_ message: String) {
        statusKind = .error
        statusText = message
    }

    func closePicker() {
        if pickerOpen {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { pickerOpen = false }
        }
    }
    /// Manda un comando da tastiera al banner armi.
    func sendPicker(_ key: PickerKey) {
        pickerCommand = PickerCommand(id: pickerCommand.id + 1, key: key)
    }

    // MARK: Cifre

    /// Cambia il testo con la piccola animazione a molla (le cifre entrano/escono).
    func setInput(_ s: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) {
            inputText = s
        }
    }

    /// Cancella l'ultima cifra.
    func deleteLast() {
        if !inputText.isEmpty { setInput(String(inputText.dropLast())) }
    }

    /// Aggiunge una cifra. Restituisce false se il carattere non è una cifra (le cartucce sono intere: niente decimali).
    func typeDigit(_ ch: Character) -> Bool {
        guard ("0"..."9").contains(ch) else { return false }
        var t = inputText
        if t == "0" { t = "" }                       // niente zeri iniziali: "05" diventa "5"
        guard t.count < maxLength else { return true }
        t.append(ch)
        setInput(t)
        return true
    }

    /// Backspace può arrivare come tasto "delete", "forward delete" o come carattere di controllo
    /// (0x7F, 0x08, 0xF728): li riconosco tutti.
    func isBackspace(_ press: KeyPress) -> Bool {
        if press.key == .delete || press.key == .deleteForward { return true }
        return press.characters.unicodeScalars.contains {
            $0.value == 0x7F || $0.value == 0x08 || $0.value == 0xF728
        }
    }

    func setProvenance(_ p: Provenance) {
        guard allowsReload else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            storedProvenance = p.rawValue
        }
    }

    // MARK: Tastiera

    func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard isActive else { return .ignored }
        // Lascio passare le scorciatoie di sistema (⌘C, ⌘Q, ...).
        if press.modifiers.contains(.command) || press.modifiers.contains(.control) { return .ignored }

        if press.key == .escape {
            if pickerOpen { closePicker() } else { setInput("") }
            return .handled
        }
        // Banner armi aperto: ↑ ↓ e invio sono del banner (li gestisce il monitor qui sotto).
        // Questa è solo una rete di sicurezza: con il banner aperto non deve mai partire uno sparo.
        if pickerOpen && (press.key == .upArrow || press.key == .downArrow || press.key == .return) {
            return .handled
        }

        // Invio non registra (le azioni sono due: ↓ e ↑): ricordo come si fa.
        if press.key == .return || press.characters == "\u{3}" {
            if canCommit && press.phase == .down {
                statusKind = .hint
                statusText = target.weaponID == nil
                    ? "Premi ↓ per aggiungere o ↑ per sparare."
                    : "Premi ↑ per sparare."
            }
            return .handled
        }

        // Frecce: ↓ aggiunte, ↑ sparate, ←/→ provenienza. Partono solo alla pressione, non se tieni premuto.
        let isArrow = press.key == .upArrow || press.key == .downArrow
            || press.key == .leftArrow || press.key == .rightArrow
        if isArrow {
            if press.phase == .down {
                if press.key == .upArrow {
                    commit(.shot)
                } else if press.key == .downArrow {
                    commit(.added)
                } else if press.key == .leftArrow {
                    setProvenance(.reloaded)
                } else {
                    setProvenance(.bought)
                }
            }
            return .handled
        }

        if isBackspace(press) {
            deleteLast()
            return .handled
        }

        var handled = false
        for ch in press.characters where typeDigit(ch) { handled = true }
        return handled ? .handled : .ignored
    }

    /// Monitor dei tasti a livello di finestra: agisce solo se questa è la pagina visibile e non stai
    /// scrivendo in un campo di testo né hai un foglio aperto. Gestisce:
    ///   ⌫ / ⌦   cancella l'ultima cifra (rete di sicurezza contro il "blip")
    ///   ⌘↓       apre il banner armi
    ///   a banner aperto: ↑ ↓ cambiano voce · ↩ sceglie · ⌘↩ assorbe/espande le armi del calibro · Esc chiude
    func installKeyMonitor() {
        #if os(macOS)
        guard keyMonitor == nil else { return }
        let gate = self.gate
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 51 = backspace, 117 = cancella in avanti, 125 = ↓, 126 = ↑, 36 = invio, 76 = invio tastierino, 53 = Esc.
            // Le frecce portano anche i flag "numericPad" e "function": tengo solo i modificatori veri.
            let code = event.keyCode
            let mods = event.modifierFlags.intersection([.command, .control, .option])
            let consumed: Bool = MainActor.assumeIsolated {
                guard gate.active else { return false }
                if NSApp.keyWindow?.firstResponder is NSTextView { return false }
                if NSApp.keyWindow?.attachedSheet != nil { return false }

                // Cancellazione
                if (code == 51 || code == 117) && mods.isEmpty {
                    deleteLast()
                    return true
                }

                // ⌘↓: apre il banner armi (a banner già aperto non fa nulla)
                if code == 125 && mods == .command {
                    if !event.isARepeat { sendPicker(.open) }
                    return true
                }

                // Da qui in poi solo a banner aperto
                guard pickerOpen else { return false }

                if mods.isEmpty {
                    switch code {
                    case 126:                       // ↑
                        sendPicker(.up)
                        return true
                    case 125:                       // ↓
                        sendPicker(.down)
                        return true
                    case 36, 76:                    // ↩
                        if !event.isARepeat { sendPicker(.confirm) }
                        return true
                    case 53:                        // Esc
                        closePicker()
                        return true
                    default:
                        return false
                    }
                }
                if mods == .command && (code == 36 || code == 76) {      // ⌘↩
                    if !event.isARepeat { sendPicker(.toggle) }
                    return true
                }
                return false
            }
            return consumed ? nil : event
        }
        #endif
    }

    func removeKeyMonitor() {
        #if os(macOS)
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
        #endif
    }

    // MARK: Registrazione

    /// Breve lampo verde del riquadro quando il valore è stato scritto nel file.
    func celebrate() {
        withAnimation(.easeOut(duration: 0.2)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.4)) { flash = false }
        }
    }
    /// Inserimento rifiutato: la casella trema e le cifre e il bordo lampeggiano di rosso.
    func reject() {
        withAnimation(.linear(duration: 0.45)) { shakes += 1 }
        withAnimation(.easeOut(duration: 0.15)) { flashError = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.4)) { flashError = false }
        }
    }

    /// Registra il numero scritto come «sparate» (.shot) o «aggiunte» (.added), con la provenienza scelta.
    /// Oggi: data e ora di adesso. Giorno passato (dal calendario): solo la data, con l'ora convenzionale.
    func commit(_ kind: MovementKind) {
        guard let q = quantity else { return }
        let t = target
        guard !t.caliberID.isEmpty else {
            fail("Nessun calibro configurato: aggiungilo dalle Impostazioni (⌘,).")
            return
        }
        if kind == .added && t.weaponID != nil {
            statusKind = .hint
            statusText = "Con un'arma scelta non si aggiungono cartucce: scegli «Senza arma» nel banner."
            return
        }

        var date = Date()
        var hasTime = true
        if let d = day, !Cal.cal.isDateInToday(d) {
            date = Cal.stamp(day: d, kind: kind)
            hasTime = false
        }

        let m = Movement(date: date,
                         hasTime: hasTime,
                         kind: kind,
                         provenance: provenance,
                         caliberID: t.caliberID,
                         quantity: q,
                         weaponID: kind == .shot ? t.weaponID : nil)
        if let error = store.add(m, allowOverdraw: false) {
            fail(error)
            reject()
            return
        }

        setInput("")
        celebrate()
        statusKind = .none
        statusText = ""
        if let w = warning(after: m) {
            statusKind = .warning
            statusText = w
        }
        inputFocused = true
    }

    /// Avvisi (non bloccanti) dopo un inserimento: saldo negativo o limite superato.
    func warning(after m: Movement) -> String? {
        var notes: [String] = []
        let name = store.config.caliberName(m.caliberID)

        if m.delta > 0 {
            let balance = store.ledger.balance(for: m.caliberID)
            if let limit = store.config.caliber(m.caliberID)?.limit, balance.total > limit {
                notes.append("\(name): \(numText(balance.total)) cartucce, oltre le \(numText(limit)) denunciate.")
            }
            let all = store.ledger.balance(for: nil)
            if let limit = store.config.totalLimit, all.total > limit {
                notes.append("Totale \(numText(all.total)) cartucce, oltre il limite di \(numText(limit)).")
            }
        }
        return notes.first
    }
}
