//
//  DateHelpers.swift
//  AmmoTrack
//
//  Calendario (settimane da lunedì), formattazione compatta e lettura delle date
//  nei formati più comuni: "2026-03-01", "1 Mar 26", "18 December 2022", "15/03/2026", "3 mag 2026".
//

import Foundation

// MARK: - Calendario

nonisolated enum Cal {
    /// Calendario con le settimane da lunedì a domenica, nel fuso orario locale.
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }()

    static func startOfDay(_ date: Date) -> Date {
        cal.startOfDay(for: date)
    }

    /// Costruisce una data valida; nil se il giorno non esiste (es. 31 febbraio).
    static func make(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date? {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        c.minute = minute
        c.second = second
        guard let date = cal.date(from: c) else { return nil }
        let back = cal.dateComponents([.year, .month, .day], from: date)
        guard back.year == year, back.month == month, back.day == day else { return nil }
        return date
    }

    /// Lo stesso giorno, alle ore indicate.
    static func at(_ day: Date, hour: Int, minute: Int, second: Int) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: second, of: day) ?? day
    }

    /// Ora convenzionale dei movimenti di cui si conosce solo il giorno: serve unicamente a ordinare
    /// quelli dello stesso giorno (prima il saldo iniziale, poi le entrate, poi le uscite).
    static func defaultTime(for kind: MovementKind) -> (hour: Int, minute: Int, second: Int) {
        switch kind {
        case .opening: return (0, 0, 0)
        case .added: return (9, 0, 0)
        case .adjustment: return (12, 0, 0)
        case .shot: return (18, 0, 0)
        }
    }

    /// Data completa per un movimento di cui si conosce solo il giorno.
    static func stamp(day: Date, kind: MovementKind) -> Date {
        let t = defaultTime(for: kind)
        return at(cal.startOfDay(for: day), hour: t.hour, minute: t.minute, second: t.second)
    }

    static func sameMonth(_ a: Date, _ b: Date) -> Bool {
        cal.isDate(a, equalTo: b, toGranularity: .month)
    }

    /// Primo giorno del mese (alle 00:00).
    static func monthStart(_ date: Date) -> Date {
        cal.dateInterval(of: .month, for: date)?.start ?? cal.startOfDay(for: date)
    }
}

// MARK: - Formattazione (come `date +%F` / `date +%T`)

nonisolated func pad2(_ n: Int) -> String {
    n < 10 ? "0\(n)" : "\(n)"
}

/// "AAAA-MM-GG" nel fuso orario locale.
nonisolated func isoDay(_ date: Date) -> String {
    let c = Cal.cal.dateComponents([.year, .month, .day], from: date)
    return "\(c.year ?? 0)-\(pad2(c.month ?? 0))-\(pad2(c.day ?? 0))"
}

/// "HH:MM:SS" nel fuso orario locale.
nonisolated func isoTime(_ date: Date) -> String {
    let c = Cal.cal.dateComponents([.hour, .minute, .second], from: date)
    return "\(pad2(c.hour ?? 0)):\(pad2(c.minute ?? 0)):\(pad2(c.second ?? 0))"
}

/// "AAAAMMGG-HHMMSS": per i nomi dei file di backup.
nonisolated func compactStamp(_ date: Date) -> String {
    let c = Cal.cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    return "\(c.year ?? 0)\(pad2(c.month ?? 0))\(pad2(c.day ?? 0))-\(pad2(c.hour ?? 0))\(pad2(c.minute ?? 0))\(pad2(c.second ?? 0))"
}

// MARK: - Lettura delle date

nonisolated enum DateParsing {

    /// Mesi in inglese e in italiano: basta il prefisso di tre lettere ("Mar", "March", "marzo"...).
    private static let months: [String: Int] = [
        "jan": 1, "gen": 1,
        "feb": 2,
        "mar": 3,
        "apr": 4,
        "may": 5, "mag": 5,
        "jun": 6, "giu": 6,
        "jul": 7, "lug": 7,
        "aug": 8, "ago": 8,
        "sep": 9, "set": 9,
        "oct": 10, "ott": 10,
        "nov": 11,
        "dec": 12, "dic": 12
    ]

    static func monthNumber(_ token: String) -> Int? {
        let letters = token.lowercased().filter { $0.isLetter }
        guard letters.count >= 3 else { return nil }
        return months[String(letters.prefix(3))]
    }

    /// 26 → 2026, 98 → 1998, 2022 → 2022.
    static func fullYear(_ y: Int) -> Int {
        if y >= 100 { return y }
        return y < 70 ? 2000 + y : 1900 + y
    }

    /// Legge un giorno (restituisce le 00:00 locali) o nil se il testo non è una data valida.
    static func parseDay(_ raw: String) -> Date? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }

        // ISO con orario: "2026-03-01T12:30:00" → tengo solo la data.
        if let t = s.firstIndex(of: "T") {
            let head = s[s.startIndex..<t]
            if head.count == 10, head.filter({ $0 == "-" }).count == 2 {
                s = String(head)
            }
        }

        let separators = CharacterSet(charactersIn: " ,/-.\t")
        let tokens = s.components(separatedBy: separators).filter { !$0.isEmpty && !$0.contains(":") }
        let numbers = tokens.compactMap { Int($0) }
        let words = tokens.filter { Int($0) == nil }

        // Con il nome del mese: "1 Mar 26", "18 December 2022", "Mar 1, 2026".
        if let month = words.compactMap({ monthNumber($0) }).first {
            guard numbers.count >= 2 else { return nil }
            let day: Int
            let year: Int
            if numbers[0] > 31 {
                year = numbers[0]
                day = numbers[1]
            } else {
                day = numbers[0]
                year = numbers[1]
            }
            return Cal.make(year: fullYear(year), month: month, day: day)
        }

        // Tutto numerico: "2026-03-01", "15/03/2026", "15.03.26".
        guard numbers.count == 3 else { return nil }
        if numbers[0] > 31 {
            return Cal.make(year: numbers[0], month: numbers[1], day: numbers[2])
        }
        let a = numbers[0]
        let b = numbers[1]
        let y = fullYear(numbers[2])
        if a > 12 { return Cal.make(year: y, month: b, day: a) }      // 25/03/2026 → giorno prima
        if b > 12 { return Cal.make(year: y, month: a, day: b) }      // 03/25/2026 → mese prima
        return Cal.make(year: y, month: b, day: a)                     // ambiguo: all'italiana, giorno/mese
    }

    /// "HH:MM" o "HH:MM:SS".
    static func parseTime(_ raw: String) -> (hour: Int, minute: Int, second: Int)? {
        let parts = raw.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2 || parts.count == 3,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m)
        else { return nil }
        var s = 0
        if parts.count == 3 {
            let secondsText = parts[2].split(separator: ".").first.map(String.init) ?? ""
            guard let v = Int(secondsText), (0..<60).contains(v) else { return nil }
            s = v
        }
        return (h, m, s)
    }
}
