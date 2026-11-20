//
//  PageShortcuts.swift
//  AmmoTrack
//
//  ⌘← e ⌘→ cambiano pagina (Inserimento · Dati · Armi), come il selettore in alto, da qualunque pagina.
//
//  Su iPad con la tastiera valgono gli stessi tasti (pulsanti invisibili con la scorciatoia, in fondo al file).
//
//  Su Mac usa un monitor locale dei tasti, come quello di EntryView per il backspace:
//  - agisce solo se il tasto arriva alla finestra principale (non a Impostazioni, non a un popover);
//  - se c'è un foglio aperto (editor, importazione) o stai scrivendo in un campo di testo,
//    lascia passare il tasto: ⌘← resta "inizio riga" nei campi di testo;
//  - agli estremi (prima e ultima pagina) non fa nulla; tenendo premuto non scorre più di una pagina.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

extension View {
    /// Collega ⌘← e ⌘→ alla pagina scelta. Va applicato alla vista radice (RootView).
    @ViewBuilder
    func pageShortcuts(page: Binding<AppPage>) -> some View {
        #if os(macOS)
        modifier(PageShortcuts(page: page))
        #else
        modifier(PageShortcutButtons(page: page))
        #endif
    }
}

#if os(macOS)

/// Ricorda in quale finestra sta RootView (serve al monitor, che non vede lo stato della vista).
@MainActor
final class PageShortcutGate {
    weak var window: NSWindow?
}

struct PageShortcuts: ViewModifier {
    @Binding var page: AppPage

    @State private var monitor: Any? = nil
    @State private var gate = PageShortcutGate()

    /// Stessa molla del pager di RootView: la lente del selettore scorre insieme alle pagine.
    private let slide = Animation.spring(response: 0.48, dampingFraction: 0.90)

    func body(content: Content) -> some View {
        let gate = self.gate
        return content
            .background(WindowReader { gate.window = $0 })
            .onAppear { install() }
            .onDisappear { remove() }
    }

    // MARK: Cambio pagina

    /// delta = +1 pagina successiva (a destra), −1 precedente. Agli estremi resta dov'è.
    private func step(_ delta: Int) {
        let pages = AppPage.allCases
        let target = page.index + delta
        guard pages.indices.contains(target) else { return }
        withAnimation(slide) { page = pages[target] }
    }

    // MARK: Monitor dei tasti

    private func install() {
        guard monitor == nil else { return }
        let gate = self.gate
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 123 = freccia sinistra, 124 = freccia destra. Le frecce portano anche i flag "numericPad"
            // e "function": per questo tengo solo i quattro modificatori veri e voglio ⌘ da solo.
            let code = event.keyCode
            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard code == 123 || code == 124, mods == .command else { return event }

            let consumed: Bool = MainActor.assumeIsolated {
                guard let window = event.window, window === gate.window else { return false }
                if window.attachedSheet != nil { return false }
                if window.firstResponder is NSText { return false }
                if !event.isARepeat { step(code == 124 ? 1 : -1) }
                return true
            }
            return consumed ? nil : event
        }
    }

    private func remove() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}

// MARK: - Finestra della vista

/// Vista invisibile che dice in quale finestra si trova (stesso principio di BlurBackingView).
private struct WindowReader: NSViewRepresentable {
    let onWindow: @MainActor (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ReaderView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ReaderView)?.onWindow = onWindow
    }

    final class ReaderView: NSView {
        var onWindow: (@MainActor (NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow?(window)
        }
    }
}

#endif

#if !os(macOS)

// MARK: - iPad con la tastiera

/// ⌘← e ⌘→ come su Mac, ma con due pulsanti invisibili che portano la scorciatoia.
struct PageShortcutButtons: ViewModifier {
    @Binding var page: AppPage

    /// Stessa molla del pager di RootView: la lente del selettore scorre insieme alle pagine.
    private let slide = Animation.spring(response: 0.48, dampingFraction: 0.90)

    /// delta = +1 pagina successiva (a destra), −1 precedente. Agli estremi resta dov'è.
    private func step(_ delta: Int) {
        let pages = AppPage.allCases
        let target = page.index + delta
        guard pages.indices.contains(target) else { return }
        withAnimation(slide) { page = pages[target] }
    }

    func body(content: Content) -> some View {
        content.background {
            Group {
                Button("") { step(-1) }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Button("") { step(1) }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }
}

#endif
