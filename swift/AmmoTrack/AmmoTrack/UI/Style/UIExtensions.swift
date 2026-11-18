//
//  UIExtensions.swift
//
//  Colori e simboli dei tipi del Core, barra del limite, anteprime delle armi, piccole utilità di vista.
//

import SwiftUI

// MARK: - Provenienza e tipo di movimento

extension Provenance {
    var color: Color { self == .reloaded ? Palette.reloaded : Palette.bought }
    /// Ingranaggio per le ricaricate, carrello per le comprate.
    var symbol: String { self == .reloaded ? "gearshape.fill" : "cart.fill" }
}

extension MovementKind {
    var symbol: String {
        switch self {
        case .opening: return "flag.fill"
        case .added: return "arrow.down"
        case .shot: return "arrow.up"
        case .adjustment: return "plusminus"
        }
    }
}

// MARK: - Formati

/// Numeri a video con i separatori del sistema (anche quelli personalizzati in Impostazioni di Sistema).
/// `.formatted()` li ignora; NumberFormatter no. I formattatori si creano una volta sola perché costano.
/// `nonisolated(unsafe)`: NumberFormatter è sicuro da usare da più thread, ma Swift non lo sa.
nonisolated private let integerFormatter = makeNumberFormatter(maxFraction: 0)
nonisolated private let oneDecimalFormatter = makeNumberFormatter(maxFraction: 1)

nonisolated private func makeNumberFormatter(maxFraction: Int) -> NumberFormatter {
    let f = NumberFormatter()
    f.locale = Locale.autoupdatingCurrent
    f.numberStyle = .decimal
    f.usesGroupingSeparator = true
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = maxFraction
    return f
}

nonisolated func numText(_ v: Int) -> String {
    integerFormatter.string(from: NSNumber(value: v)) ?? String(v)
}

nonisolated func decimalText(_ v: Double, maxFraction: Int = 1) -> String {
    let f: NumberFormatter
    switch maxFraction {
    case 0: f = integerFormatter
    case 1: f = oneDecimalFormatter
    default: f = makeNumberFormatter(maxFraction: maxFraction)
    }
    return f.string(from: NSNumber(value: v)) ?? String(v)
}

/// "14 nov 2026"
func dayText(_ d: Date) -> String {
    d.formatted(.dateTime.day().month(.abbreviated).year())
}

// MARK: - Barra del limite

/// Barra sottile: quanto del limite denunciato è occupato. Arancione oltre il 90%, rossa oltre il 100%.
struct LimitBar: View {
    let value: Int
    let limit: Int?

    private var ratio: Double {
        guard let limit, limit > 0 else { return 0 }
        return Double(max(value, 0)) / Double(limit)
    }

    private var tint: Color {
        if ratio > 1 { return Palette.danger }
        if ratio >= 0.9 { return Palette.warning }
        return Color.white.opacity(0.62)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * CGFloat(min(ratio, 1)))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Immagini delle armi
/// Beretta già disegnata, una volta sola per misura: l'icona vera ha decine di sagome con sfocature e maschere,
/// troppo pesanti da ridisegnare a ogni fotogramma mentre il banner armi si apre.
@MainActor
enum BerettaBitmap {
    private struct Key: Hashable {
        let height: Int
        let tint: Color
    }
    private static var cache: [Key: CGImage] = [:]

    static func image(height: CGFloat, tint: Color = Palette.muted) -> CGImage? {
        let key = Key(height: Int((height * 100).rounded()), tint: tint)
        if let cached = cache[key] { return cached }
        let renderer = ImageRenderer(content: BerettaIcon(height: height).foregroundStyle(tint))
        renderer.scale = 3
        guard let image = renderer.cgImage else { return nil }
        cache[key] = image
        return image
    }
}
/// Miniatura dell'arma: il logo (PNG con trasparenza) per intero e centrato.
/// Senza logo mostra l'emoji della pistola, in grigio, dentro un cerchio.
struct WeaponThumb: View {
    @EnvironmentObject var store: DataStore
    let weapon: Weapon?
    var caliberID: String? = nil        // non serve più, resta per non toccare le chiamate esistenti
    var size: CGFloat = 34

    var body: some View {
        let pixels = Int(size * 3)
        if let logo = store.logo(for: weapon, maxPixel: pixels) {
            Image(decorative: logo, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            let h = size / BerettaIcon.aspectRatio
            if let bitmap = BerettaBitmap.image(height: h) {
                Image(decorative: bitmap, scale: 3)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                BerettaIcon(height: h)
                    .foregroundStyle(Palette.muted)
                    .frame(width: size, height: size)
            }
        }
    }
}
/// La composizione del segnaposto: la Beretta con il bossolo in piedi a destra dell'impugnatura, sotto il ponticello,
/// con il fondello sulla stessa linea della base della pistola.
struct WeaponPlaceholderArt: View {
    let style: CartridgeStyle
    let gunHeight: CGFloat

    var body: some View {
        let gunW = gunHeight * BerettaIcon.aspectRatio
        ZStack(alignment: .bottomLeading) {
            BerettaIcon(height: gunHeight)
            CartridgeIcon(style: style, height: gunHeight * 0.37, restsOnBottom: true)
                .frame(width: gunW * 0.12)
                .padding(.leading, gunW * 0.34)        // centro del bossolo a circa il 40% della larghezza
        }
        .frame(width: gunW, height: gunHeight)
    }
}

/// Il segnaposto già disegnato, una volta sola per tipo di cartuccia (come BerettaBitmap).
/// Si disegna grande e poi si rimpicciolisce: non va rifatto a ogni misura della scheda.
@MainActor
enum WeaponPlaceholderBitmap {
    static let gunHeight: CGFloat = 200
    static let scale: CGFloat = 2
    private static var cache: [CartridgeStyle: CGImage] = [:]

    static func image(style: CartridgeStyle) -> CGImage? {
        if let cached = cache[style] { return cached }
        let art = WeaponPlaceholderArt(style: style, gunHeight: gunHeight)
            .foregroundStyle(Color.white.opacity(0.30))
        let renderer = ImageRenderer(content: art)
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }
        cache[style] = image
        return image
    }
}

/// Anteprima grande dell'arma. `data` è una foto scelta ma non ancora salvata (nell'editor).
struct WeaponImage: View {
    @EnvironmentObject var store: DataStore
    var weapon: Weapon? = nil
    var caliberID: String? = nil      // calibro scelto nell'editor (arma non ancora salvata)
    var data: Data? = nil
    var removed = false
    var maxPixel = 900

    private var resolved: CGImage? {
        if let data { return ImageTools.cgImage(from: data, maxPixel: maxPixel) }
        if removed { return nil }
        return store.image(for: weapon, maxPixel: maxPixel)
    }
    private var cartridge: CartridgeStyle {
        store.config.caliber(caliberID ?? weapon?.caliberID ?? "")?.cartridgeStyle ?? .pistol
    }
    /// Segnaposto senza foto: la Beretta con il bossolo in piedi accanto, la scritta sotto.
    private var placeholder: some View {
        GeometryReader { geo in
            let gunH = min(geo.size.height * 0.52, geo.size.width * 0.66 / BerettaIcon.aspectRatio)
            let gunW = gunH * BerettaIcon.aspectRatio
            VStack(spacing: gunH * 0.12) {
                if let art = WeaponPlaceholderBitmap.image(style: cartridge) {
                    Image(decorative: art, scale: WeaponPlaceholderBitmap.scale)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: gunW, height: gunH)
                } else {
                    WeaponPlaceholderArt(style: cartridge, gunHeight: gunH)     // ripiego: vettoriale
                        .foregroundStyle(Color.white.opacity(0.30))
                }
                Text("Nessuna immagine")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.30))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            if let img = resolved {
                Image(decorative: img, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Testo d'errore rosso, una riga o due.
struct ErrorLine: View {
    let text: String?

    var body: some View {
        if let text, !text.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(text)
            }
            .font(.caption)
            .foregroundStyle(Palette.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
/// Logo dell'arma, per intero e centrato, con la trasparenza. `data` è un logo scelto ma non ancora salvato.
struct WeaponLogo: View {
    @EnvironmentObject var store: DataStore
    var weapon: Weapon? = nil
    var data: Data? = nil
    var removed = false
    var maxPixel = 400

    private var resolved: CGImage? {
        if let data { return ImageTools.cgImage(from: data, maxPixel: maxPixel) }
        if removed { return nil }
        return store.logo(for: weapon, maxPixel: maxPixel)
    }

    var body: some View {
        if let img = resolved {
            Image(decorative: img, scale: 1)
                .resizable()
                .scaledToFit()
        } else {
            Text("Nessun logo")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.30))
        }
    }
}
