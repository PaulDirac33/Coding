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
                    Image(systemName: p.symbol)
                        .font(.system(size: 14, weight: .semibold))
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

    func go(_ target: AppPage) {
        page = target
    }

    /// Le tre pagine stanno in fila e scorrono insieme: nessuna si perde cambiando pagina
    /// (quel che stai scrivendo resta lì). Solo quella visibile riceve i tasti.
    var pager: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            HStack(spacing: 0) {
                EntryView(isActive: page == .entry, onManageWeapons: { go(.weapons) })
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
