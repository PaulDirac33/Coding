//
//  AppearanceSettings.swift
//
//  Aspetto e comportamento che si possono regolare da qui.
//

import SwiftUI

enum BackgroundStyle {
    case black          // nero pieno
    case camouflage     // mimetica scura (il vetro ci rifrange dentro)
}

/// Sfondo dell'app: `.black` oppure `.camouflage`.
let appBackgroundStyle: BackgroundStyle = .camouflage

/// Il banner armi si apre come il menù del filtro armi nella pagina Dati: il tasto «si allunga» e diventa il banner (true).
/// La presentazione è una finestra UIKit trasparente con un'animazione di Core Animation, fluida come quelle di sistema
/// (la trasformazione del vetro fatta in SwiftUI scattava). Dentro c'è il banner di sempre: loghi, cartucce, bolla di
/// selezione, bollicine che nascondono le armi.
/// Con false torna il popover di sistema (con la freccetta): è il ripiego se qualcosa non va.
let weaponPickerUsesOverlay = true
