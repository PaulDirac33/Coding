//
//  RootView.swift
//
//  Finestra principale: il selettore di pagina in alto (Inserimento · Dati · Armi) e le tre pagine,
//  disposte in fila e fatte scorrere come "pagine" (come nell'altra app, nella direzione della bolla di vetro).
//
//  Su iPhone e iPad, accanto al selettore, c'è il pulsante «…» con Annulla, Ripeti e Impostazioni
//  (su Mac stanno nel menu Modifica e in Impostazioni ⌘,).
//

import SwiftUI
import Combine

enum AppPage: String, CaseIterable, Identifiable {
    case entry
    case data
    case weapons

    var id: String { rawValue }

    var index: Int { AppPage.allCases.firstIndex(of: self) ?? 0 }

    var title: String {
        switch self {
        case .entry: return "Inserimento"
        case .data: return "Dati"
        case .weapons: return "Armi"
        }
    }

    /// Simboli SF Symbols: se vuoi cambiarli, è qui.
    var symbol: String {
        switch self {
        case .entry: return "square.and.pencil"
        case .data: return "chart.xyaxis.line"
        case .weapons: return "scope"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: DataStore

    @State private var page: AppPage = .entry
    /// Larghezza della finestra (misurata): sotto i 600 pt è un iPhone in verticale e la barra in alto si restringe.
    @State private var rootWidth: CGFloat = 1180
    #if os(iOS)
    @State private var showSettings = false
    #endif

    let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// iPhone in verticale. Su Mac la finestra è sempre più larga (minimo 940 pt).
    private var isCompact: Bool { rootWidth < Adaptive.phoneWidth }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            banner
            pager
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .preferredColorScheme(.dark)
        .overlay {
            if store.needsFolder {
                FolderSetupView()
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rootWidth = $0 }
        .onAppear { store.start() }
        .onReceive(tick) { _ in store.refresh() }
        .pageShortcuts(page: $page)
        #if os(iOS)
        .background { undoShortcuts }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        #endif
    }

    // MARK: Barra superiore

    @ViewBuilder
    var topBar: some View {
        if isCompact {
            compactTopBar
        } else {
            wideTopBar
        }
    }

    /// Selettore di pagina al centro (i pulsanti rosso/giallo/verde della finestra restano liberi a sinistra).
    /// Su iPad il pulsante «…» sta a destra.
    var wideTopBar: some View {
        HStack {
            Spacer()
            pageSelector(segmentWidth: 128)
            Spacer()
        }
        #if os(iOS)
        .overlay(alignment: .trailing) {
            moreMenu
                .padding(.trailing, 24)
        }
        #endif
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(height: 60)
    }

    /// iPhone: selettore e pulsante «…» sulla stessa riga; le tre voci si dividono la larghezza che resta.
    var compactTopBar: some View {
        let segment = max(60, ((rootWidth - 32 - 36 - 8 - 6) / 3).rounded(.down))
        return HStack(spacing: 8) {
            pageSelector(segmentWidth: segment)
            #if os(iOS)
            moreMenu
            #endif
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(height: 48)
    }

    func pageSelector(segmentWidth: CGFloat) -> some View {
        GlassSegmented(options: AppPage.allCases,
                       selection: $page,
                       segmentWidth: segmentWidth) { p, selected in
            HStack(spacing: isCompact ? 5 : 7) {
                pageIcon(p, selected: selected)
                Text(p.title)
                    .font(.system(size: isCompact ? 12 : 13, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.68))
        }
    }

    /// Altezza comune delle icone del selettore: i simboli di sistema e la Beretta sono alti uguale.
    var pageIconHeight: CGFloat { isCompact ? 16 : 20 }
    /// Di quanti punti si alzano le icone del selettore rispetto al centro della voce.
    var pageIconLift: CGFloat { isCompact ? 1.5 : 2 }

    /// Icona della pagina nel selettore: la Beretta per Armi, il simbolo di sistema per le altre.
    @ViewBuilder
    func pageIcon(_ p: AppPage, selected: Bool) -> some View {
        if p == .weapons {
            beretta(selected: selected)
        } else {
            Image(systemName: p.symbol)
                .font(.system(size: pageIconHeight, weight: .semibold))
                .offset(y: -pageIconLift)          // solo i simboli di sistema: la Beretta è già più alta
        }
    }

    /// La Beretta già disegnata (bianca), attenuata come il testo quando la voce non è selezionata.
    @ViewBuilder
    private func beretta(selected: Bool) -> some View {
        let h = pageIconHeight
        if let bitmap = BerettaBitmap.image(height: h, tint: .white) {
            Image(decorative: bitmap, scale: 3)
                .resizable()
                .interpolation(.high)
                .frame(width: h * BerettaIcon.aspectRatio, height: h)
                .opacity(selected ? 1 : 0.68)
        } else {
            BerettaIcon(height: h)                  // ripiego: vettoriale
        }
    }

    #if os(iOS)
    /// Pulsante «…»: Annulla, Ripeti e Impostazioni. Su Mac stanno nel menu Modifica e in Impostazioni (⌘,).
    var moreMenu: some View {
        Menu {
            Button(store.undoName.map { "Annulla \($0)" } ?? "Annulla") {
                _ = store.undo()
            }
            .disabled(store.undoName == nil)

            Button(store.redoName.map { "Ripeti \($0)" } ?? "Ripeti") {
                _ = store.redo()
            }
            .disabled(store.redoName == nil)

            Divider()

            Button {
                showSettings = true
            } label: {
                Label("Impostazioni…", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
                .glassCapsule(interactive: true)
        }
        .menuIndicator(.hidden)
        .accessibilityLabel("Annulla, Ripeti e Impostazioni")
    }

    /// ⌘Z e ⇧⌘Z con la tastiera dell'iPad (come nel menu Modifica del Mac).
    /// Nei campi di testo vale l'annulla del testo, che ha la precedenza.
    var undoShortcuts: some View {
        Group {
            Button("") { _ = store.undo() }
                .keyboardShortcut("z", modifiers: .command)
            Button("") { _ = store.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
    #endif

    /// Problemi di lettura/scrittura (rosso) o avvisi (arancione): visibili in tutte le pagine.
    @ViewBuilder
    var banner: some View {
        if let m = store.message {
            bannerText(m, color: Palette.danger)
        } else if let n = store.notice {
            bannerText(n, color: Palette.warning)
        }
    }

    func bannerText(_ text: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(color)
        .padding(.horizontal, isCompact ? 16 : 28)
        .padding(.bottom, 6)
    }

    // MARK: Pagine

    /// Le tre pagine stanno in fila e scorrono insieme: nessuna si perde cambiando pagina
    /// (quel che stai scrivendo resta lì). Solo quella visibile riceve i tasti.
    var pager: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            HStack(spacing: 0) {
                EntryView(isActive: page == .entry)
                    .frame(width: w, height: h)
                    .allowsHitTesting(page == .entry)
                DataView()
                    .frame(width: w, height: h)
                    .allowsHitTesting(page == .data)
                WeaponsView()
                    .frame(width: w, height: h)
                    .allowsHitTesting(page == .weapons)
            }
            .offset(x: -CGFloat(page.index) * w)
            .animation(.spring(response: 0.48, dampingFraction: 0.90), value: page)
        }
        .clipped()
    }
}
