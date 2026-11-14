//
//  CSV.swift
//  AmmoTrack
//
//  Lettura e scrittura CSV (virgolette, a capo CRLF/LF, BOM, separatore , ; o tab)
//  e lettura tollerante dei numeri interi.
//

import Foundation

nonisolated enum CSV {

    /// Legge il testo in righe di campi. Il separatore si riconosce da solo se non lo indichi.
    static func parse(_ text: String, delimiter: Character? = nil) -> [[String]] {
        var scalars = Array(text.unicodeScalars)
        if scalars.first == "\u{FEFF}" { scalars.removeFirst() }          // BOM

        let chosen: Character = delimiter ?? detectDelimiter(scalars)
        let delim: Unicode.Scalar = chosen.unicodeScalars.first ?? ","

        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        var i = 0
        let n = scalars.count

        while i < n {
            let c = scalars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < n && scalars[i + 1] == "\"" {
                        field.append("\"")                                 // "" dentro le virgolette = una virgoletta
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                if field.isEmpty { inQuotes = true } else { field.append(c) }
            } else if c == delim {
                row.append(String(field))
                field = String.UnicodeScalarView()
            } else if c == "\n" || c == "\r" {
                if c == "\r" && i + 1 < n && scalars[i + 1] == "\n" { i += 1 }   // CRLF
                row.append(String(field))
                field = String.UnicodeScalarView()
                rows.append(row)
                row = []
            } else {
                field.append(c)
            }
            i += 1
        }
        // Ultima riga senza a capo finale (come nel CSV esportato da Numbers).
        if !field.isEmpty || !row.isEmpty {
            row.append(String(field))
            rows.append(row)
        }
        return rows
    }

    /// Guarda la prima riga (fuori dalle virgolette) e sceglie fra , ; e tab.
    static func detectDelimiter(_ scalars: [Unicode.Scalar]) -> Character {
        var commas = 0
        var semicolons = 0
        var tabs = 0
        var inQuotes = false
        for c in scalars {
            if c == "\"" {
                inQuotes.toggle()
                continue
            }
            if inQuotes { continue }
            if c == "\n" || c == "\r" { break }
            if c == "," { commas += 1 }
            else if c == ";" { semicolons += 1 }
            else if c == "\t" { tabs += 1 }
        }
        if semicolons > commas && semicolons >= tabs { return ";" }
        if tabs > commas && tabs > semicolons { return "\t" }
        return ","
    }

    // MARK: Scrittura

    /// Mette fra virgolette solo i campi che ne hanno bisogno.
    static func field(_ s: String, delimiter: Character = ",") -> String {
        let delim: Unicode.Scalar = delimiter.unicodeScalars.first ?? ","
        var needsQuotes = s.hasPrefix(" ") || s.hasSuffix(" ")
        if !needsQuotes {
            needsQuotes = s.unicodeScalars.contains { $0 == "\"" || $0 == "\n" || $0 == "\r" || $0 == delim }
        }
        guard needsQuotes else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func line(_ fields: [String], delimiter: Character = ",") -> String {
        fields.map { field($0, delimiter: delimiter) }.joined(separator: String(delimiter))
    }

    /// Intestazione normalizzata: senza accenti, minuscola, senza spazi ai lati ("Quantità " → "quantita").
    static func normalizeHeader(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
    }
}

nonisolated enum NumberParsing {
    /// Intero tollerante: "204", " 70 ", "+5", "−5", "50.0" → 50. Vuoto o testo → nil.
    static func int(_ raw: String) -> Int? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        s = s.replacingOccurrences(of: "\u{2212}", with: "-")      // meno tipografico
        s = s.replacingOccurrences(of: "\u{00A0}", with: "")       // spazio non separabile
        s = s.replacingOccurrences(of: "\u{202F}", with: "")
        s = s.replacingOccurrences(of: " ", with: "")
        if let v = Int(s) { return v }
        let dotted = s.replacingOccurrences(of: ",", with: ".")
        if let d = Double(dotted), d.isFinite, d == d.rounded(), abs(d) < 1_000_000_000 {
            return Int(d)
        }
        return nil
    }
}
