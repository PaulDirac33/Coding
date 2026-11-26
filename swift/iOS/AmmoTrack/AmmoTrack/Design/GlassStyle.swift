//
//  GlassStyle.swift
//
//  Liquid Glass vero (iOS e iPadOS 26): sfoca e rifrange quello che c'è dietro.
//  Modificatori per pannelli, capsule, cerchi tinti e pulsanti, più l'identificativo con cui il vetro
//  "si trasforma" da una vista all'altra (il tasto delle armi che diventa banner).
//

import SwiftUI

extension View {
    /// Pannello di vetro (schede, casella dell'importo, saldi...).
    func liquidGlass(cornerRadius: CGFloat = 22) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    /// Capsula di vetro. Con `interactive` reagisce al tocco, come i pulsanti di sistema.
    func glassCapsule(interactive: Bool = false) -> some View {
        glassEffect(interactive ? Glass.regular.interactive() : Glass.regular, in: Capsule())
    }

    /// Cerchio di vetro (pulsanti tondi piccoli: Annulla, Ripeti).
    func glassCircle(interactive: Bool = false) -> some View {
        glassEffect(interactive ? Glass.regular.interactive() : Glass.regular, in: Circle())
    }

    /// Cerchio di vetro colorato per i pulsanti tondi (si combina con `glassMorphID`).
    func glassTintedCircle(_ tint: Color) -> some View {
        glassEffect(.regular.tint(tint).interactive(), in: Circle())
    }

    /// Pulsante di vetro del sistema.
    func glassButton() -> some View {
        buttonStyle(.glass)
    }

    /// Pulsante di vetro principale: verde militare con la scritta chiara (Salva, Importa, Nuova arma...).
    func glassProminentButton() -> some View {
        buttonStyle(.glassProminent)
            .tint(Palette.militaryGreen)
    }

    /// Dà al vetro un identificativo: due viste con lo stesso id (nello stesso GlassEffectContainer)
    /// si trasformano l'una nell'altra.
    func glassMorphID(_ id: String, in namespace: Namespace.ID) -> some View {
        glassEffectID(id, in: namespace)
    }
}

/// Cerchio di vetro la cui tinta passa dall'oro (t = 0) al rosso (t = 1).
/// SwiftUI anima `t` e rifà il vetro a ogni fotogramma con il colore intermedio.
struct ProvenanceTintedCircle: ViewModifier, Animatable {
    var t: Double

    var animatableData: Double {
        get { t }
        set { t = newValue }
    }

    func body(content: Content) -> some View {
        content.glassTintedCircle(Palette.provenanceTint(t))
    }
}

extension View {
    /// Tasto tondo di vetro con la tinta fra ricaricate (0) e comprate (1), animabile.
    func provenanceGlassCircle(_ t: Double) -> some View {
        modifier(ProvenanceTintedCircle(t: t))
    }
}
