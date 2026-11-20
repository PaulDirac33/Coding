//
//  TouchHelpers.swift
//
//  Piccoli aiuti per iPhone e iPad: tastiera numerica, popover che restano popover,
//  chiusura della tastiera. Su Mac non fanno nulla.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {

    /// Tastiera numerica sui campi dei numeri (su Mac non cambia nulla).
    /// `signed`: con anche il segno meno (per le rettifiche).
    @ViewBuilder
    func numericKeyboard(signed: Bool = false) -> some View {
        #if os(iOS)
        keyboardType(signed ? .numbersAndPunctuation : .numberPad)
        #else
        self
        #endif
    }

    /// Su iPhone i popover diventano fogli a tutta altezza: questo li tiene popover, come sul Mac.
    @ViewBuilder
    func keepsPopover() -> some View {
        #if os(iOS)
        presentationCompactAdaptation(.popover)
        #else
        self
        #endif
    }
}

#if os(iOS)
/// Chiude la tastiera a schermo (il pulsante «Fine» sopra la tastiera numerica).
func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
#endif
