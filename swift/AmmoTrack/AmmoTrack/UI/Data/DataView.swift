//
//  DataView.swift
//
//  Pagina "Dati": il registro (come il foglio Numbers, ma con i saldi calcolati) e i grafici.
//  I filtri (calibro, periodo) valgono per entrambi; l'esportazione CSV segue il filtro attivo.
//

import SwiftUI
import UniformTypeIdentifiers
/// Che cosa apre il foglio di modifica: un movimento esistente o uno nuovo (movement == nil).
struct EditorTarget: Identifiable {
    let id = UUID()
    let movement: Movement?
}

struct DataView: View {
    @EnvironmentObject var store: DataStore
    /// true quando questa è la pagina visibile: solo allora ascolta i tasti.
    let isActive: Bool
    enum Mode: String, CaseIterable, Identifiable {
        case registry
        case charts

        var id: String { rawValue }
        var symbol: String { self == .registry ? "tablecells" : "chart.bar.xaxis.ascending" }
        var title: String { self == .registry ? "Registro" : "Grafici" }
    }

    @State var mode: Mode = .registry
    @State var caliberFilter: CaliberFilter = .all
    @State var period: Period = .all
    @State var weaponFilter: String? = nil
    @State var editing: EditorTarget? = nil
    @State var showImport = false
    @State var exporting = false
    @State var exportDocument = CSVDocument(text: "")
    @State var actionError: String? = nil
    @State var selection: String? = nil        // riga selezionata nel registro (clic o frecce)
    @State var showWeaponMenu = false          // menù di vetro del filtro armi
    @State var weaponButtonFrame: CGRect = .zero   // dove sta il pulsante (da lì si apre il menù)
    @State var showActionsMenu = false              // menù di vetro delle azioni (nuovo, importa, esporta)
    @State var actionsButtonFrame: CGRect = .zero   // dove sta il suo pulsante

    // MARK: Filtri

    var caliberOptions: [CaliberFilter] {
        [CaliberFilter.all] + store.config.calibers.map { CaliberFilter.caliber($0.id) }
    }

    /// Se il calibro filtrato non esiste più, vale "tutti".
    var effectiveFilter: CaliberFilter {
        if case .caliber(let id) = caliberFilter, store.config.caliber(id) == nil { return .all }
        return caliberFilter
    }

    func filterTitle(_ f: CaliberFilter) -> String {
        switch f {
        case .all: return "Tutti"
        case .caliber(let id): return store.config.caliberName(id)
        }
    }

    var weaponFilterName: String {
        guard let id = weaponFilter else { return "Tutte le armi" }
        return store.config.weapon(id)?.name ?? "Arma eliminata"
    }

    /// Righe del registro dopo i filtri, dalla più recente.
    var filteredRows: [LedgerRow] {
        let since = period.start()
        let cid = effectiveFilter.caliberID
        let selected = store.ledger.rows.filter { r in
            if let cid, r.movement.caliberID != cid { return false }
            if let w = weaponFilter, r.movement.weaponID != w { return false }
            if let since, r.movement.date < since { return false }
            return true
        }
        return Array(selected.reversed())
    }

    // MARK: Corpo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .zIndex(10)
            ErrorLine(text: actionError)
            content
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .coordinateSpace(.named("dataPage"))
        .overlay { editorOverlay }
        .overlay { weaponMenuOverlay }
        .overlay { actionsMenuOverlay }
        .sheet(isPresented: $showImport) {
            ImportChooserSheet()
        }
        .fileExporter(isPresented: $exporting,
                      document: exportDocument,
                      contentType: .commaSeparatedText,
                      defaultFilename: "AmmoTrack \(isoDay(Date()))") { result in
            if case .failure(let failure) = result {
                actionError = failure.localizedDescription
            }
        }
        // I tasti della pagina si fermano mentre l'editor o il menù delle armi sono aperti.
        .dataShortcuts(isActive: isActive && editing == nil && !showWeaponMenu) { handleKey($0) }
        .onChange(of: isActive) { _, active in
            if !active { showWeaponMenu = false
                showActionsMenu = false}
        }
    }

    // MARK: Intestazione

    var header: some View {
        HStack(spacing: 14) {
            GlassSegmented(options: Mode.allCases,
                           selection: $mode.animation(Self.slide),
                           segmentWidth: 56) { m, selected in
                Image(systemName: m.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? Color.white : Color.white.opacity(0.68))
                    .accessibilityLabel(m.title)
            }

            GlassSegmented(options: caliberOptions,
                           selection: $caliberFilter.animation(Self.slide),
                           segmentWidth: 74) { f, selected in
                glassLabel(filterTitle(f), selected: selected)
            }

            GlassSegmented(options: Period.allCases,
                           selection: $period.animation(Self.slide),
                           segmentWidth: 66) { p, selected in
                glassLabel(p.rawValue, selected: selected)
            }

            if mode == .registry {
                weaponMenu
                actionsMenu
                Text("#\(numText(filteredRows.count))")
                                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                                    .foregroundStyle(Palette.muted)
            }

            Spacer(minLength: 8)
        }
        .frame(height: 40)
    }
    /// Filtro per arma (solo nel registro). Il menù di vetro è in DataView+Glass.swift.
    var weaponMenu: some View {
        Button {
            withAnimation(Self.slide) { showWeaponMenu.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(weaponFilterName)
                    .lineLimit(1)
            }
            .font(.system(size: 13, weight: weaponFilter == nil ? .medium : .semibold))
            .foregroundStyle(weaponFilter == nil ? Color.white.opacity(0.68) : Color.white)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .glassCapsule(interactive: true)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("dataPage")) } action: { weaponButtonFrame = $0 }
    }

/// Menù delle azioni (solo nel registro): nuovo movimento, importa, esporta. Il pannello è in DataView+Glass.swift.
var actionsMenu: some View {
    Button {
        withAnimation(Self.slide) { showActionsMenu.toggle() }
    } label: {
        Image(systemName: "ellipsis")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: 36, height: 36)
            .glassCapsule(interactive: true)
            .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .fixedSize()
    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("dataPage")) } action: { actionsButtonFrame = $0 }
    .glassHint("Azioni")
}

    // MARK: Contenuto

    var content: some View {
        ZStack {
            if mode == .registry {
                RegistryView(rows: filteredRows,
                             onEdit: { editing = EditorTarget(movement: $0) },
                             onDelete: { delete($0) },
                             onImport: { showImport = true },
                             selection: $selection)
                    .transition(.opacity)
            } else {
                ChartsView(filter: effectiveFilter, period: period)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.2), value: mode)
    }

    // MARK: Azioni

    func delete(_ m: Movement) {
        if let error = store.delete(ids: [m.id]) {
            actionError = error
        } else {
            actionError = nil
        }
    }

    /// Esporta in CSV (in ordine cronologico, con i saldi) esattamente quello che si vede.
    func exportCurrent() {
        let chronological = Array(filteredRows.reversed())
        exportDocument = CSVDocument(text: MovementCSV.exportCSV(rows: chronological, config: store.config))
        exporting = true
    }
}
