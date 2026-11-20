//
//  GlassSegmented.swift
//
//  Selettore in vetro con la lente che segue il puntatore, e le etichette (testo e pallini).
//  (Copiato dall'altra app, invariato.)
//

import SwiftUI

// MARK: - Selettore in vetro (come la barra dell'app Musica e Telefono)

/// Barra di vetro con una "lente" che segue il puntatore in modo continuo.
/// A riposo la lente è una capsula chiara sulla voce selezionata; appena la tocchi o la
/// trascini diventa vetro vero (Liquid Glass), più grande e con l'ombra, come in Musica.
/// Si allunga nella direzione in cui la muovi e, quando la rilasci, rimbalza come una goccia
/// prima di fermarsi sulla voce più vicina.
/// Il contenuto di ogni voce (testo, simbolo, pallini...) lo decide chi usa il selettore.
///
/// Larghezza: o fissi quella di ogni voce (`segmentWidth`), oppure fissi quella di tutta
/// la barra (`totalWidth`) e le voci si dividono lo spazio in parti uguali.
struct GlassSegmented<T: Hashable, Content: View>: View {
    let options: [T]
    @Binding var selection: T
    var segmentWidth: CGFloat
    let walls: Edge.Set                    // ← nuovo: lati dove la lente sbatte e si schiaccia
    let content: (T, Bool) -> Content      // (voce, è selezionata?)

    /// Margine fra il bordo della barra e la prima/ultima voce.
    /// (Statica e calcolata perché serve già dentro l'init; nei tipi generici
    /// Swift non ammette proprietà statiche memorizzate.)
    private static var barInset: CGFloat { 3 }

    init(options: [T],
         selection: Binding<T>,
         segmentWidth: CGFloat = 80,
         totalWidth: CGFloat? = nil,
         walls: Edge.Set = .horizontal,              // ← nuovo
         @ViewBuilder content: @escaping (T, Bool) -> Content) {
        self.options = options
        self._selection = selection
        self.walls = walls                  // ← nuova riga
        if let totalWidth, !options.isEmpty {
            // barra = voci + un margine a ciascun capo
            self.segmentWidth = (totalWidth - 2 * Self.barInset) / CGFloat(options.count)
        } else {
            self.segmentWidth = segmentWidth
        }
        self.content = content
    }

    private struct DragState: Equatable {
        var x: CGFloat          // centro della lente
        var velocity: CGFloat   // velocità orizzontale in punti al secondo
    }

    /// Stato del trascinamento (nil = a riposo). Si azzera da solo, anche se il gesto viene annullato,
    /// e lo fa con una molla poco smorzata: è quella che dà il rimbalzo.
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.50, dampingFraction: 0.48)))
    private var drag: DragState? = nil

    private let height: CGFloat = 36
    private var inset: CGFloat { Self.barInset }

    private var index: Int { options.firstIndex(of: selection) ?? 0 }
    private var pressed: Bool { drag != nil }

    var body: some View {
        let w = segmentWidth
        let n = CGFloat(options.count)
        let lo = inset + w / 2
        let hi = inset + n * w - w / 2
        let center = drag?.x ?? (inset + CGFloat(index) * w + w / 2)
        let speed = min(abs(drag?.velocity ?? 0) / 3000, 1)          // 0...1
        let base: CGFloat = pressed ? 1.12 : 1
        let stretchX = pressed ? 0.14 * speed : 0                       // si allunga quando corri
        let squashY = pressed ? 0.06 * speed : 0                        // e si schiaccia un po'
        let lensW = w - 2
        let lensH = height - inset * 2 + (pressed ? 8 : 0)

        ZStack(alignment: .leading) {
            track

            lens
                .frame(width: lensW, height: lensH)
                .modifier(LensEffect(center: center,
                                     scaleX: base + stretchX,
                                     scaleY: base - squashY,
                                     wallLeading: walls.contains(.leading) ? -2 : nil,
                                     wallTrailing: walls.contains(.trailing) ? w * n + inset * 2 + 2: nil))

            HStack(spacing: 0) {
                ForEach(options.indices, id: \.self) { i in
                    content(options[i], i == index)
                        .frame(width: w, height: height)
                }
            }
            .padding(.horizontal, inset)
            .animation(.easeOut(duration: 0.15), value: index)
            .allowsHitTesting(false)
        }
        .frame(width: w * n + inset * 2, height: height)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($drag) { g, state, transaction in
                    // Al primo tocco la lente raggiunge il punto con una molla, poi segue senza ritardo.
                    let first: Animation? = (state == nil)
                        ? Animation.spring(response: 0.30, dampingFraction: 0.62)
                        : nil
                    transaction.animation = first
                    state = DragState(x: min(max(g.location.x, lo), hi),
                                      velocity: g.velocity.width)
                }
                .onChanged { g in
                    // La voce selezionata cambia mentre la lente ci passa sopra.
                    let c = min(max(g.location.x, lo), hi)
                    let i = min(max(Int(((c - inset) / w).rounded(.down)), 0), options.count - 1)
                    if options[i] != selection { selection = options[i] }
                }
        )
    }

    /// La barra: vetro vero (Liquid Glass) con un velo scuro, come la barra di Musica.
    @ViewBuilder
    private var track: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(Color.black.opacity(0.30)), in: Capsule())
        } else {
            Capsule()
                .fill(Color.black.opacity(0.34))
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
    }

    /// A riposo una capsula chiara semitrasparente; mentre la sposti, vetro vero.
    private var lens: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.14))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .opacity(pressed ? 0 : 1)
            if pressed {
                glassLens
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .allowsHitTesting(false)
    }

    private var glassLens: some View {
        glassBase
            .overlay(Capsule().fill(highlight))
            .overlay(Capsule().strokeBorder(rim, lineWidth: 1.2))
            .shadow(color: Color.black.opacity(0.40), radius: 12, y: 4)
    }

    @ViewBuilder
    private var glassBase: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Color.clear
                .glassEffect(.clear.tint(Color.white.opacity(0.12)), in: Capsule())
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color.white.opacity(0.14)))
        }
    }

    /// Riflesso morbido: più chiaro in alto, quasi nullo al centro, un filo più chiaro in basso.
    private var highlight: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.16), Color.clear, Color.white.opacity(0.05)],
                       startPoint: .top, endPoint: .bottom)
    }

    private var rim: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.80), Color.white.opacity(0.10), Color.white.opacity(0.45)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Testo di una voce del selettore: bianco e più marcato se selezionata.
func glassLabel(_ text: String, selected: Bool) -> some View {
    Text(text)
        .font(.system(size: 13, weight: selected ? .semibold : .medium))
        .foregroundStyle(selected ? Color.white : Color.white.opacity(0.68))
}

/// Quattro pallini: `filled` pieni e gli altri vuoti (1 = ●○○○, 4 = ●●●●).
struct DotsLabel: View {
    let filled: Int
    let selected: Bool

    private var color: Color { selected ? Color.white : Color.white.opacity(0.68) }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { i in
                ZStack {
                    if i < filled {
                        Circle().fill(color)
                    } else {
                        Circle().strokeBorder(color, lineWidth: 1.2)
                    }
                }
                .frame(width: 7, height: 7)
            }
        }
    }
}
/// Posiziona e deforma la lente (sostituisce scaleEffect + offset).
/// Deve sapere dove si trova la lente a ogni fotogramma, compreso lo "sfondamento" della molla:
/// se supera un muro, il bordo si ferma lì e il resto si schiaccia contro di esso.
private struct LensEffect: GeometryEffect {
    var center: CGFloat           // centro X della lente, nello spazio della barra
    var scaleX: CGFloat
    var scaleY: CGFloat
    let wallLeading: CGFloat?     // X del muro a sinistra (nil = nessun muro)
    let wallTrailing: CGFloat?    // X del muro a destra

    /// Compressione massima (frazione della larghezza) e quanto la lente si gonfia in altezza.
    private static let maxSquash: CGFloat = 10
    private static let bulge: CGFloat = 1

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(center, AnimatablePair(scaleX, scaleY)) }
        set {
            center = newValue.first
            scaleX = newValue.second.first
            scaleY = newValue.second.second
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let free = size.width * scaleX                // larghezza se nessun muro la tocca
        var left = center - free / 2
        var right = center + free / 2
        var squash: CGFloat = 0

        // di quanto sfonderebbe ciascun muro
        let hitL = wallLeading.map { max(0, $0 - left) } ?? 0
        let hitR = wallTrailing.map { max(0, right - $0) } ?? 0
        let hit = max(hitL, hitR)

        if hit > 0 {
            // compressione morbida: segue lo sfondamento all'inizio, poi satura
            let limit = Self.maxSquash * free
            let c = limit * tanh(hit / limit)
            squash = c / free
            if hitL >= hitR, let wall = wallLeading {
                left = wall
                right = wall + free - c
            } else if let wall = wallTrailing {
                right = wall
                left = wall - (free - c)
            }
        }

        let sy = scaleY * (1 + squash * Self.bulge)   // più si schiaccia, più si gonfia in verticale
        return ProjectionTransform(
            CGAffineTransform(a: (right - left) / size.width, b: 0, c: 0, d: sy,
                              tx: left, ty: size.height * (1 - sy) / 2))
    }
}
