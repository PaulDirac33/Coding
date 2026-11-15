//
//  GlassStyle.swift
//
//  Modificatori View: pannello Liquid Glass, capsule e pulsanti in vetro (con ripiego per macOS < 26),
//  più i due aiutanti per il selettore delle armi che "si trasforma" dal pulsante al pannello.
//

import SwiftUI

extension View {
    /// Pannello in vetro: Liquid Glass su macOS 26+, materiale traslucido sui sistemi precedenti.
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 22) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.tint(Color.black.opacity(0.28)),
                             in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Palette.line))
        }
    }

    /// Capsula di vetro (pulsanti a pillola). Con `interactive` reagisce al tocco, come i pulsanti di sistema.
    @ViewBuilder
    func glassCapsule(interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.tint(Color.black.opacity(0.28)).interactive(), in: Capsule())
            } else {
                self.glassEffect(.regular.tint(Color.black.opacity(0.28)), in: Capsule())
            }
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Palette.line))
        }
    }
    /// Cerchio di vetro colorato per i pulsanti tondi (si combina con `glassMorphID`).
    @ViewBuilder
    func glassTintedCircle(_ tint: Color) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(), in: Circle())
        } else {
            self
                .background(Circle().fill(tint.opacity(0.85)))
                .overlay(Circle().stroke(Palette.line))
        }
    }

    /// Pulsante in vetro su macOS 26+, pulsante normale prima.
    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Pulsante in vetro colorato (usa .tint) su macOS 26+.
    @ViewBuilder
    func glassProminentButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Dà al vetro un identificativo: due viste con lo stesso id (nello stesso GlassContainer)
    /// si trasformano l'una nell'altra. Prima di macOS 26 non fa nulla.
    @ViewBuilder
    func glassMorphID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

/// Contenitore che fa fondere e trasformare il vetro delle viste che contiene (macOS 26);
/// sui sistemi precedenti è un contenitore trasparente.
struct GlassContainer<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}
