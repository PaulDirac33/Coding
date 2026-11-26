//
//  AppBackground.swift
//
//  Sfondo di ogni pagina: nero con sopra la mimetica scura (vedi CamoBackground).
//  Il vetro dei pannelli rifrange queste chiazze: senza niente dietro, il Liquid Glass sembra piatto.
//

import SwiftUI

struct AppBackground: View {
    var body: some View {
        ZStack {
            Color.black
            if appBackgroundStyle == .camouflage {
                CamoBackground()
            }
        }
        .ignoresSafeArea()
    }
}
