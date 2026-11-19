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
// MARK: - Suggerimento a capsula (al posto di .help)

/// Dove compare il suggerimento rispetto al controllo.
enum HintPlacement {
    case below            // sotto, centrato
    case belowTrailing    // sotto, con il bordo destro allineato a quello del controllo
}

private struct GlassHint: ViewModifier {
    let text: String
    let placement: HintPlacement
    let delay: Double

    @State private var shown = false
    @State private var pending: Task<Void, Never>? = nil

    private var overlayAlignment: Alignment {
        placement == .belowTrailing ? .bottomTrailing : .bottom
    }

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                pending?.cancel()
                if inside {
                    pending = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(delay))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.3)) { shown = true }
                    }
                } else {
                    hide()
                }
            }
            .simultaneousGesture(TapGesture().onEnded { hide() })    // al clic il suggerimento sparisce
            .onDisappear { hide() }
            .overlay(alignment: overlayAlignment) { bubble }
            .accessibilityLabel(text)
    }

    private func hide() {
        pending?.cancel()
        withAnimation(.easeOut(duration: 0.15)) { shown = false }
    }

    private var bubble: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(white: 0.07).opacity(0.92)))
            .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)
            .fixedSize()
            .alignmentGuide(.bottom) { d in d[.top] - 6 }      // sotto il controllo, a 6 pt di distanza
            .opacity(shown ? 1 : 0)
            .allowsHitTesting(false)
    }
}

extension View {
    /// Suggerimento a capsula scura che compare dopo `delay` secondi, con dissolvenza.
    func glassHint(_ text: String,
                   placement: HintPlacement = .below,
                   delay: Double = 1.0) -> some View {
        modifier(GlassHint(text: text, placement: placement, delay: delay))
    }
}
