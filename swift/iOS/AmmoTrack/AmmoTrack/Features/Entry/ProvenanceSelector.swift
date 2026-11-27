//
//  ProvenanceSelector.swift
//
//  Selettore ricaricate / comprate della pagina Inserimento.
//  È il UISegmentedControl di sistema (Liquid Glass vero: la lente scorre e si deforma col dito), con:
//  - il simbolo (ingranaggio / carrello) sopra la scritta, come nella barra delle pagine ma più piccolo;
//  - scritta e simbolo che si colorano (oro per le ricaricate, rosso per le comprate) SOLO sotto la bolla:
//    il colore compare e sparisce mentre la bolla passa, come nella barra delle pagine.
//
//  Le scritte vere del controllo restano (le legge VoiceOver) ma sono trasparenti: simboli e scritte visibili li disegna
//  `ProvenanceSelector` sopra al controllo, senza intercettare il tocco. Le scritte colorate sono una copia di quelle grigie,
//  ritagliata da una capsula che segue la bolla. La posizione della bolla mentre la si trascina è stimata dal dito.
//

import SwiftUI
import UIKit

/// Alone della bolla a riposo = tinta del vetro: un grigio con una certa opacità.
/// Grigio: 0 = nero, 1 = bianco. Opacità: 0 = trasparente (vetro pulito), 1 = pieno.
let provenanceLensGray: CGFloat = 0.3
let provenanceLensOpacity: CGFloat = 0.6
/// Ingrandimento di simbolo e scritta sotto la bolla mentre la tocchi o la trascini (1 = nessuno, 1.2 = +20%).
let provenanceZoomPressed: CGFloat = 1.1
/// Ingrandimento a bolla ferma (1 = nessuno; con 1.05 resta un piccolo ingrandimento fisso).
let provenanceZoomAtRest: CGFloat = 1.0

struct ProvenanceSelector: View {
    @Binding var selection: Provenance

    /// Altezza: due righe, simbolo sopra e scritta sotto.
    static let height: CGFloat = 46

    /// Posizione della bolla mentre la si trascina (0 = sulla prima voce, 1 = sull'ultima). nil = a riposo.
    @State private var dragPos: Double? = nil
    @State private var dragActive = false
    @State private var settleTicket = 0
    @State private var pressed = false                          // il dito è sulla bolla

    private var segmentWidth: CGFloat {
        (EntryLayout.controlWidth - 6) / CGFloat(Provenance.allCases.count)
    }

    /// Dove sta la bolla a riposo: sulla voce scelta.
    private var restPos: Double {
        Double(Provenance.allCases.firstIndex(of: selection) ?? 0)
    }

    private var lensPos: Double { dragPos ?? restPos }

    var body: some View {
        ProvenanceSegments(selection: $selection, onLens: lensMoved, onPress: lensPressed, onJump: lensJumped)
            .frame(width: EntryLayout.controlWidth, height: Self.height)
            .overlay { labels }
            .onChange(of: selection) { _, _ in
                if !dragActive { dragPos = nil }                 // la scelta è arrivata: da qui si segue la voce scelta
            }
    }

    // MARK: Bolla trascinata

    /// Il controllo avvisa a ogni movimento del dito (finished = false) e al rilascio (finished = true).
    private func lensMoved(_ pos: Double, _ finished: Bool) {
        if !finished {
            dragActive = true
            dragPos = pos                                  // senza animazione: segue il dito
            return
        }
        dragActive = false
        let target = pos.rounded()                         // la bolla si ferma sulla voce più vicina
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { dragPos = target }
        // Rete di sicurezza: se la scelta non cambia (o non arriva), dopo un attimo si torna alla voce scelta.
        settleTicket += 1
        let ticket = settleTicket
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            if settleTicket == ticket && !dragActive { dragPos = nil }
        }
    }
    /// Il dito si appoggia sulla bolla (true) o si stacca (false): le voci sotto la bolla si ingrandiscono a molla.
    private func lensPressed(_ down: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pressed = down }
    }

    /// Il dito si appoggia su una voce NON scelta: la bolla va subito lì (a molla) e ci resta finché non lo alzi.
    private func lensJumped(_ index: Int) {
        dragActive = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { dragPos = Double(index) }
    }

    /// Ingrandimento della voce `index` (solo nella copia sotto la bolla): massimo con la bolla centrata su di lei, nullo quando è sull'altra.
    /// Ogni voce si ingrandisce attorno al proprio centro, quindi non si sposta: entra nella bolla già al suo posto.
    private func zoom(_ index: Int) -> CGFloat {
        let coverage = max(0, 1 - abs(lensPos - Double(index)))
        let z = pressed ? provenanceZoomPressed : provenanceZoomAtRest
        return 1 + (z - 1) * CGFloat(coverage)
    }

    /// La sagoma della bolla (bordo morbido, come la lente): segue `lensPos`.
    private var lensShape: some View {
        Capsule()
            .frame(width: segmentWidth, height: Self.height)
            .blur(radius: 2)
            .offset(x: 3 + CGFloat(lensPos) * segmentWidth)
    }

    // MARK: Simboli e scritte (sopra al controllo)

    /// Fuori dalla bolla: simboli e scritte grigi, fermi (sotto la bolla c'è un buco).
    /// Dentro la bolla: la copia colorata, ingrandita attorno al centro della bolla e ritagliata dal suo bordo (lente convergente).
    private var labels: some View {
        ZStack {
            labelRow(colored: false)
                .mask {
                    Rectangle()
                        .overlay(alignment: .leading) { lensShape.blendMode(.destinationOut) }
                        .compositingGroup()
                }
            labelRow(colored: true)
                .mask(alignment: .leading) { lensShape }
        }
        .allowsHitTesting(false)          // il tocco arriva al controllo che sta sotto
        .accessibilityHidden(true)        // le legge il controllo
    }

    /// Le due voci stanno nella stessa posizione di quelle del controllo: margine di 3 pt e metà larghezza ciascuna.
    private func labelRow(colored: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(Provenance.allCases.enumerated()), id: \.element) { index, p in
                VStack(spacing: 1) {
                    Image(systemName: p.symbol)
                        .font(.system(size: 15, weight: .semibold))
                    Text(p.label)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(colored ? p.color : Palette.muted)
                .scaleEffect(colored ? zoom(index) : 1)       // solo la copia sotto la bolla si ingrandisce
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 3)
    }
}

// MARK: - Il controllo di sistema

private struct ProvenanceSegments: UIViewRepresentable {
    @Binding var selection: Provenance
    /// (posizione della bolla, finito): posizione stimata dal dito, da 0 (prima voce) a 1 (ultima).
    var onLens: (Double, Bool) -> Void
    /// true quando il dito si appoggia sulla bolla, false quando si stacca.
    var onPress: (Bool) -> Void
    /// Il dito si appoggia su una voce NON scelta: indice di quella voce.
    var onJump: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, onLens: onLens, onPress: onPress, onJump: onJump)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: Provenance.allCases.map { $0.label })
        control.selectedSegmentIndex = Provenance.allCases.firstIndex(of: selection) ?? 0

        // Alone della bolla a riposo: più scuro.
        control.selectedSegmentTintColor = UIColor(white: provenanceLensGray, alpha: provenanceLensOpacity)

        // Scritte trasparenti: le disegna ProvenanceSelector, con il simbolo sopra.
        for state in [UIControl.State.normal, .selected, .highlighted] {
            control.setTitleTextAttributes([.foregroundColor: UIColor.clear], for: state)
        }
        control.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)

        // Segue il dito senza disturbare il controllo (che continua a ricevere tutti i tocchi).
        let touch = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.touched(_:)))
        touch.minimumPressDuration = 0
        touch.allowableMovement = .greatestFiniteMagnitude
        touch.cancelsTouchesInView = false
        touch.delaysTouchesBegan = false
        touch.delaysTouchesEnded = false
        touch.delegate = context.coordinator
        control.addGestureRecognizer(touch)
        return control
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        let coordinator = context.coordinator
        coordinator.selection = $selection
        coordinator.onLens = onLens
        coordinator.onPress = onPress
        coordinator.onJump = onJump
        // La scelta si passa al controllo SOLO se è cambiata da fuori. Questa funzione gira a ogni movimento del dito:
        // se rimettesse la scelta vecchia mentre trascini, la bolla non riuscirebbe a cambiare voce.
        if coordinator.lastSelection != selection {
            coordinator.lastSelection = selection
            let index = Provenance.allCases.firstIndex(of: selection) ?? 0
            if control.selectedSegmentIndex != index {
                control.selectedSegmentIndex = index
            }
        }
    }

    /// Altezza fissa (il controllo di sistema da solo è più basso) e larghezza quella proposta.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? EntryLayout.controlWidth, height: ProvenanceSelector.height)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var selection: Binding<Provenance>
        var onLens: (Double, Bool) -> Void
        var onPress: (Bool) -> Void
        var onJump: (Int) -> Void
        /// L'ultima scelta nota (arrivata dal controllo o da SwiftUI): serve a non rimettere nel controllo una scelta vecchia.
        var lastSelection: Provenance

        private var armed = false          // il tocco è partito sulla bolla
        private var dragging = false       // il dito si è mosso davvero
        private var startX: CGFloat = 0
        private var startIndex = 0
        private var startPos: Double = 0
        private var lastPos: Double = 0
        private var origin = 0             // la voce scelta quando il dito si è appoggiato
        private var jumped = false         // il dito si è appoggiato su una voce NON scelta e la bolla è corsa lì

        init(selection: Binding<Provenance>,
             onLens: @escaping (Double, Bool) -> Void,
             onPress: @escaping (Bool) -> Void,
             onJump: @escaping (Int) -> Void) {
            self.selection = selection
            self.onLens = onLens
            self.onPress = onPress
            self.onJump = onJump
            self.lastSelection = selection.wrappedValue
        }

        @objc func changed(_ sender: UISegmentedControl) {
            let all = Provenance.allCases
            guard all.indices.contains(sender.selectedSegmentIndex) else { return }
            lastSelection = all[sender.selectedSegmentIndex]
            selection.wrappedValue = all[sender.selectedSegmentIndex]
        }

        /// Il dito si appoggia: sulla voce scelta (e si trascina) o su una voce non scelta (la bolla ci va subito).
        /// Da qui si stima dove sta la bolla.
        @objc func touched(_ g: UILongPressGestureRecognizer) {
            guard let control = g.view as? UISegmentedControl else { return }
            let count = max(control.numberOfSegments, 1)
            let inset: CGFloat = 3
            let width = (control.bounds.width - 2 * inset) / CGFloat(count)
            let x = g.location(in: control).x

            switch g.state {
            case .began:
                var index = control.selectedSegmentIndex
                origin = max(index, 0)
                jumped = false
                // Appoggiato su una voce NON scelta: la bolla (quella di sistema e la nostra) va subito lì,
                // come nella barra delle pagine. La scelta si conferma al rilascio.
                let hit = min(max(Int((x - inset) / width), 0), count - 1)
                if index >= 0 && hit != index && x >= inset && x <= control.bounds.width - inset {
                    index = hit
                    jumped = true
                    control.selectedSegmentIndex = hit
                    onJump(hit)
                }
                startX = x
                startIndex = max(index, 0)
                startPos = Double(startIndex)
                lastPos = startPos
                dragging = false
                armed = index >= 0
                    && x >= inset + CGFloat(index) * width
                    && x <= inset + CGFloat(index + 1) * width
                if armed { onPress(true) }
            case .changed:
                guard armed else { return }
                if !dragging && abs(x - startX) < 4 { return }      // un tocco fermo non è un trascinamento
                dragging = true
                lastPos = min(max(startPos + Double((x - startX) / width), 0), Double(count - 1))
                onLens(lastPos, false)
            case .ended:
                if dragging || jumped {
                    let target = Int(lastPos.rounded())
                    onLens(lastPos, true)
                    commit(target, in: control)
                }
                if armed { onPress(false) }
                dragging = false
                jumped = false
                armed = false
            case .cancelled, .failed:
                // La voce nuova non era stata confermata: la bolla torna dov'era.
                if jumped, selection.wrappedValue == Provenance.allCases[origin] {
                    control.selectedSegmentIndex = origin
                }
                if dragging || jumped { onLens(Double(origin), true) }
                if armed { onPress(false) }
                dragging = false
                jumped = false
                armed = false
            default:
                break
            }
        }

        /// Rete di sicurezza: alla fine di un trascinamento, o di un tocco prolungato su una voce nuova, la scelta la confermiamo noi
        /// se il controllo non l'ha già fatto (valueChanged). Se la scelta è già quella, non si tocca niente.
        private func commit(_ index: Int, in control: UISegmentedControl) {
            DispatchQueue.main.async { [weak self, weak control] in
                guard let self, let control else { return }
                let all = Provenance.allCases
                guard all.indices.contains(index), self.selection.wrappedValue != all[index] else { return }
                control.selectedSegmentIndex = index
                self.lastSelection = all[index]
                self.selection.wrappedValue = all[index]
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
