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
        case .added: return "arrow.up"
        case .shot: return "arrow.down"
        case .adjustment: return "plusminus"
        }
    }
}

// MARK: - Formati

func numText(_ v: Int) -> String {
    v.formatted()
}

func decimalText(_ v: Double, maxFraction: Int = 1) -> String {
    v.formatted(.number.precision(.fractionLength(0...maxFraction)))
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

/// Miniatura rotonda dell'arma (o un mirino se non c'è la foto).
struct WeaponThumb: View {
    @EnvironmentObject var store: DataStore
    let weapon: Weapon?
    var size: CGFloat = 34

    var body: some View {
        let pixels = Int(size * 3)
        ZStack {
            Circle().fill(Color.white.opacity(0.10))
            if let img = store.image(for: weapon, maxPixel: pixels) {
                Image(decorative: img, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "scope")
                    .font(.system(size: size * 0.46, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// Anteprima grande dell'arma. `data` è una foto scelta ma non ancora salvata (nell'editor).
struct WeaponImage: View {
    @EnvironmentObject var store: DataStore
    var weapon: Weapon? = nil
    var data: Data? = nil
    var removed = false
    var maxPixel = 900

    private var resolved: CGImage? {
        if let data { return ImageTools.cgImage(from: data, maxPixel: maxPixel) }
        if removed { return nil }
        return store.image(for: weapon, maxPixel: maxPixel)
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
                VStack(spacing: 6) {
                    Image(systemName: "scope")
                        .font(.system(size: 40, weight: .light))
                    Text("Nessuna immagine")
                        .font(.caption)
                }
                .foregroundStyle(Color.white.opacity(0.30))
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
