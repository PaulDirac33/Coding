//
//  EntryKeypad.swift
//
//  Tastierino a schermo per iPhone e iPad: sostituisce la tastiera del Mac (cifre e cancella).
//  Due file da cinque cifre più ⌫ e C: sull'iPhone resta spazio per i saldi e i limiti sotto.
//  Le cifre passano da `typeDigit` e `deleteLast` (EntryView+Input.swift): stessa logica,
//  stessa animazione delle cifre della tastiera. I tasti ↑ ↓ e il selettore ricaricate/comprate
//  sono quelli di sempre. Con la tastiera dell'iPad si scrive come sul Mac.
//

#if os(iOS)
import SwiftUI

extension EntryView {

    /// Le cifre 1...0, ⌫ (cancella l'ultima cifra) e C (svuota, come Esc sul Mac).
    /// Larga al massimo quanto la scheda dei saldi.
    var keypad: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(["1", "2", "3", "4", "5"], id: \.self) { digit in
                    digitKey(digit)
                }
                keypadKey("Cancella l'ultima cifra", action: { deleteLast() }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
            HStack(spacing: 8) {
                ForEach(["6", "7", "8", "9", "0"], id: \.self) { digit in
                    digitKey(digit)
                }
                keypadKey("Svuota la casella", action: { setInput("") }) {
                    Text("C")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        }
        .frame(maxWidth: 390)
    }

    private func digitKey(_ digit: String) -> some View {
        keypadKey(digit, action: {
            if let ch = digit.first { _ = typeDigit(ch) }
        }) {
            Text(digit)
                .font(.system(size: 22, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.white)
        }
    }

    /// Un tasto in vetro: capsula con il contenuto al centro, che reagisce al tocco come i tasti di sistema.
    private func keypadKey<Label: View>(_ accessibility: String,
                                  action: @escaping () -> Void,
                                  @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassCapsule(interactive: true)
        .accessibilityLabel(accessibility)
    }
}
#endif
