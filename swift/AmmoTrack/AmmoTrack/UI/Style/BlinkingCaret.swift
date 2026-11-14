//
//  BlinkingCaret.swift
//
//  Cursore lampeggiante accanto alle cifre.
//

import SwiftUI

/// Cursore lampeggiante accanto alle cifre.
struct BlinkingCaret: View {
    var height: CGFloat = 34
    @State private var on = false

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.85))
            .frame(width: 3, height: height)
            .opacity(on ? 1 : 0.15)
            .padding(.leading, 3)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}
