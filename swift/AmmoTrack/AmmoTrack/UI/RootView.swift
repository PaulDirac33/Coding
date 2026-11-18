//
//  RootView.swift
//
//  Finestra principale: il selettore di pagina in alto (Inserimento · Dati · Armi) e le tre pagine,
//  disposte in fila e fatte scorrere come "pagine" (come nell'altra app, nella direzione della bolla di vetro).
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

    let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
        .onAppear { store.start() }
        .onReceive(tick) { _ in store.refresh() }
        .onAppear { store.start() }
        .onReceive(tick) { _ in store.refresh() }
        .pageShortcuts(page: $page)      // ← NUOVA RIGA
    }

    // MARK: Barra superiore

    /// Selettore di pagina al centro (i pulsanti rosso/giallo/verde della finestra restano liberi a sinistra).
    var topBar: some View {
        HStack {
            Spacer()
            GlassSegmented(options: AppPage.allCases,
                           selection: $page,
                           segmentWidth: 128) { p, selected in
                HStack(spacing: 7) {
                    pageIcon(p, selected: selected)
                    Text(p.title)
                        .font(.system(size: 13, weight: selected ? .semibold : .medium))
                }
                .foregroundStyle(selected ? Color.white : Color.white.opacity(0.68))
            }
            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(height: 60)
    }
    /// Icona della pagina nel selettore: la Beretta per Armi, il simbolo di sistema per le altre.
    /// Altezza comune delle icone del selettore: i simboli di sistema e la Beretta sono alti uguale.
    let pageIconHeight: CGFloat = 20
    /// Di quanti punti si alzano le icone del selettore rispetto al centro della voce.
    let pageIconLift: CGFloat = 2

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
        .padding(.horizontal, 28)
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
