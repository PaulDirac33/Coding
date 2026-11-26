//
//  WeaponEditor.swift
//
//  Foglio per creare o modificare un'arma: nome, calibro, matricola, note, foto.
//  Il calibro è incorporato nell'arma e non si cambia se ci sono già movimenti (per un kit di conversione
//  crea un'arma separata). Un'arma con movimenti non si elimina: si archivia.
//

import SwiftUI
import UniformTypeIdentifiers

struct WeaponEditor: View {
    @EnvironmentObject var store: DataStore
    let onClose: () -> Void
    private func dismiss() { onClose() }

    let original: Weapon?
    private let weaponID: String

    @State private var name: String
    @State private var caliberID: String
    @State private var qualification: WeaponQualification?
    @State private var serial: String
    @State private var notes: String
    @State private var newImage: Data? = nil
    @State private var removeImage = false
    @State private var newLogo: Data? = nil
    @State private var removeLogo = false
    @State private var pickingLogo = false      // il selettore di file è unico: questo dice se sceglie foto o logo
    @State private var choosingImage = false
    @State private var error: String? = nil
    @State private var confirmDelete = false

    init(original: Weapon?, onClose: @escaping () -> Void) {
        self.original = original
        self.onClose = onClose
        self.weaponID = original?.id ?? UUID().uuidString
        _name = State(initialValue: original?.name ?? "")
        _caliberID = State(initialValue: original?.caliberID ?? "")
        _qualification = State(initialValue: original?.qualification)
        _serial = State(initialValue: original?.serial ?? "")
        _notes = State(initialValue: original?.notes ?? "")
    }

    private var movementCount: Int {
        original == nil ? 0 : store.movementCount(forWeapon: weaponID)
    }

    private var hasImage: Bool {
        if newImage != nil { return true }
        if removeImage { return false }
        return original?.imageFile != nil
    }
    private var hasLogo: Bool {
        if newLogo != nil { return true }
        if removeLogo { return false }
        return original?.logoFile != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(original == nil ? "Nuova arma" : "Modifica arma")
                .font(.headline)
                .padding(.top, 18)

            Form {
                Section {
                    Color.clear
                        .aspectRatio(16.0 / 10.0, contentMode: .fit)
                        .overlay {
                            WeaponImage(weapon: original, data: newImage, removed: removeImage, maxPixel: 700)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    HStack {
                        Button(hasImage ? "Cambia foto…" : "Scegli foto…") {
                            pickingLogo = false
                            choosingImage = true }
                        if hasImage {
                            Button("Rimuovi foto") {
                                newImage = nil
                                removeImage = true
                            }
                        }
                    }
                }
                Section("Logo (compare nel banner di Inserimento)") {
                    WeaponLogo(weapon: original, data: newLogo, removed: removeLogo)
                        .frame(height: 90)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
                    HStack {
                        Button(hasLogo ? "Cambia logo…" : "Scegli logo…") {
                            pickingLogo = true
                            choosingImage = true
                        }
                        if hasLogo {
                            Button("Rimuovi logo") {
                                newLogo = nil
                                removeLogo = true
                            }
                        }
                    }
                }

                Section {
                    TextField("Nome (es. Glock 34)", text: $name)
                    Picker("Calibro", selection: $caliberID) {
                        ForEach(store.config.calibers) { c in
                            Text(c.name).tag(c.id)
                        }
                    }
                    .disabled(movementCount > 0)
                    if movementCount > 0 {
                        Text("Il calibro non si cambia: ci sono già \(movementCount) movimenti con quest'arma. Per un kit di conversione crea un'altra arma.")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                    }
                    Picker("Qualifica", selection: $qualification) {
                        Text("Non indicata").tag(WeaponQualification?.none)
                        ForEach(WeaponQualification.allCases) { q in
                            Text(q.label).tag(WeaponQualification?.some(q))
                        }
                    }
                    TextField("Matricola", text: $serial)
                        .font(.body.monospacedDigit())
                    TextField("Note", text: $notes, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .formStyle(.grouped)
            .buttonStyle(.borderless)        // nelle righe di un Form ogni pulsante deve avere il suo tocco

            ErrorLine(text: error)
                .padding(.horizontal, 20)

            HStack {
                if let w = original {
                    Button(w.isArchived ? "Ripristina" : "Archivia") { toggleArchived(w) }
                        .glassButton()
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
        .onAppear {
            if caliberID.isEmpty { caliberID = store.config.calibers.first?.id ?? "" }
        }
        .fileImporter(isPresented: $choosingImage, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                if pickingLogo {
                    if let png = ImagePicking.png(from: url) {
                        newLogo = png
                        removeLogo = false
                        error = nil
                    } else {
                        error = "Non riesco a leggere quell'immagine."
                    }
                } else if let jpeg = ImagePicking.jpeg(from: url) {
                    newImage = jpeg
                    removeImage = false
                    error = nil
                } else {
                    error = "Non riesco a leggere quell'immagine."
                }
            case .failure(let failure):
                error = failure.localizedDescription
            }
        }
        .confirmationDialog("Eliminare quest'arma?",
                            isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Elimina", role: .destructive) { remove() }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Si elimina solo se non ha movimenti nel registro; altrimenti archiviala.")
        }
    }

    // MARK: Azioni

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            error = "Dai un nome all'arma."
            return
        }
        guard !caliberID.isEmpty else {
            error = "Scegli il calibro (aggiungilo dalle Impostazioni se manca)."
            return
        }
        var w = original ?? Weapon(id: weaponID, name: trimmedName, caliberID: caliberID)
        w.name = trimmedName
        w.caliberID = caliberID
        w.qualification = qualification
        w.serial = serial.trimmingCharacters(in: .whitespacesAndNewlines)
        w.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let failure = store.saveWeapon(w, newImage: newImage, removeImage: removeImage,
                                          newLogo: newLogo, removeLogo: removeLogo) {
            error = failure
        } else {
            dismiss()
        }
    }

    private func toggleArchived(_ w: Weapon) {
        if let failure = store.setArchived(w.id, !w.isArchived) {
            error = failure
        } else {
            dismiss()
        }
    }

    private func remove() {
        if let failure = store.deleteWeapon(weaponID) {
            error = failure
        } else {
            dismiss()
        }
    }
}
