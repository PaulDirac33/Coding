//
//  RootView.swift
//
//  Radice dell'app: la barra delle pagine IN BASSO (Inserimento · Dati · Armi · Impostazioni), a portata di pollice.
//  È la TabView di sistema: su iOS 26 è Liquid Glass vero (barra fluttuante, lente che rifrange e si trascina).
//  Ogni pagina ha dietro lo sfondo (nero con mimetica scura) e, in alto, gli avvisi di lettura/scrittura.
//

import SwiftUI
import Combine

enum AppTab: Hashable {
    case entry
    case data
    case weapons
    case settings
}

struct RootView: View {
    @EnvironmentObject var store: DataStore

    @State private var tab: AppTab = .entry

    let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $tab) {
            Tab("Inserimento", systemImage: "square.and.pencil", value: AppTab.entry) {
                page { EntryView(isActive: tab == .entry) }
            }
            Tab("Dati", systemImage: "chart.xyaxis.line", value: AppTab.data) {
                page { DataView() }
            }
            Tab(value: AppTab.weapons) {
                page { WeaponsView() }
            } label: {
                Label {
                    Text("Armi")
                } icon: {
                    Image(uiImage: AppIcons.beretta())          // la tua Beretta, come icona della pagina
                }
            }
            Tab("Impostazioni", systemImage: "gearshape", value: AppTab.settings) {
                page {
                    NavigationStack {
                        SettingsView()
                            .navigationTitle("Impostazioni")
                    }
                }
            }
        }
        .tint(Palette.militaryGreenLight)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: needsFolder) {
            FolderSetupView()
        }
        .onAppear { store.start() }
        .onReceive(tick) { _ in store.refresh() }
        .task { @MainActor in
            // A schermata già visibile: si preparano le icone pesanti e le foto delle armi (vedi IconCache.swift),
            // così il banner armi non deve farlo mentre si apre.
            store.start()
            await Prewarm.run()
            await store.warmImages()
        }
    }

    /// true finché non c'è una cartella dei dati: compare la schermata di scelta, a tutto schermo.
    private var needsFolder: Binding<Bool> {
        Binding(get: { store.needsFolder }, set: { _ in })
    }

    /// Una pagina: sfondo, avvisi in alto, contenuto.
    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            banner
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AppBackground() }
    }

    /// Problemi di lettura/scrittura (rosso) o avvisi (arancione): visibili in tutte le pagine.
    @ViewBuilder
    private var banner: some View {
        if let m = store.message {
            bannerText(m, color: Palette.danger)
        } else if let n = store.notice {
            bannerText(n, color: Palette.warning)
        }
    }

    private func bannerText(_ text: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
