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

/// Il banner armi si apre con la trasformazione del vetro (true) oppure con una dissolvenza (false, più leggera:
/// è quella che non scatta). Metti true solo se vuoi riprovare la trasformazione.
let weaponPickerMorphs = true
