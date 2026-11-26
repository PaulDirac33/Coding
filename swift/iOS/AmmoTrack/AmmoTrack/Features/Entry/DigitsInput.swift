//
//  DigitsInput.swift
//
//  La tastiera della pagina Inserimento. Dietro la casella dell'importo c'è un campo di testo UIKit invisibile
//  che porta la tastiera: compare SOLO toccando la casella, e non ha nessuna barra sopra.
//
//  Con `entryKeyboardStyle = .custom` (AppearanceSettings.swift) la tastiera è quella dell'app, un vero
//  «input view»: compare e scompare come una tastiera di sistema, copre la barra delle pagine e non ha
//  caselle vuote:
//
//        1  2  3
//        4  5  6
//        7  8  9
//        0    ⌫
//
//  Con `.system` è la tastiera numerica di sistema (con la casella vuota in basso a sinistra).
//  Anche con la tastiera fisica dell'iPad le cifre arrivano da qui.
//

import SwiftUI
import UIKit

struct DigitsInputField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let style: EntryKeyboardStyle

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
        if style == .custom {
            field.inputView = context.coordinator.makeKeypad()
        }
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

        func makeKeypad() -> UIView {
            KeypadInputView(onDigit: { [weak self] digit in self?.append(digit) },
                            onDelete: { [weak self] in self?.deleteLast() })
        }

        private func append(_ digit: String) {
            parent.text += digit
        }

        private func deleteLast() {
            parent.text = String(parent.text.dropLast())
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

// MARK: - La tastiera dell'app

/// L'input view: porta dentro le cifre disegnate in SwiftUI (vetro vero).
final class KeypadInputView: UIInputView, UIInputViewAudioFeedback {
    private var hosting: UIHostingController<KeypadKeys>?

    init(onDigit: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        super.init(frame: CGRect(x: 0, y: 0, width: 390, height: KeypadKeys.height), inputViewStyle: .keyboard)
        allowsSelfSizing = true

        let host = UIHostingController(rootView: KeypadKeys(onDigit: onDigit, onDelete: onDelete))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host.view)

        let height = heightAnchor.constraint(equalToConstant: KeypadKeys.height)
        height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            height
        ])
        hosting = host
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) non implementato")
    }

    /// Con «Clic della tastiera» attivo nelle impostazioni del dispositivo, i tasti fanno il clic di sistema.
    var enableInputClicksWhenVisible: Bool { true }
}

/// I tasti: cifre da 1 a 9, poi lo zero largo due caselle e il cancella subito alla sua destra.
struct KeypadKeys: View {
    static let height: CGFloat = 258

    let onDigit: (String) -> Void
    let onDelete: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    digit("1")
                    digit("2")
                    digit("3")
                }
                GridRow {
                    digit("4")
                    digit("5")
                    digit("6")
                }
                GridRow {
                    digit("7")
                    digit("8")
                    digit("9")
                }
                GridRow {
                    digit("0")
                        .gridCellColumns(2)
                    deleteKey
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
        }
        .frame(maxWidth: 380)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }

    private func digit(_ d: String) -> some View {
        key {
            Text(d)
                .font(.system(size: 26, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white)
        } action: {
            onDigit(d)
        }
    }

    private var deleteKey: some View {
        key {
            Image(systemName: "delete.left")
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(Color.white)
        } action: {
            onDelete()
        }
        .accessibilityLabel("Cancella")
    }

    /// Un tasto di vetro, che reagisce al tocco.
    private func key<Label: View>(@ViewBuilder label: () -> Label, action: @escaping () -> Void) -> some View {
        Button {
            UIDevice.current.playInputClick()
            action()
        } label: {
            label()
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
}
