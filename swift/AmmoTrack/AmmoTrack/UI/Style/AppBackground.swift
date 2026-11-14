//
//  AppBackground.swift
//
//  Sfondo della finestra: sfocatura del desktop + sfumatura con gli aloni.
//

import SwiftUI
#if os(macOS)
import AppKit

/// Vista AppKit che sfoca ciò che sta DIETRO la finestra (desktop e altre finestre)
/// e rende trasparente lo sfondo della finestra, così la sfocatura si vede.
final class BlurBackingView: NSVisualEffectView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let w = window else { return }
        w.isOpaque = false
        w.backgroundColor = .clear
    }
}

struct WindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = BlurBackingView()
        v.material = windowMaterial
        v.blendingMode = .behindWindow
        v.state = .active                 // resta sfocata anche quando la finestra non è in primo piano
        v.appearance = NSAppearance(named: .darkAqua)
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#endif

/// Sfondo: sfocatura del desktop + nero → grigio scuro semi trasparente, con tre aloni di colore.
/// Il vetro dei pannelli rifrange questi aloni: senza niente dietro, il Liquid Glass sembra piatto.
struct AppBackground: View {
    var body: some View {
        ZStack {
            #if os(macOS)
            if translucentWindow {
                WindowBlur()
            }
            #endif
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    LinearGradient(colors: [Color(white: 0.015), Color(white: 0.085)],
                                   startPoint: .top, endPoint: .bottom)
                    // Aloni grigi appena percettibili: servono al vetro per avere qualcosa da rifrangere.
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: w * 0.42, height: w * 0.42)
                        .blur(radius: 110)
                        .offset(x: -w * 0.30, y: -h * 0.30)
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: w * 0.38, height: w * 0.38)
                        .blur(radius: 120)
                        .offset(x: w * 0.34, y: -h * 0.05)
                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: w * 0.34, height: w * 0.34)
                        .blur(radius: 120)
                        .offset(x: -w * 0.08, y: h * 0.42)
                }
                .drawingGroup()
                .frame(width: w, height: h)
                .clipped()
            }
            .opacity(translucentWindow ? backgroundTint : 1)
        }
        .ignoresSafeArea()
    }
}
