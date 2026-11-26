//
//  IconCache.swift
//
//  Le icone pesanti (Beretta e cartucce, fatte di decine di sagome con luci e maschere) si disegnano UNA volta
//  e poi si mostrano come immagini. Il banner armi le mostra mentre si apre e si anima: se le ridisegnasse a ogni
//  fotogramma, o se dovesse disegnarle per la prima volta proprio in quel momento, l'apertura scatterebbe.
//  `Prewarm` le prepara subito dopo l'avvio, una alla volta, a schermata già visibile.
//

import SwiftUI
import UIKit

// MARK: - Cartucce già disegnate

@MainActor
enum CartridgeBitmap {
    static let scale: CGFloat = 3

    private struct Key: Hashable {
        let style: CartridgeStyle
        let height: Int
        let horizontal: Bool
    }
    private static var cache: [Key: CGImage] = [:]

    static func image(style: CartridgeStyle, height: CGFloat, horizontal: Bool) -> CGImage? {
        let key = Key(style: style, height: Int((height * 100).rounded()), horizontal: horizontal)
        if let cached = cache[key] { return cached }
        let renderer = ImageRenderer(content: CartridgeIcon(style: style, height: height, horizontal: horizontal)
            .foregroundStyle(Palette.muted))
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }
        cache[key] = image
        return image
    }
}

/// La cartuccia come immagine (stessa misura e stesso aspetto di CartridgeIcon, in grigio).
struct CartridgeImage: View {
    let style: CartridgeStyle
    let height: CGFloat
    var horizontal = false

    var body: some View {
        if let cg = CartridgeBitmap.image(style: style, height: height, horizontal: horizontal) {
            Image(decorative: cg, scale: CartridgeBitmap.scale)
        } else {
            CartridgeIcon(style: style, height: height, horizontal: horizontal)
                .foregroundStyle(Palette.muted)
        }
    }
}

// MARK: - Icona della barra delle pagine

@MainActor
enum AppIcons {
    private static var berettaTab: UIImage?

    /// La Beretta per la barra delle pagine: una sagoma "template", che il sistema colora come le altre icone
    /// (chiara quando la voce è scelta, grigia quando no).
    static func beretta() -> UIImage {
        if let berettaTab { return berettaTab }
        let image: UIImage
        if let cg = BerettaBitmap.image(height: 22, tint: .white) {
            image = UIImage(cgImage: cg, scale: 3, orientation: .up).withRenderingMode(.alwaysTemplate)
        } else {
            image = UIImage(systemName: "scope") ?? UIImage()
        }
        berettaTab = image
        return image
    }
}

// MARK: - Preparazione in anticipo

@MainActor
enum Prewarm {
    /// Disegna in anticipo le icone più pesanti, una alla volta (fra l'una e l'altra lo schermo può aggiornarsi).
    static func run() async {
        _ = BerettaBitmap.image(height: 32 / BerettaIcon.aspectRatio)            // miniatura nel tasto delle armi
        await Task.yield()
        _ = BerettaBitmap.image(height: 34 / BerettaIcon.aspectRatio)            // miniatura nelle righe del banner
        await Task.yield()
        _ = BerettaBitmap.image(height: 220, tint: Color.white.opacity(0.30))    // segnaposto della pagina Armi
        await Task.yield()
        for style in [CartridgeStyle.pistol, CartridgeStyle.rimfire] {
            _ = CartridgeBitmap.image(style: style, height: 34, horizontal: true)    // righe del banner
            await Task.yield()
            _ = CartridgeBitmap.image(style: style, height: 64, horizontal: true)    // tasto delle armi, solo calibro
            await Task.yield()
        }
    }
}
