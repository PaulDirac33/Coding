//
//  MovementEditor.swift
//
//  Foglio per creare o modificare un movimento (data, ora facoltativa, tipo, provenienza, calibro,
//  quantità, arma, nota) e per eliminarlo. Prima di ogni modifica o cancellazione il registro
//  viene copiato in Backup/.
//

import SwiftUI

struct MovementEditor: View {
    @EnvironmentObject var store: DataStore

    let onClose: () -> Void
    private func dismiss() { onClose() }

    let original: Movement?

    @State private var kind: MovementKind
    @State private var provenance: Provenance
    @State private var caliberID: String
    @State private var day: Date
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var quantityText: String
    @State private var weaponID: String
    @State private var note: String
    @State private var error: String? = nil
    @State private var confirmDelete = false

    init(original: Movement?, onClose: @escaping () -> Void) {
        self.original = original
        self.onClose = onClose
        let m = original
        _kind = State(initialValue: m?.kind ?? .shot)
        _provenance = State(initialValue: m?.provenance ?? .reloaded)
        _caliberID = State(initialValue: m?.caliberID ?? "")
        _day = State(initialValue: Cal.startOfDay(m?.date ?? Date()))
        _hasTime = State(initialValue: m?.hasTime ?? false)
        _time = State(initialValue: m?.date ?? Date())
        _quantityText = State(initialValue: m.map { String($0.quantity) } ?? "")
        _weaponID = State(initialValue: m?.weaponID ?? "")
        _note = State(initialValue: m?.note ?? "")
    }

    private var allowsReload: Bool {
        store.config.caliber(caliberID)?.allowsReload ?? true
    }

    private var weaponsForCaliber: [Weapon] {
        store.config.weapons.filter { $0.caliberID == caliberID && (!$0.isArchived || $0.id == weaponID) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(original == nil ? "Nuovo movimento" : "Modifica movimento")
                .font(.headline)
                .padding(.top, 18)

            Form {
                Picker("Tipo", selection: $kind) {
                    ForEach(MovementKind.allCases) { k in
                        Text(k.label).tag(k)
                    }
                }

                Picker("Calibro", selection: $caliberID) {
                    ForEach(store.config.calibers) { c in
                        Text(c.name).tag(c.id)
                    }
                }

                if allowsReload {
                    Picker("Provenienza", selection: $provenance) {
                        ForEach(Provenance.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                }

                DatePicker("Data", selection: $day, displayedComponents: .date)

                Toggle("Specifica l'ora", isOn: $hasTime)
                if hasTime {
                    DatePicker("Ora", selection: $time, displayedComponents: .hourAndMinute)
                }

                TextField(kind == .adjustment ? "Quantità (+ o −)" : "Quantità", text: $quantityText)

                if kind == .shot {
                    Picker("Arma", selection: $weaponID) {
                        Text("Nessuna").tag("")
                        ForEach(weaponsForCaliber) { w in
                            Text(w.name).tag(w.id)
                        }
                    }
                }

                TextField("Nota", text: $note)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
                        .fixedSize(horizontal: false, vertical: true)

            ErrorLine(text: error)
                .padding(.horizontal, 20)

            HStack {
                if original != nil {
                    Button("Elimina…", role: .destructive) { confirmDelete = true }
                        .glassButton()
                }
                Spacer()
                Button("Annulla") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .glassButton()
                Button("Salva") { save() }
                    .keyboardShortcut(.defaultAction)
                    .glassProminentButton()
            }
            .padding(20)
        }
        .frame(width: 460)
        .onAppear {
            if caliberID.isEmpty { caliberID = store.config.calibers.first?.id ?? "" }
        }
        .onChange(of: caliberID) {
            if !allowsReload { provenance = .bought }
            if !weaponID.isEmpty, !weaponsForCaliber.contains(where: { $0.id == weaponID }) { weaponID = "" }
        }
        .confirmationDialog("Eliminare questo movimento?",
                            isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Elimina", role: .destructive) { remove() }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Resta una copia di sicurezza del registro in Backup/.")
        }
    }

    // MARK: Azioni

    private func save() {
        guard !caliberID.isEmpty else {
            error = "Scegli un calibro."
            return
        }
        guard let q = NumberParsing.int(quantityText) else {
            error = "Scrivi la quantità come numero intero."
            return
        }
        if kind == .adjustment {
            guard q != 0 else {
                error = "Una rettifica non può essere zero."
                return
            }
        } else {
            guard q > 0 else {
                error = "La quantità deve essere maggiore di zero."
                return
            }
        }

        let dayStart = Cal.cal.startOfDay(for: day)
        let date: Date
        if hasTime {
            let c = Cal.cal.dateComponents([.hour, .minute], from: time)
            date = Cal.at(dayStart, hour: c.hour ?? 0, minute: c.minute ?? 0, second: 0)
        } else {
            date = Cal.stamp(day: dayStart, kind: kind)
        }

        let m = Movement(id: original?.id ?? UUID().uuidString,
                         date: date,
                         hasTime: hasTime,
                         kind: kind,
                         provenance: allowsReload ? provenance : .bought,
                         caliberID: caliberID,
                         quantity: q,
                         weaponID: (kind == .shot && !weaponID.isEmpty) ? weaponID : nil,
                         note: note.trimmingCharacters(in: .whitespaces))

        let failure: String?
        if original == nil {
            failure = store.add(m)
        } else {
            failure = store.update(m)
        }
        if let failure {
            error = failure
        } else {
            dismiss()
        }
    }

    private func remove() {
        guard let id = original?.id else { return }
        if let failure = store.delete(ids: [id]) {
            error = failure
        } else {
            dismiss()
        }
    }
}
