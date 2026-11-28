//
//  WeaponPicker.swift
//
//  Tasto di vetro con l'arma scelta (il calibro è quello dell'arma). Toccandolo il tasto «si allunga» e diventa
//  un banner di vetro con le armi preimpostate, raggruppate per calibro: come il menù del filtro armi nella
//  pagina Dati, ma con righe fatte a mano (loghi, cartucce, bolla di selezione, bollicine).
//
//  COME SI APRE (e perché prima scattava)
//  La trasformazione del vetro fatta in SwiftUI (GlassEffectContainer + glassEffectID) ricalcola il vetro a ogni
//  fotogramma, nel processo dell'app: sul telefono scattava anche in Release. Il menù di sistema è fluido perché
//  lo anima il sistema. Qui si fa lo stesso con Core Animation:
//   - il banner (WeaponPickerPanel) è una vista SwiftUI già a misura piena, dentro una finestra UIKit trasparente
//     (PickerPresenter, in fondo al file);
//   - l'apertura è l'animazione di una cornice UIKit che passa dal tasto al banner (con gli angoli che si
//     arrotondano) e lo scopre dall'alto: il lavoro lo fa il render server, non SwiftUI;
//   - le righe sfumano un attimo dopo, a banner quasi aperto; in chiusura sfumano prima e la cornice torna sul tasto;
//   - nessuna freccia e nessun ridimensionamento di sistema: le armi nascoste si assorbono con la solita molla SwiftUI.
//  Il tasto sparisce mentre il banner lo copre (stessa posizione) e riappare alla chiusura.
//  Ripiego: `weaponPickerUsesOverlay = false` in AppearanceSettings.swift usa il popover di sistema.
//
//  LA SCELTA
//  Nel banner la scelta è una bolla di vetro vero che scorre in verticale come la lente di GlassSegmented: premi e
//  trascini, rilasci sulla voce che vuoi. Passando su una voce c'è una vibrazione leggera, come nei menù.
//  Se le voci non entrano nel banner la lista NON si scorre col dito (si perderebbe la scelta): tieni la bolla sul
//  bordo in basso (o in alto) e la lista scorre una voce alla volta; la vibrazione scandisce i passi.
//  Le armi si aggiungono dalla pagina Armi.
//
//  Se un calibro non ha ancora armi compare la voce "Senza arma": serve anche per le entrate
//  (acquisti e ricariche non hanno un'arma) e per lo storico importato.
//

import SwiftUI
import Combine
import UIKit

/// Separatore fra calibro e matricola. Il trattino «–» (en dash) è un unico segno, come il "--" di LaTeX.
/// Alternative: " • " oppure " - ".
private let pickerSeparator = "  •  "

// MARK: - Stato condiviso

/// Stato condiviso fra il tasto, la presentazione UIKit e il banner.
@MainActor
final class PickerReveal: ObservableObject {
    /// true = le righe si vedono (da poco dopo l'inizio dell'apertura fino all'inizio della chiusura).
    @Published var rowsVisible = false
    /// true = il banner copre il tasto: il tasto sparisce, per non vedere due vetri sovrapposti.
    @Published var coversButton = false
    /// Altezza attuale del banner. La scrive il banner, la leggono l'apertura e la chiusura.
    /// Non è pubblicata: cambia di continuo e non serve ridisegnare niente.
    var panelHeight: CGFloat = 0 {
        didSet {
            if panelHeight != oldValue { onPanelHeight?(panelHeight) }
        }
    }
    /// La presentazione UIKit si fa avvisare quando l'altezza cambia, per adeguare il vetro.
    var onPanelHeight: ((CGFloat) -> Void)? = nil
    /// true = in cima al banner si vede la scritta del tasto (sfuma via all'apertura, torna alla chiusura).
    @Published var labelVisible = true
    /// Altezza del tasto all'apertura o alla chiusura: serve a posare la scritta in cima al banner.
    var sourceHeight: CGFloat = 52
}

// MARK: - Tasto

struct WeaponPicker: View {
    @EnvironmentObject var store: DataStore

    @Binding var target: EntryTarget
    @Binding var isOpen: Bool
    var maxPanelHeight: CGFloat = 360     // la decide EntryView: dal tasto fino al fondo della pagina

    @StateObject private var reveal = PickerReveal()

    private let compactHeight: CGFloat = 44             // altezza del tasto quando c'è solo il calibro
    private let compactCartridgeLength: CGFloat = 64    // lunghezza della cartuccia orizzontale (in punti)

    var body: some View {
        if weaponPickerUsesOverlay {
            overlayVersion
        } else {
            popoverVersion
        }
    }

    // MARK: Le due versioni

    /// Il tasto «si allunga» nel banner. La presentazione è `PickerPresenter` (UIKit), agganciata al tasto.
    private var overlayVersion: some View {
        pickerButton
            .glassCapsule()                      // NON interactive: il banner lo sostituisce subito
            // Il tasto sparisce e riappare di colpo: il vetro a opacità intermedia si appiattisce (grigio).
            .opacity(reveal.coversButton ? 0 : 1)
            .background {
                PickerPresenter(isPresented: $isOpen,
                                reveal: reveal,
                                panelWidth: EntryLayout.controlWidth,
                                maxHeight: maxPanelHeight,
                                panel: panel(drawsGlass: true))
            }
            // Vibrazione: leggera all'apertura, di selezione a ogni scelta (come i menù di sistema).
            .sensoryFeedback(.impact(flexibility: .soft), trigger: isOpen) { _, opened in opened }
            .sensoryFeedback(.selection, trigger: target)
            // Cambiando arma il tasto cambia misura subito, non con la molla di choose():
            // altrimenti il banner si richiude su una cornice ancora in movimento.
            .animation(nil, value: target)
    }

    /// Ripiego: popover di sistema (con la freccia). `drawsGlass: false` perché il vetro lo mette il popover.
    private var popoverVersion: some View {
        pickerButton
            .glassCapsule()
            .popover(isPresented: $isOpen, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                panel(drawsGlass: false)
                    .presentationCompactAdaptation(.popover)
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: isOpen) { _, opened in opened }
            .sensoryFeedback(.selection, trigger: target)
    }

    /// Il banner, con tutto quello che serve a una finestra a sé: l'ambiente (lo store) e il tema scuro
    /// non passano da soli a una vista presentata da UIKit.
    private func panel(drawsGlass: Bool) -> some View {
        WeaponPickerPanel(reveal: reveal,
                          target: $target,
                          isOpen: $isOpen,
                          maxPanelHeight: maxPanelHeight,
                          drawsGlass: drawsGlass,
                          closedLabel: AnyView(labelContent))
            .environmentObject(store)
            .preferredColorScheme(.dark)
    }

    // MARK: Aspetto del tasto

    private var currentWeapon: Weapon? { store.config.weapon(target.weaponID) }
    /// Solo il calibro, nessuna arma: il tasto si riduce.
    private var isCaliberOnly: Bool {
        currentWeapon == nil && !target.caliberID.isEmpty
    }

    private var cartridgeStyle: CartridgeStyle {
        store.config.caliber(target.caliberID)?.cartridgeStyle ?? .pistol
    }

    /// Con un'arma: il suo nome. Senza arma: il nome esteso del calibro.
    private var titleText: String {
        if target.caliberID.isEmpty { return "Nessun calibro" }
        if let w = currentWeapon { return w.name.isEmpty ? "Senza nome" : w.name }
        return store.config.caliberLongName(target.caliberID)
    }

    /// Con un'arma: calibro e matricola. Senza arma: "Senza arma".
    private var subtitleText: String {
        guard !target.caliberID.isEmpty else { return "Aggiungi un calibro dalle Impostazioni" }
        guard let w = currentWeapon else { return "Senza arma" }
        var parts = [store.config.caliberName(target.caliberID)]
        if !w.serial.isEmpty { parts.append(w.serial) }
        return parts.joined(separator: pickerSeparator)
    }

    /// La scritta del tasto: la usa anche il banner, in cima, mentre si apre e si chiude.
    @ViewBuilder
    private var labelContent: some View {
        if isCaliberOnly {
            compactLabel
        } else {
            fullLabel
        }
    }

    private var pickerButton: some View {
        Button {
            isOpen = true
        } label: {
            labelContent
        }
        .buttonStyle(.plain)
    }
    /// Con un'arma: miniatura, nome e calibro/matricola sulla seconda riga. Nessuna larghezza fissa:
    /// il tasto si stringe attorno al contenuto, come nel caso del solo calibro.
    private var fullLabel: some View {
        HStack(spacing: 10) {
            WeaponThumb(weapon: currentWeapon, caliberID: target.caliberID, size: 32)
            VStack(alignment: .center, spacing: 1) {
                Text(titleText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                    .offset(y: 2)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(Capsule())
    }

    /// Solo il calibro: cartuccia orizzontale grande + nome. Nessuna larghezza fissa, quindi il tasto
    /// si stringe attorno al contenuto (e resta centrato, perché lo slot in EntryView centra il tasto).
    private var compactLabel: some View {
        HStack(spacing: 14) {
            CartridgeImage(style: cartridgeStyle, height: compactCartridgeLength, horizontal: true)
            Text(titleText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 18)
        .frame(height: compactHeight)
        .contentShape(Capsule())
    }

}

// MARK: - Banner

/// Il banner: righe, bolla di selezione, bollicine. È una vista a sé (con il suo stato) perché vive in una
/// finestra UIKit separata (vedi PickerPresenter): tutto quello che serve arriva dai parametri.
struct WeaponPickerPanel: View {
    @EnvironmentObject var store: DataStore
    @ObservedObject var reveal: PickerReveal
    @Binding var target: EntryTarget
    @Binding var isOpen: Bool
    var maxPanelHeight: CGFloat = 360     // la decide EntryView: dal tasto fino al fondo della pagina
    /// true = il banner disegna il proprio vetro (presentazione UIKit); false = lo disegna chi lo contiene (popover).
    var drawsGlass = true
    /// La scritta del tasto (la costruisce WeaponPicker): in cima al banner, sfuma via all'apertura e torna alla chiusura.
    var closedLabel = AnyView(EmptyView())

    private let panelWidth: CGFloat = EntryLayout.controlWidth

    /// Spazio di coordinate in cui le righe dicono dove stanno (serve alla bolla).
    private let rowsSpace = "pickerRows"
    /// Margine sopra e sotto le righe dentro l'area visibile: lascia posto alla bolla premuta, che sporge di 3 pt.
    private let scrollPad: CGFloat = 4
    /// Altezza riservata ai pallini "ci sono altre voci" in alto o in basso.
    private let moreStrip: CGFloat = 18

    /// Animazione di assorbimento e comparsa delle armi: la stessa per righe e altezza del banner.
    private static var absorbAnimation: Animation {
        .spring(response: 0.42, dampingFraction: 0.86)
    }

    /// Come entrano ed escono le righe delle armi: sfumano in fretta e si restringono verso la riga del calibro.
    private static var absorbTransition: AnyTransition {
        AnyTransition.opacity.animation(.easeOut(duration: 0.18))
            .combined(with: .scale(scale: 0.92, anchor: .top))
    }

    /// Scorrimento a bordo: dopo quanti secondi che la bolla è sul bordo parte il primo passo…
    private static let scrollDwell: Double = 0.22
    /// …e ogni quanti secondi si fa un passo (una voce) finché resta lì.
    private static let scrollInterval: Double = 0.30

    /// Posizione di ogni riga, raccolta dalle righe stesse.
    @State private var rowFrames: [String: CGRect] = [:]
    /// Altezza che le righe avrebbero senza ritaglio (misurata quando il banner è aperto).
    @State private var rowsHeight: CGFloat = 0
    /// Calibri con le armi assorbite (id separati da virgola). Si ricorda anche fra un avvio e l'altro.
    @AppStorage("picker.collapsedCalibers") private var collapsedRaw = ""
    /// Posizione delle bolle piccole (una per calibro che ha armi), raccolta dalle righe.
    @State private var toggleFrames: [String: CGRect] = [:]
    /// Quante voci sono scorse fuori dall'alto del banner (0 = la lista è all'inizio). Vedi `stepScroll`.
    @State private var topIndex = 0
    /// Altezza del puntatore mentre premi o trascini (nil = a riposo).
    /// Si azzera con una molla poco smorzata: è il rimbalzo, come in GlassSegmented.
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.36, dampingFraction: 0.65)))
    private var drag: CGFloat? = nil
    /// Calibro la cui bolla piccola è premuta in questo momento (nil = nessuna).
    @GestureState private var pressedToggle: String? = nil

    /// Posizione del dito nello spazio delle righe all'ultimo evento del tocco, e `contentTop` di quel momento:
    /// servono a seguire il dito quando la lista scorre sotto di lui (il dito fermo non manda eventi).
    @State private var pointerRowsY: CGFloat? = nil
    @State private var touchContentTop: CGFloat = 0
    /// Voce sotto il dito: a ogni cambio c'è una vibrazione (nil = nessun tocco).
    @State private var hoverKey: String? = nil
    /// Si incrementa a ogni passo di scorrimento: serve alla vibrazione.
    @State private var scrollTick = 0
    /// Si incrementa a ogni tocco sulle bolle piccole (assorbi/espandi le armi): serve alla vibrazione.
    @State private var toggleTick = 0
    /// Il ciclo che scorre la lista mentre la bolla è sul bordo (esiste solo durante il tocco).
    @State private var autoScroll: Task<Void, Never>? = nil

    var body: some View {
        // Le righe si vedono un attimo dopo l'inizio dell'apertura e spariscono per prime alla chiusura:
        // lo decide PickerPresenter con `reveal.rowsVisible`.
        let content = panelContent
            .opacity(reveal.rowsVisible ? 1 : 0)
            .animation(.easeOut(duration: reveal.rowsVisible ? 0.22 : 0.12), value: reveal.rowsVisible)
            .allowsHitTesting(reveal.rowsVisible)
        return Group {
            if drawsGlass {
                content
                    .animation(Self.absorbAnimation, value: collapsedRaw)
                    // L'altezza del vetro serve alla presentazione (apertura e chiusura) e ai tocchi.
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { reveal.panelHeight = $0 }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .overlay(alignment: .top) { closedLabelView }
            } else {
                content
                    .onAppear { reveal.rowsVisible = true }
            }
        }
        .ignoresSafeArea()
        .onChange(of: collapsedRaw) { topIndex = 0 }          // assorbendo o espandendo la lista torna all'inizio
        .onDisappear { stopAutoScroll() }
    }
    private var closedLabelView: some View {
        closedLabel
            .frame(width: 320, height: reveal.sourceHeight)           // 320 = larghezza dello slot in EntryView
            .opacity(reveal.labelVisible ? 1 : 0)
            .animation(.easeOut(duration: reveal.labelVisible ? 0.22 : 0.15), value: reveal.labelVisible)
            .allowsHitTesting(false)
    }

    // MARK: Misure

    private var rowCount: Int {
        store.config.calibers.reduce(0) { total, cal in
            total + store.config.activeWeapons(for: cal.id).count + 1   // +1 = "Senza arma"
        }
    }

    private var roomForRows: CGFloat { max(120, maxPanelHeight - 20) }
    private var fullEstimate: CGFloat {
        CGFloat(rowCount) * 50 + CGFloat(store.config.calibers.count) * 24
    }
    /// true = le righe non entrano nel banner: servono ritaglio o scorrimento.
    private var isLimited: Bool { fullEstimate > roomForRows }
    /// Altezza dell'area visibile quando le righe non entrano.
    private var viewportHeight: CGFloat {
        min(roomForRows, (rowsHeight > 0 ? rowsHeight : fullEstimate) + scrollPad * 2)
    }
    /// Altezza che il banner mostra davvero. Se in basso c'è una voce nascosta, il banner finisce subito
    /// sotto l'ultima voce visibile (più la fascia dei pallini). Altrimenti è l'altezza piena.
    private var shownHeight: CGFloat {
        let v = visibility
        guard v.below else { return viewportHeight }
        let lastBottom = rowFrames
            .filter { !v.hidden.contains($0.key) }
            .values.map { $0.maxY }.max()
        guard let lastBottom else { return viewportHeight }
        // 3 pt = quanto sporge la bolla premuta sull'ultima voce.
        return min(viewportHeight, lastBottom + contentTop + 3 + moreStrip)
    }
    /// Zona occupata da una riga: per la riga di un calibro include la sua intestazione, che sta sopra.
    private func rowSpan(_ key: String, _ r: CGRect) -> (minY: CGFloat, maxY: CGFloat) {
        (key.hasSuffix("|") ? r.minY - 16 : r.minY, r.maxY)
    }

    /// Di quanto salgono tutte le voci per chiudere lo spazio fra i pallini in alto e la prima voce visibile.
    /// È 0 se in alto non ci sono voci nascoste.
    private var topShift: CGFloat {
        let v = visibility
        guard v.above else { return 0 }
        let firstTop = rowFrames
            .filter { !v.hidden.contains($0.key) }
            .map { rowSpan($0.key, $0.value).minY }
            .min()
        guard let firstTop else { return 0 }
        // La prima voce deve stare a 3 pt (margine della bolla) + la fascia dei pallini dal bordo alto.
        return max(0, firstTop + contentTop - (3 + moreStrip))
    }


    // MARK: Contenuto

    /// Quanto è scorsa la lista: la prima voce visibile è la numero `topIndex`, e va a posarsi subito sotto i pallini.
    /// Si scorre a voci intere, non a pixel: così le voci che escono dall'alto "si assorbono" con la stessa animazione
    /// di quelle nascoste dal bordo in basso.
    private var scrollOffset: CGFloat {
        guard topIndex > 0 else { return 0 }
        let spans = orderedSpans
        guard spans.count > 1 else { return 0 }
        let k = min(topIndex, spans.count - 1)
        return max(0, spans[k].minY + scrollPad - 3 - moreStrip)
    }

    /// Posizione in alto delle righe rispetto all'area visibile del banner (cambia quando la lista scorre).
    private var contentTop: CGFloat { scrollPad - scrollOffset }

    /// Le righe in ordine dall'alto in basso, ognuna con la zona che occupa (per un calibro, intestazione compresa).
    private var orderedSpans: [(key: String, minY: CGFloat, maxY: CGFloat)] {
        rowFrames
            .map { (k, r) in
                let s = rowSpan(k, r)
                return (key: k, minY: s.minY, maxY: s.maxY)
            }
            .sorted { $0.minY < $1.minY }
    }

    private var panelContent: some View {
        let shift = topShift
        return Group {
            if isLimited {
                // Le voci non entrano: l'area visibile ritaglia le righe, che non si scorrono col dito
                // (il tocco serve alla scelta) ma a voci intere con `stepScroll`.
                rows
                    .padding(.horizontal, 10)
                    .padding(.vertical, scrollPad)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: -scrollOffset)                             // la lista scorsa
                    .frame(height: viewportHeight, alignment: .top)       // altezza piena dell'area visibile
                    .offset(y: -shift)                                    // le voci salgono
                    .frame(height: max(shownHeight - shift, 0), alignment: .top)   // il banner si accorcia dal basso
                    .clipped()
                    .animation(Self.absorbAnimation, value: visibility.hidden)
            } else {
                rows
                    .padding(.horizontal, 10)
            }
        }
        .overlay(alignment: .top) { moreDots(visibility.above, top: true) }
        .overlay(alignment: .bottom) { moreDots(visibility.below, top: false) }
        .padding(.vertical, 10)
        .frame(width: panelWidth)
    }

    /// Tre bollicine: dicono che sopra o sotto ci sono altre voci (scorri, o alza la finestra).
    private func moreDots(_ shown: Bool, top: Bool) -> some View {
        ZStack {
            if shown {
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { _ in
                        AbsorbGlass().frame(width: 8, height: 8)
                    }
                }
                .frame(height: moreStrip)
                .transition(.opacity.combined(with: .offset(y: top ? -10 : 10)))
            }
        }
        .animation(Self.absorbAnimation, value: shown)
        .allowsHitTesting(false)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(store.config.calibers) { cal in
                caliberSection(cal)
            }
        }
        .animation(Self.absorbAnimation, value: collapsedRaw)
        .coordinateSpace(.named(rowsSpace))
        .onPreferenceChange(RowFramesKey.self) { if rowFrames != $0 { rowFrames = $0 } }
        .onPreferenceChange(ToggleFramesKey.self) { if toggleFrames != $0 { toggleFrames = $0 } }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowsHeight = $0 }
        .background(alignment: .topLeading) { lens }
        .contentShape(Rectangle())
        .gesture(pickGesture)
        // Vibrazione leggera quando la bolla passa da una voce all'altra (non alla prima pressione), come nei menù…
        .sensoryFeedback(.selection, trigger: hoverKey) { old, new in old != nil && new != nil }
        // …e a ogni passo dello scorrimento a bordo.
        .sensoryFeedback(.selection, trigger: scrollTick)
        // …e quando tocchi una bolla piccola (assorbe o mostra le armi).
        .sensoryFeedback(.impact(flexibility: .soft), trigger: toggleTick)
    }

    @ViewBuilder
    private func caliberSection(_ cal: Caliber) -> some View {
        let all = store.config.activeWeapons(for: cal.id)
        let isAbsorbed = absorbed.contains(cal.id)
        let shown = isAbsorbed ? all.filter { $0.id == target.weaponID } : all
        let hidden = all.count - shown.count
        let balance = store.ledger.balance(for: cal.id)
        let unseen = visibility.hidden
        let caliberKey = key(EntryTarget(caliberID: cal.id, weaponID: nil))

        HStack(spacing: 6) {
            Text(cal.name.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.muted)
            if hidden > 0 {
                Text("· \(hidden) \(hidden == 1 ? "arma nascosta" : "armi nascoste")")
                    .font(.caption2)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)    // una sola riga, mai a capo
            }
            Spacer()
            Text("\(numText(balance.total)) cartucce")
                .font(.caption2)
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .opacity(unseen.contains(caliberKey) ? 0 : 1)
        .animation(.easeOut(duration: 0.15), value: unseen.contains(caliberKey))

        PickerRow(rowKey: caliberKey,
                  space: rowsSpace,
                  weapon: nil,
                  title: cal.displayName,
                  subtitle: "Senza arma",
                  cartridge: cal.cartridgeStyle,
                  toggleID: all.isEmpty ? nil : cal.id,
                  absorbed: isAbsorbed,
                  togglePressed: pressedToggle == cal.id,
                  faded: unseen.contains(caliberKey))
        ForEach(shown) { w in
            PickerRow(rowKey: key(EntryTarget(caliberID: cal.id, weaponID: w.id)),
                      space: rowsSpace,
                      weapon: w,
                      title: w.name,
                      subtitle: w.serial.isEmpty ? cal.name : "\(cal.name)\(pickerSeparator)\(w.serial)",
                      faded: unseen.contains(key(EntryTarget(caliberID: cal.id, weaponID: w.id))))
                .transition(Self.absorbTransition)
        }
    }

    // MARK: Armi assorbite (bolla piccola dei calibri)

    private var absorbed: Set<String> {
        Set(collapsedRaw.split(separator: ",").map(String.init))
    }

    private func toggleAbsorbed(_ id: String) {
        var set = absorbed
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        toggleTick += 1
        withAnimation(Self.absorbAnimation) {
            collapsedRaw = set.sorted().joined(separator: ",")
        }
    }

    /// Calibro la cui bolla piccola contiene il punto (area un po' più larga della bolla).
    private func toggleHit(_ p: CGPoint) -> String? {
        let hidden = visibility.hidden
        return toggleFrames.first {
            !hidden.contains("\($0.key)|")
                && $0.value.insetBy(dx: -AbsorbBubble.hitSlop, dy: -AbsorbBubble.hitSlop).contains(p)
        }?.key
    }
    /// Sceglie una voce: la bolla si assesta, poi il banner si richiude (più lentamente).
       private func choose(_ t: EntryTarget) {
           let changed = t != target
           if changed {
               withAnimation(.spring(response: 0.36, dampingFraction: 0.65)) { target = t }
           }
           DispatchQueue.main.asyncAfter(deadline: .now() + (changed ? 0.30 : 0)) {
               // La chiusura (le righe sfumano, poi il banner si richiude sul tasto) la fa PickerPresenter quando isOpen diventa false.
               isOpen = false
           }
       }

    // MARK: Bolla e selezione

    private func key(_ t: EntryTarget) -> String {
        "\(t.caliberID)|\(t.weaponID ?? "")"
    }

    /// La voce su cui sta la bolla: quella scelta.
    private var selectedKey: String { key(target) }

    /// Tutte le scelte possibili, per chiave.
    private var targets: [String: EntryTarget] {
        var map: [String: EntryTarget] = [:]
        for cal in store.config.calibers {
            let c = EntryTarget(caliberID: cal.id, weaponID: nil)
            map[key(c)] = c
            for w in store.config.activeWeapons(for: cal.id) {
                let t = EntryTarget(caliberID: cal.id, weaponID: w.id)
                map[key(t)] = t
            }
        }
        return map
    }

    /// Premi = la bolla corre dal puntatore; trascini = lo segue; rilasci = sceglie la riga sotto il puntatore.
    /// Tenendo la bolla sul bordo in basso o in alto la lista scorre (vedi `startAutoScroll`).
    private var pickGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(rowsSpace))
            .updating($drag) { g, state, transaction in
                // Pressione iniziata sulla bolla piccola: la bolla grande non si muove.
                guard toggleHit(g.startLocation) == nil else { return }
                // Al primo tocco la bolla raggiunge il punto con una molla, poi segue senza ritardo.
                transaction.animation = (state == nil)
                ? Animation.spring(response: 0.28, dampingFraction: 0.7) : nil
                state = g.location.y
            }
            .updating($pressedToggle) { g, state, _ in
                state = toggleHit(g.startLocation)
            }
            .onChanged { g in
                guard toggleHit(g.startLocation) == nil else { return }
                pointerRowsY = g.location.y
                touchContentTop = contentTop
                let k = nearestKey(toY: g.location.y)
                if k != hoverKey { hoverKey = k }
                startAutoScroll()
            }
            .onEnded { g in
                // Il dito può essere fermo mentre la lista scorre: la posizione vera si ricava da qui.
                let y = currentPointerY() ?? g.location.y
                stopAutoScroll()
                hoverKey = nil
                pointerRowsY = nil
                if let id = toggleHit(g.startLocation) {
                    // Inizia e finisce sulla stessa bolla piccola: assorbe o espande. Selezione e banner restano com'erano.
                    if toggleHit(g.location) == id { toggleAbsorbed(id) }
                } else {
                    finish(at: CGPoint(x: g.location.x, y: y))
                }
            }
    }

    /// La riga più vicina all'altezza data (fra quelle visibili per intero).
    private func nearestKey(toY y: CGFloat) -> String? {
        selectableFrames.min(by: { abs($0.value.midY - y) < abs($1.value.midY - y) })?.key
    }

    private func finish(at point: CGPoint) {
        // Sceglie la riga più vicina al punto di rilascio: è quella su cui la bolla si è già fermata,
        // anche se rilasci fra due righe o su un'intestazione di calibro.
        guard let hit = nearestKey(toY: point.y), let t = targets[hit] else { return }
        choose(t)
    }

    // MARK: Scorrimento a bordo

    /// Dove sta il dito adesso, nello spazio delle righe (tiene conto di quanto la lista è scorsa dall'ultimo evento).
    private func currentPointerY() -> CGFloat? {
        guard let y = pointerRowsY else { return nil }
        return y + touchContentTop - contentTop
    }

    /// -1 = il dito è sopra la prima voce visibile e sopra c'è altro; +1 = è sotto l'ultima e sotto c'è altro; 0 = no.
    /// «Sotto l'ultima voce» include la fascia dei pallini e anche lo spazio fuori dal banner.
    private func scrollDirection(forY y: CGFloat) -> Int {
        guard isLimited else { return 0 }
        let rects = selectableFrames.values
        guard let firstTop = rects.map({ $0.minY }).min(),
              let lastBottom = rects.map({ $0.maxY }).max() else { return 0 }
        let v = visibility
        if y > lastBottom, v.below { return 1 }
        if y < firstTop, v.above { return -1 }
        return 0
    }

    /// Un passo: una voce in più (o in meno) fuori dall'alto.
    private func stepScroll(down: Bool) {
        let count = rowFrames.count
        let v = visibility
        var changed = false
        withAnimation(Self.absorbAnimation) {
            if down, v.below {
                topIndex = min(topIndex + 1, max(count - 1, 0))
                changed = true
            } else if !down, v.above {
                topIndex = max(topIndex - 1, 0)
                changed = true
            }
        }
        if changed { scrollTick += 1 }
    }

    /// Mentre il dito è sul banner: se la bolla sta sul bordo (sotto l'ultima voce o sopra la prima) per un po',
    /// la lista scorre una voce, poi un'altra ogni `scrollInterval` finché resta lì. Il dito fermo non manda
    /// eventi, per questo serve un ciclo.
    private func startAutoScroll() {
        guard isLimited, autoScroll == nil else { return }
        autoScroll = Task { @MainActor in
            var inZoneSince: Date? = nil
            var lastStep = Date.distantPast
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
                guard let y = currentPointerY() else { continue }
                let dir = scrollDirection(forY: y)
                guard dir != 0 else {
                    inZoneSince = nil
                    continue
                }
                let now = Date()
                let since = inZoneSince ?? now
                inZoneSince = since
                if now.timeIntervalSince(since) >= Self.scrollDwell,
                   now.timeIntervalSince(lastStep) >= Self.scrollInterval {
                    stepScroll(down: dir > 0)
                    lastStep = now
                }
            }
        }
    }

    private func stopAutoScroll() {
        autoScroll?.cancel()
        autoScroll = nil
    }

    /// Chiavi delle righe dei calibri che hanno la bolla piccola.
    private var shortKeys: Set<String> {
        Set(store.config.calibers
            .filter { !store.config.activeWeapons(for: $0.id).isEmpty }
            .map { key(EntryTarget(caliberID: $0.id, weaponID: nil)) })
    }
    /// Bolla grande a riposo su una riga: larga come la riga, meno lo spazio della bolla piccola sui calibri che ne hanno una.
    private func restRect(_ key: String, _ frame: CGRect) -> CGRect {
        var r = frame.insetBy(dx: lensInset, dy: 0)
        if shortKeys.contains(key) { r.size.width -= AbsorbBubble.slot }
        return r
    }

    /// Bolla grande a riposo su una riga: larga come la riga, meno lo spazio della bolla piccola sui calibri che ne hanno una.
    private func lensRect() -> CGRect? {
        guard let full = rowFrames[selectedKey] else { return nil }
        let rest = restRect(selectedKey, full)
        guard let dragY = drag else { return rest }
        // Se nel frattempo la lista è scorsa (dito fermo sul bordo), la posizione del dito si corregge.
        let y = dragY + touchContentTop - contentTop

        let ordered = selectableFrames.sorted { $0.value.midY < $1.value.midY }
        guard let first = ordered.first, let last = ordered.last else { return rest }
        let p = min(max(y, first.value.midY), last.value.midY)     // il puntatore, fra la prima e l'ultima riga

        // Partenza: la prima riga. Se il puntatore è più in basso, il ciclo sostituisce i valori.
        var cy = first.value.midY
        var h = first.value.height
        var w = restRect(first.key, first.value).width

        // Fra le due righe sopra e sotto il puntatore la bolla non segue il dito alla pari:
        // vicino al centro di una riga rallenta (ne viene catturata), a metà strada accelera verso l'altra.
        // Altezza e larghezza usano lo stesso avanzamento, così la forma resta coerente con la riga.
        for i in 1..<ordered.count {
            let a = ordered[i - 1]
            let b = ordered[i]
            guard p <= b.value.midY else { continue }
            let t = (p - a.value.midY) / (b.value.midY - a.value.midY)     // 0 = su a, 1 = su b
            let smooth = t * t * (3 - 2 * t)
            let m = t + (smooth - t) * magnet
            cy = a.value.midY + (b.value.midY - a.value.midY) * m
            h = a.value.height + (b.value.height - a.value.height) * m
            let wa = restRect(a.key, a.value).width
            let wb = restRect(b.key, b.value).width
            w = wa + (wb - wa) * m
            break
        }

        let height = h + 6                                  // premuta, si ingrandisce un po'
        return CGRect(x: rest.minX - 4, y: cy - height / 2, width: w + 8, height: height)
    }

    /// I muri della bolla: bordo alto della prima riga e basso dell'ultima, con 2 pt di respiro (come in GlassSegmented).
    /// Quanto la bolla può uscire ai lati dai bordi delle righe. Il pannello ha 10 pt di margine:
    /// sotto 10 la bolla resta dentro il banner, sopra sporge. Alza o abbassa a gusto.
    private let sideRoom: CGFloat = 5
    /// Quanto stringere la bolla per lato rispetto alla riga (0 = larga come la riga).
    private let lensInset: CGFloat = 3
    /// Quanto la bolla viene attirata dal centro delle righe mentre trascini (0 = segue il dito alla pari).
    /// Sopra 0,8 si "appiccica" troppo.
    private let magnet: CGFloat = 0.3
    /// Righe visibili per intero (con 3 pt di margine per la bolla premuta): le sole su cui la bolla può andare.
    /// Se le righe entrano tutte nel banner, sono tutte.
    /// Quali righe non si vedono per intero nel banner, e se ce ne sono sopra o sotto.
    /// Quando ci sono, riservo una striscia ai pallini e nascondo anche le righe che ci finirebbero sopra.
    private var visibility: (hidden: Set<String>, above: Bool, below: Bool) {
        guard isLimited, !rowFrames.isEmpty else { return ([], false, false) }
        let top = -contentTop + 3
        let bottom = -contentTop + viewportHeight - 3

        // La riga di un calibro porta con sé la sua intestazione, che sta sopra.
        func span(_ key: String, _ r: CGRect) -> (minY: CGFloat, maxY: CGFloat) {
            (key.hasSuffix("|") ? r.minY - 16 : r.minY, r.maxY)
        }

        var above = false
        var below = false
        for (k, r) in rowFrames {
            let s = span(k, r)
            if s.minY < top { above = true }
            if s.maxY > bottom { below = true }
        }
        guard above || below else { return ([], false, false) }

        let topLimit = top + (above ? moreStrip : 0)
        let bottomLimit = bottom - (below ? moreStrip : 0)
        var hidden = Set<String>()
        for (k, r) in rowFrames {
            let s = span(k, r)
            if s.minY < topLimit || s.maxY > bottomLimit { hidden.insert(k) }
        }
        // Banner così basso da non mostrare nemmeno una voce: meglio non nascondere nulla.
        if hidden.count == rowFrames.count { return ([], false, false) }
        return (hidden, above, below)
    }

    /// Le righe su cui la bolla può andare: quelle che si vedono per intero.
    private var selectableFrames: [String: CGRect] {
        let hidden = visibility.hidden
        return rowFrames.filter { !hidden.contains($0.key) }
    }

    private var wallFrames: [CGRect] { Array(selectableFrames.values) }

    /// A riposo la bolla grande non si vede se la sua riga è nascosta.
    private var lensHidden: Bool { drag == nil && visibility.hidden.contains(selectedKey) }
    /// I muri della bolla: in alto e in basso i bordi della prima e dell'ultima riga (+2 pt di respiro),
    /// ai lati i bordi delle righe più `sideRoom`.
    private var wallRange: (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)? {
        let rects = wallFrames
        guard let top = rects.map({ $0.minY }).min(),
              let bottom = rects.map({ $0.maxY }).max(),
              let left = rects.map({ $0.minX }).min(),
              let right = rects.map({ $0.maxX }).max() else { return nil }
        return (top - 0, bottom + 2, left - sideRoom, right + sideRoom)
    }

    @ViewBuilder
    private var lens: some View {
        if let r = lensRect(), let walls = wallRange {
            PickerLens(pressed: drag != nil)
                .frame(width: r.width, height: r.height)
                .modifier(PickerLensEffect(minX: r.minX, width: r.width,
                                           minY: r.minY, height: r.height,
                                           wallTop: walls.top, wallBottom: walls.bottom,
                                           wallLeft: walls.left, wallRight: walls.right))
                // Con le righe ancora invisibili (apertura) la bolla va subito al suo posto, senza scivolare.
                .animation(reveal.rowsVisible ? Animation.spring(response: 0.42, dampingFraction: 0.82) : nil, value: rowFrames)
                .opacity(lensHidden ? 0 : 1)
                .animation(.easeOut(duration: 0.15), value: lensHidden)
        }
    }
}

// MARK: - Supporto

/// Ogni riga scrive qui la propria posizione.
private nonisolated struct RowFramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
/// Ogni bolla piccola scrive qui la propria posizione (chiave = id del calibro).
private nonisolated struct ToggleFramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Misure della bolla piccola (a destra dei calibri che hanno armi).
private enum AbsorbBubble {
    static let size: CGFloat = 22           // diametro con le armi visibili
    static let smallScale: CGFloat = 0.64   // con le armi assorbite: 14 pt
    static let slot: CGFloat = 30           // spazio che toglie alla bolla grande su quelle righe
    static let edge: CGFloat = 3            // distanza dal bordo destro della riga (come lensInset)
    static let hitSlop: CGFloat = 5         // area cliccabile oltre il bordo della bolla
}
/// Il vetro delle bolle piccole: stessi ingredienti della bolla grande quando è premuta
/// (glassEffect, riflesso, bordo), con un'ombra più leggera perché il cerchio è piccolo.
private struct AbsorbGlass: View {
    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.14))
            .overlay(Circle().fill(LinearGradient(
                colors: [Color.white.opacity(0.22), Color.clear, Color.white.opacity(0.06)],
                startPoint: .top, endPoint: .bottom)))
            .overlay(Circle().strokeBorder(LinearGradient(
                colors: [Color.white.opacity(0.80), Color.white.opacity(0.10), Color.white.opacity(0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.30), radius: 3, y: 1)
    }
}

/// Posiziona e deforma la bolla del banner. Conosce la posizione a ogni fotogramma, compreso lo "sfondamento"
/// della molla: se supera un muro (in alto o in basso), il bordo si ferma lì e il resto si schiaccia contro di esso.
/// È la versione verticale di LensEffect in GlassSegmented.
private struct PickerLensEffect: GeometryEffect {
    var minX: CGFloat
    var width: CGFloat
    var minY: CGFloat
    var height: CGFloat
    let wallTop: CGFloat
    let wallBottom: CGFloat
    let wallLeft: CGFloat
    let wallRight: CGFloat

    /// Schiacciamento massimo (frazione dell'altezza) e quanto la bolla si allarga ai lati.
    /// Qui sono molto più bassi che nel selettore: le righe sono alte ~46 pt e il pannello ha poco margine ai lati.
    private static let maxSquash: CGFloat = 1
    private static let bulge: CGFloat = 0.08

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(minX, width), AnimatablePair(minY, height)) }
        set {
            minX = newValue.first.first
            width = newValue.first.second
            minY = newValue.second.first
            height = newValue.second.second
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard size.width > 0, size.height > 0, height > 0 else { return ProjectionTransform() }

        var top = minY
        var bottom = minY + height
        var squash: CGFloat = 0

        // di quanto sfonderebbe ciascun muro
        let hitTop = max(0, wallTop - top)
        let hitBottom = max(0, bottom - wallBottom)
        let hit = max(hitTop, hitBottom)

        if hit > 0 {
            let limit = Self.maxSquash * height
            let c = limit * tanh(hit / limit)          // compressione morbida: segue lo sfondamento, poi satura
            squash = c / height
            if hitTop >= hitBottom {
                top = wallTop
                bottom = wallTop + height - c
            } else {
                bottom = wallBottom
                top = wallBottom - (height - c)
            }
        }

        let grow = width * squash * Self.bulge          // più si schiaccia, più si allarga
        var left = minX - grow / 2
        var right = minX + width + grow / 2
        left = max(left, wallLeft)                      // muri laterali: l'allargamento si ferma qui
        right = min(right, wallRight)

        return ProjectionTransform(
            CGAffineTransform(a: (right - left) / size.width, b: 0,
                              c: 0, d: (bottom - top) / size.height,
                              tx: left, ty: top))
    }
}

/// La bolla di selezione: vetro vero (Liquid Glass) sempre, a riposo e mentre la premi.
/// Premuta si fa un po' più luminosa e proietta un'ombra più marcata.
private struct PickerLens: View {
    let pressed: Bool

    var body: some View {
        Color.clear
            .glassEffect(.clear.tint(Color.white.opacity(pressed ? 0.14 : 0.09)), in: Capsule())
            .overlay(
                Capsule().fill(LinearGradient(
                    colors: [Color.white.opacity(0.16), Color.clear, Color.white.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom))
                .opacity(pressed ? 1 : 0.6))
            .overlay(
                Capsule().strokeBorder(LinearGradient(
                    colors: [Color.white.opacity(0.80), Color.white.opacity(0.10), Color.white.opacity(0.45)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                .opacity(pressed ? 1 : 0.55))
            .shadow(color: Color.black.opacity(pressed ? 0.40 : 0.14),
                    radius: pressed ? 12 : 5, y: pressed ? 4 : 2)
            .animation(.easeOut(duration: 0.15), value: pressed)
            .allowsHitTesting(false)
    }
}

/// Una riga del banner: miniatura, nome, dettaglio. Non è un Button: la selezione la gestisce il gesto
/// del pannello, così la bolla può scorrere. La riga si limita a dire dove si trova.
private struct PickerRow: View {
    let rowKey: String
    let space: String
    let weapon: Weapon?
    let title: String
    let subtitle: String
    var cartridge: CartridgeStyle? = nil     // se c'è, è la riga del solo calibro: si disegna la cartuccia
    var toggleID: String? = nil      // se c'è, è un calibro con armi: a destra compare la bolla piccola
    var absorbed = false             // true = armi assorbite (bolla piccola)
    var togglePressed = false        // la bolla è premuta in questo momento
    var faded = false                // la riga non si vede per intero nel banner: sfuma via

    /// true per la riga del solo calibro (nessuna arma, con la cartuccia).
    private var isCaliberRow: Bool {
        weapon == nil && cartridge != nil
    }

    /// A sinistra: foto dell'arma, oppure cartuccia orizzontale (solo calibro).
    @ViewBuilder
    private var iconView: some View {
        if weapon != nil {
            WeaponThumb(weapon: weapon, size: 34)
        } else if let cartridge {
            // Lunga 34 pt come la miniatura rotonda, così i testi restano allineati a quelli delle armi.
            CartridgeImage(style: cartridge, height: 34, horizontal: true)
                .frame(width: 34, height: 26)
        }
    }

    /// Solo calibro: nome e «Senza arma» sulla stessa riga. Altre righe: nome sopra, dettaglio sotto.
    @ViewBuilder
    private var textView: some View {
        if isCaliberRow {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
        }
    }
    /// Bolla piccola di vetro: 22 pt con le armi visibili, 14 pt con le armi assorbite.
    /// Cambia il diametro vero e non una scala, così il vetro resta nitido. L'area misurata per il clic
    /// è sempre quella da 22 pt: la bolla rimpicciolita si preme comunque facilmente.
    /// Il clic lo gestisce il pannello.
    @ViewBuilder
    private var absorbBubble: some View {
        if let toggleID {
            let d = AbsorbBubble.size
                * (absorbed ? AbsorbBubble.smallScale : 1)
                * (togglePressed ? 0.9 : 1)
            AbsorbGlass()
                .frame(width: d, height: d)
                .frame(width: AbsorbBubble.size, height: AbsorbBubble.size)
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: absorbed)
                .animation(.easeOut(duration: 0.12), value: togglePressed)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ToggleFramesKey.self,
                                               value: [toggleID: geo.frame(in: .named(space))])
                    }
                )
                .padding(.trailing, AbsorbBubble.edge)
                .allowsHitTesting(false)
        }
    }
    var body: some View {
        HStack(spacing: 10) {
            iconView
            textView
            Spacer(minLength: toggleID == nil ? 8 : AbsorbBubble.slot)    // lascia posto alla bolla piccola
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: RowFramesKey.self,
                                       value: [rowKey: geo.frame(in: .named(space))])
            }
        )
        .overlay(alignment: .trailing) { absorbBubble }
        .opacity(faded ? 0 : 1)
        .animation(.easeOut(duration: 0.15), value: faded)
        .id(rowKey)
    }
}

// MARK: - Presentazione UIKit del banner

/// Il contenitore del banner. Lascia passare i tocchi sotto il vetro visibile (la parte trasparente della vista
/// SwiftUI, alta quanto il banner più grande possibile): lì i tocchi vanno allo sfondo, che chiude il banner.
private final class PanelContainerView: UIView {
    var visibleHeight: () -> CGFloat = { 0 }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard point.y <= visibleHeight() else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// La finestra trasparente a tutto schermo che porta il banner. Il vetro è una vista UIKit (UIGlassEffect) che
/// cambia solo cornice: dal tasto al banner e ritorno. Nessuna maschera e nessun alpha sopra il vetro, che
/// altrimenti si appiattirebbe. Il banner SwiftUI dentro è già a misura piena, fermo, e senza vetro proprio:
/// le righe sfumano sopra il vetro che si apre.
@MainActor
private final class PickerOverlayController: UIViewController, UIGestureRecognizerDelegate {
    let hosting: UIHostingController<AnyView>
    /// Cornice del tasto al momento dell'apertura, in coordinate della finestra.
    let sourceFrame: CGRect
    var onOutsideTap: () -> Void = {}

    private let container = PanelContainerView()
    /// Il vetro vero del banner.
    private let glass = UIVisualEffectView(effect: UIGlassEffect())
    private let reveal: PickerReveal
    private let panelWidth: CGFloat
    private let maxHeight: CGFloat
    private let finalX: CGFloat
    private var revealStarted = false
    private var closed = false

    init(root: AnyView, reveal: PickerReveal, source: CGRect, windowBounds: CGRect,
         panelWidth: CGFloat, maxHeight: CGFloat) {
        let margin: CGFloat = 8
        let x = source.midX - panelWidth / 2
        self.hosting = UIHostingController(rootView: root)
        self.reveal = reveal
        self.sourceFrame = source
        self.panelWidth = panelWidth
        self.finalX = min(max(x, margin), windowBounds.width - panelWidth - margin)
        self.maxHeight = max(120, min(maxHeight, windowBounds.maxY - source.minY - margin))
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) non è usato")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        // Un tocco fuori dal banner lo chiude (il contenitore lascia passare i tocchi sotto il vetro visibile).
        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tap.delegate = self
        view.addGestureRecognizer(tap)

        container.backgroundColor = .clear
        container.alpha = 0                       // finché non parte l'apertura (poi resta sempre 1)
        container.visibleHeight = { [weak self] in self?.reveal.panelHeight ?? 0 }
        view.addSubview(container)

        // Angoli: metà altezza finché il vetro è basso (tasto = capsula), al massimo 26 pt (banner).
        glass.cornerConfiguration = .capsule(maximumRadius: 26)
        container.addSubview(glass)

        addChild(hosting)
        hosting.view.backgroundColor = .clear
        hosting.view.isOpaque = false
        container.addSubview(hosting.view)        // sopra il vetro
        hosting.didMove(toParent: self)
    }

    @objc private func backgroundTapped() {
        onOutsideTap()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.view === view
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        onOutsideTap()                       // rotazione o cambio di finestra: il banner si chiude
    }

    /// Cornice del vetro in coordinate del contenitore (che sta fermo, alto quanto il banner più grande possibile).
    private func glassFrame(for source: CGRect) -> CGRect {
        CGRect(x: source.minX - finalX, y: source.minY - sourceFrame.minY,
               width: source.width, height: source.height)
    }

    // MARK: Apertura

    /// Mette tutto al suo posto (invisibile), aspetta che SwiftUI disegni e misuri il banner, poi parte l'animazione.
    func open() {
        container.frame = CGRect(x: finalX, y: sourceFrame.minY, width: panelWidth, height: maxHeight)
        hosting.view.frame = container.bounds
        glass.frame = glassFrame(for: sourceFrame)
        container.alpha = 0
        view.layoutIfNeeded()

        reveal.onPanelHeight = { [weak self] h in self?.panelHeightChanged(h) }

        Task { @MainActor [weak self] in
            var tries = 0
            while let self, self.reveal.panelHeight <= 0, tries < 12 {
                try? await Task.sleep(for: .milliseconds(16))
                tries += 1
            }
            self?.startReveal()
        }
    }

    private func startReveal() {
        guard !closed else { return }
        revealStarted = true
        let h = min(max(reveal.panelHeight, sourceFrame.height), maxHeight)

        container.alpha = 1
        reveal.coversButton = true                // il tasto sparisce: il vetro parte esattamente da lì
        reveal.labelVisible = false               // la scritta del tasto sfuma via

        // Il vetro si allarga dal tasto al banner (Core Animation, nel render server).
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.glass.frame = CGRect(x: 0, y: 0, width: self.panelWidth, height: h)
        }

        // Le righe sfumano in entrata a vetro quasi aperto (se le vedi sporgere in basso, alza 140).
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(140))
            guard let self, !self.closed else { return }
            self.reveal.rowsVisible = true
        }
    }

    /// Il banner SwiftUI cambia altezza (armi assorbite, lista che scorre): il vetro lo segue.
    private func panelHeightChanged(_ height: CGFloat) {
        guard revealStarted, !closed, height > 0 else { return }
        let h = min(height, maxHeight)
        guard abs(glass.frame.height - h) > 0.5 else { return }
        UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.glass.frame.size.height = h
        }
    }

    // MARK: Chiusura

    /// A rovescio: prima sfumano le righe, poi il vetro si richiude sul tasto. La cornice del tasto si legge
    /// solo a chiusura partita (`newSource`), quando ha smesso di cambiare misura.
    func close(to newSource: @escaping () -> CGRect, completion: @escaping () -> Void) {
        guard !closed else { return }
        closed = true
        reveal.onPanelHeight = nil
        guard revealStarted else {                 // non era ancora partita l'apertura: niente da richiudere
            completion()
            return
        }
        reveal.rowsVisible = false

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard let self else { return }
            let end = self.glassFrame(for: newSource())
            UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
                           options: [.beginFromCurrentState]) {
                self.glass.frame = end
            } completion: { _ in
                // Scambio nello stesso fotogramma: il tasto vero torna e il banner sparisce subito.
                // Se restano insieme anche per pochi ms ci sono due vetri sovrapposti: il vetro del banner
                // diventa grigio e rifrange il logo del tasto che gli sta sotto (il «lampeggio» alla chiusura).
                self.reveal.coversButton = false
                completion()
            }
            // La scritta del tasto sfuma di nuovo in cima mentre il vetro si richiude.
            try? await Task.sleep(for: .milliseconds(180))
            self.reveal.labelVisible = true
        }
    }
}

/// Tiene il banner UIKit e lo apre o lo chiude quando `isPresented` cambia.
@MainActor
private final class PickerPresenterCoordinator {
    weak var anchor: UIView?
    var reveal: PickerReveal?
    var panelWidth: CGFloat = 254
    var maxHeight: CGFloat = 360
    var root = AnyView(EmptyView())
    var setPresented: (Bool) -> Void = { _ in }

    private var overlay: PickerOverlayController?
    private var isOpening = false
    private var isClosing = false
    private var wantsPresented = false

    func update(isPresented: Bool) {
        wantsPresented = isPresented
        if isPresented {
            if let overlay {
                overlay.hosting.rootView = root              // il banner aperto riceve i dati aggiornati
            } else if !isOpening {
                scheduleOpen()
            }
        } else if overlay != nil, !isClosing {
            close()
        }
    }

    /// Non si presenta dentro l'aggiornamento di SwiftUI: si aspetta il giro successivo.
    private func scheduleOpen() {
        isOpening = true
        Task { @MainActor [weak self] in
            self?.present()
        }
    }

    private func present() {
        isOpening = false
        guard wantsPresented, overlay == nil,
              let anchor, let window = anchor.window, let reveal else { return }
        var top = window.rootViewController
        while let next = top?.presentedViewController { top = next }
        guard let top else { return }

        reveal.panelHeight = 0
        reveal.rowsVisible = false
        let source = anchor.convert(anchor.bounds, to: window)
        reveal.sourceHeight = source.height
        reveal.labelVisible = true
        let controller = PickerOverlayController(root: root,
                                                 reveal: reveal,
                                                 source: source,
                                                 windowBounds: window.bounds,
                                                 panelWidth: panelWidth,
                                                 maxHeight: maxHeight)
        controller.onOutsideTap = { [weak self] in self?.setPresented(false) }
        overlay = controller
        top.present(controller, animated: false)
        controller.open()
    }

    private func close() {
        guard let overlay, !isClosing else { return }
        isClosing = true
        // La cornice del tasto si legge solo quando parte la chiusura (vedi PickerOverlayController.close).
        overlay.close(to: { [weak self] in
            var frame = overlay.sourceFrame
            if let anchor = self?.anchor, let window = anchor.window {
                frame = anchor.convert(anchor.bounds, to: window)
            }
            self?.reveal?.sourceHeight = frame.height
            return frame
        }) { [weak self] in
            self?.finishClose()
        }
    }

    private func finishClose() {
        overlay?.dismiss(animated: false)
        overlay = nil
        isClosing = false
        reveal?.coversButton = false
        if wantsPresented, !isOpening { scheduleOpen() }     // riaperto mentre si chiudeva
    }

    /// La vista del tasto sta sparendo (cambio di pagina...): niente animazioni, via subito.
    func teardown() {
        reveal?.onPanelHeight = nil
        overlay?.dismiss(animated: false)
        overlay = nil
        isClosing = false
        isOpening = false
        reveal?.coversButton = false
    }
}

/// Va dietro al tasto (ne ha la stessa cornice) e presenta il banner UIKit quando `isPresented` diventa true.
private struct PickerPresenter<Panel: View>: UIViewRepresentable {
    @Binding var isPresented: Bool
    let reveal: PickerReveal
    let panelWidth: CGFloat
    let maxHeight: CGFloat
    let panel: Panel

    func makeCoordinator() -> PickerPresenterCoordinator {
        PickerPresenterCoordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false              // i tocchi arrivano al tasto
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let c = context.coordinator
        c.anchor = uiView
        c.reveal = reveal
        c.panelWidth = panelWidth
        c.maxHeight = maxHeight
        c.root = AnyView(panel)
        c.setPresented = { isPresented = $0 }
        c.update(isPresented: isPresented)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: PickerPresenterCoordinator) {
        coordinator.teardown()
    }
}
