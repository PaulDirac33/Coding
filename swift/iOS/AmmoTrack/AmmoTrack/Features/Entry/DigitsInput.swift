//
//  DigitsInput.swift
//
//  La tastiera della pagina Inserimento. Dietro la casella dell'importo c'è un campo di testo UIKit invisibile
//  che porta la tastiera numerica di sistema: compare SOLO toccando la casella, e non ha nessuna barra sopra.
//  Anche con la tastiera fisica dell'iPad le cifre arrivano da qui.
//

import SwiftUI
import UIKit

struct DigitsInputField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.delegate = context.coordinator
        field.keyboardType = .numberPad
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.autocapitalizationType = .none
        field.textColor = .clear
        field.tintColor = .clear
        field.backgroundColor = .clear
        // Niente barra sopra la tastiera (su iPad è quella con annulla, ripeti e incolla).
        field.inputAssistantItem.leadingBarButtonGroups = []
        field.inputAssistantItem.trailingBarButtonGroups = []
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        if isFocused && !field.isFirstResponder {
            context.coordinator.requestFocus(field)
        } else if !isFocused && field.isFirstResponder {
            DispatchQueue.main.async { _ = field.resignFirstResponder() }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DigitsInputField

        init(_ parent: DigitsInputField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        /// La tastiera esce a richiesta. Se per qualche motivo non esce, lo stato torna a «chiusa».
        func requestFocus(_ field: UITextField) {
            DispatchQueue.main.async { [weak self, weak field] in
                guard let self, let field else { return }
                if !field.becomeFirstResponder() { self.parent.isFocused = false }
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async { [weak self] in self?.parent.isFocused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            DispatchQueue.main.async { [weak self] in self?.parent.isFocused = false }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}
