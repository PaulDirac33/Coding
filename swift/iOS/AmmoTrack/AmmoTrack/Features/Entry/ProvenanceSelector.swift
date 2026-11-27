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

struct ProvenanceSelector: View {
    @Binding var selection: Provenance

    /// Altezza: due righe, simbolo sopra e scritta sotto.
    static let height: CGFloat = 46

    /// Posizione della bolla mentre la si trascina (0 = sulla prima voce, 1 = sull'ultima). nil = a riposo.
    @State private var dragPos: Double? = nil
    @State private var dragActive = false
    @State private var settleTicket = 0

    private var segmentWidth: CGFloat {
        (EntryLayout.controlWidth - 6) / CGFloat(Provenance.allCases.count)
    }

    /// Dove sta la bolla a riposo: sulla voce scelta.
    private var restPos: Double {
        Double(Provenance.allCases.firstIndex(of: selection) ?? 0)
    }

    private var lensPos: Double { dragPos ?? restPos }

    var body: some View {
        ProvenanceSegments(selection: $selection, onLens: lensMoved)
            .frame(width: EntryLayout.controlWidth, height: Self.height)
            .overlay { labels }
            .onChange(of: selection) { _, _ in
                if !dragActive { dragPos = nil }          // la scelta è arrivata: da qui si segue la voce scelta
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

    // MARK: Simboli e scritte (sopra al controllo)

    /// Sotto: simboli e scritte grigi. Sopra: gli stessi, colorati, visibili solo dove passa la bolla.
    private var labels: some View {
        ZStack {
            labelRow(colored: false)
            labelRow(colored: true)
                .mask(alignment: .leading) {
                    Capsule()
                        .frame(width: segmentWidth, height: Self.height)
                        .blur(radius: 2)                   // bordo morbido, come la lente
                        .offset(x: 3 + CGFloat(lensPos) * segmentWidth)
                }
        }
        .allowsHitTesting(false)          // il tocco arriva al controllo che sta sotto
        .accessibilityHidden(true)        // le legge il controllo
    }

    /// Le due voci stanno nella stessa posizione di quelle del controllo: margine di 3 pt e metà larghezza ciascuna.
    private func labelRow(colored: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Provenance.allCases) { p in
                VStack(spacing: 1) {
                    Image(systemName: p.symbol)
                        .font(.system(size: 15, weight: .semibold))
                    Text(p.label)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(colored ? p.color : Palette.muted)
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

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, onLens: onLens)
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
        /// L'ultima scelta nota (arrivata dal controllo o da SwiftUI): serve a non rimettere nel controllo una scelta vecchia.
        var lastSelection: Provenance

        private var armed = false          // il tocco è partito sulla bolla
        private var dragging = false       // il dito si è mosso davvero
        private var startX: CGFloat = 0
        private var startIndex = 0
        private var startPos: Double = 0
        private var lastPos: Double = 0

        init(selection: Binding<Provenance>, onLens: @escaping (Double, Bool) -> Void) {
            self.selection = selection
            self.onLens = onLens
            self.lastSelection = selection.wrappedValue
        }

        @objc func changed(_ sender: UISegmentedControl) {
            let all = Provenance.allCases
            guard all.indices.contains(sender.selectedSegmentIndex) else { return }
            lastSelection = all[sender.selectedSegmentIndex]
            selection.wrappedValue = all[sender.selectedSegmentIndex]
        }

        /// Un tocco sulla voce scelta che si trascina sposta la bolla: da qui si stima dove sta.
        /// Un semplice tocco su un'altra voce non passa di qui: lo anima la scelta.
        @objc func touched(_ g: UILongPressGestureRecognizer) {
            guard let control = g.view as? UISegmentedControl else { return }
            let count = max(control.numberOfSegments, 1)
            let inset: CGFloat = 3
            let width = (control.bounds.width - 2 * inset) / CGFloat(count)
            let x = g.location(in: control).x

            switch g.state {
            case .began:
                let index = control.selectedSegmentIndex
                startX = x
                startIndex = max(index, 0)
                startPos = Double(startIndex)
                lastPos = startPos
                dragging = false
                armed = index >= 0
                    && x >= inset + CGFloat(index) * width
                    && x <= inset + CGFloat(index + 1) * width
            case .changed:
                guard armed else { return }
                if !dragging && abs(x - startX) < 4 { return }      // un tocco fermo non è un trascinamento
                dragging = true
                lastPos = min(max(startPos + Double((x - startX) / width), 0), Double(count - 1))
                onLens(lastPos, false)
            case .ended:
                if dragging {
                    let target = Int(lastPos.rounded())
                    onLens(lastPos, true)
                    commit(target, in: control)
                }
                dragging = false
                armed = false
            case .cancelled, .failed:
                if dragging { onLens(startPos, true) }
                dragging = false
                armed = false
            default:
                break
            }
        }

        /// Rete di sicurezza: se il trascinamento è finito su un'altra voce ma il controllo non ha cambiato scelta
        /// (nessun valueChanged), la scelta la confermiamo noi. Se l'ha già cambiata il controllo, non si tocca niente.
        private func commit(_ index: Int, in control: UISegmentedControl) {
            let from = startIndex
            DispatchQueue.main.async { [weak self, weak control] in
                guard let self, let control else { return }
                let all = Provenance.allCases
                guard all.indices.contains(index), index != from else { return }
                guard control.selectedSegmentIndex == from, self.selection.wrappedValue == all[from] else { return }
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
