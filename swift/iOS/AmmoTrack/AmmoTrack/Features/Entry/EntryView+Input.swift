//
//  EntryView+Input.swift
//
//  EntryView: tastiera di sistema, registrazione del movimento.
//
//  Le cifre arrivano dalla tastiera (DigitsInput.swift), che compare solo toccando la casella: qui si ripuliscono
//  (solo cifre, niente zeri iniziali, al massimo 6) e si registra con ↑ (sparate) o ↓ (aggiunte).
//  Dopo una registrazione la tastiera resta com'era: non compare e non scompare da sola.
//

import SwiftUI

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
    // MARK: Tastiera

    /// Ripulisce quello che arriva dalla tastiera: solo cifre, niente zeri iniziali ("05" diventa "5"),
    /// al massimo `maxLength` cifre. Se cambia qualcosa riscrive il campo.
    func sanitizeInput(_ raw: String) {
        var digits = raw.filter { $0.isASCII && $0.isWholeNumber }
        if digits.contains(where: { $0 != "0" }) {
            while digits.hasPrefix("0") { digits.removeFirst() }
        } else if !digits.isEmpty {
            digits = "0"                                   // solo zeri: ne resta uno
        }
        if digits.count > maxLength { digits = String(digits.prefix(maxLength)) }
        if digits != raw { inputText = digits }
    }

    /// Svuota la casella.
    func setInput(_ s: String) {
        inputText = s
    }

    func setProvenance(_ p: Provenance) {
        guard allowsReload else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            storedProvenance = p.rawValue
        }
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
            fail("Nessun calibro configurato: aggiungilo dalla pagina Impostazioni.")
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
