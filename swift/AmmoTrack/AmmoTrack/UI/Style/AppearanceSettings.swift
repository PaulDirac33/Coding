//
//  AppearanceSettings.swift
//
//  Aspetto della finestra (come nell'altra app): traslucida con sfocatura del desktop, oppure sfondo pieno.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// true  = finestra traslucida: dietro la app si vede il desktop, sfocato (le finestre sotto non si leggono).
/// false = sfondo pieno sfumato.
let translucentWindow = true

/// Quanto è "pieno" il colore scuro sopra la sfocatura (0 = quasi trasparente, 1 = opaco).
/// Se vuoi vedere più desktop abbassalo, se vuoi più contrasto alzalo.
let backgroundTint: Double = 0.66

#if os(macOS)
/// Tipo di sfocatura dietro la finestra. Alternative: .underWindowBackground, .fullScreenUI, .sidebar, .popover
let windowMaterial: NSVisualEffectView.Material = .hudWindow
#endif
