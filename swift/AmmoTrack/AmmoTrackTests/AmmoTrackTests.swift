//
//  AmmoTrackTests.swift
//  AmmoTrackTests
//
//  Test del Core: CSV, date, importazione dal foglio Numbers (con i TUOI dati reali: 9x21 e .22),
//  registro e saldi, statistiche, archivio su file.
//
//  Il test più importante: l'import dei due fogli deve riprodurre la colonna TOTALE riga per riga.
//  Se un giorno cambi il Core e questi test restano verdi, i tuoi saldi sono ancora giusti.
//
//  Come usarli: in Xcode, File ▸ New ▸ Target ▸ Unit Testing Bundle (Swift Testing) se non c'è già,
//  metti questo file nella cartella del target di test e premi ⌘U.
//

import Testing
import Foundation
@testable import AmmoTrack

// MARK: - Dati di prova (copiati dai CSV esportati da Numbers)

/// Foglio del 9x21, identico al CSV esportato (25 righe, dal 18 dicembre 2022; l'ultima colonna è un contatore).
private let sheet9x21 = """
Denunciate: 600,RICARICATE,COMPRATE,AGGIUNTE (RICARICATE),AGGIUNTE (COMPRATE),SPARATE (RICARICATE),SPARATE (COMPRATE),TOTALE,
18 December 2022,4,85,,,,85,4,1
28 February 2023,4,0,150,,,,154,2
1 March 2023,154,0,50,,,,204,3
19 March 2023,204,0,,,70,,134,4
14 January 2024,134,0,,,100,,34,5
6 March 2024,34,0,100,,,,134,6
24 March 2024,134,0,,,70,,64,7
5 April 2024,64,0,100,,,,164,8
9 November 2024,164,0,,,70,,94,9
28 February 2025,94,0,100,,,,194,10
1 March 2025,194,0,,,,,194,11
2 March 2025,194,0,,,70,,124,12
20 March 2025,124,0,100,,,,224,13
3 May 2025,224,0,,,70,,154,14
6 May 2025,154,0,150,,,,304,15
21 Nov 2025,304,0,,,100,,204,16
1 Mar 26,204,0,,,30,,174,17
9 Mar 26,174,0,50,,,,224,18
15 Mar 26,224,0,,,70,,154,19
30 Mar 26,154,0,100,,,,254,20
31 Mar 26,254,0,,,100,,154,21
16 May 26,154,0,,,30,,124,22
16 Oct 26,124,0,,,70,,54,23
29 Oct 26,54,0,100,,,,154,24
30 Oct 26,154,0,,,100,,54,25
"""

/// Foglio del .22: solo comprate. La prima riga ha solo il TOTALE (400): è un saldo iniziale implicito.
private let sheet22 = """
Denunciate: 400,COMPRATE,SPARATE,TOTALE
18 December 2022,,,400
5 May 2025,400,,400
16 May 26,400,3,397
30 Oct 26,397,27,370
"""

private let cal9x21 = Caliber(id: "9x21", name: "9x21", limit: 600, allowsReload: true)
private let cal22 = Caliber(id: "22lr", name: ".22 LR", limit: 400, allowsReload: false)

private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    Cal.make(year: y, month: m, day: d)!
}

/// Ultimo saldo totale di ogni giorno ("AAAA-MM-GG" → totale), per confrontarlo con la colonna TOTALE del foglio.
private func endOfDayTotals(_ ledger: Ledger) -> [String: Int] {
    var out: [String: Int] = [:]
    for r in ledger.rows { out[isoDay(r.movement.date)] = r.after.total }
    return out
}

// MARK: - Test

@Suite("AmmoTrack Core")
struct AmmoTrackCoreTests {

    // MARK: CSV

    @Test func csvQuotesAndCRLF() {
        let rows = CSV.parse("a,b,c\r\n1,\"x,y\",3\r\n\"q\"\"r\",,\r\n")
        #expect(rows == [["a", "b", "c"], ["1", "x,y", "3"], ["q\"r", "", ""]])
    }

    @Test func csvSemicolonAndNoFinalNewline() {
        #expect(CSV.parse("a;b\n1;2") == [["a", "b"], ["1", "2"]])
    }

    @Test func csvWriterQuotesOnlyWhenNeeded() {
        #expect(CSV.line(["a", "b,c", "d\"e", ""]) == "a,\"b,c\",\"d\"\"e\",")
    }

    // MARK: Date

    @Test func dateFormats() {
        func ymd(_ s: String) -> String? { DateParsing.parseDay(s).map(isoDay) }
        #expect(ymd("18 December 2022") == "2022-12-18")
        #expect(ymd("21 Nov 2025") == "2025-11-21")
        #expect(ymd("1 Mar 26") == "2026-03-01")
        #expect(ymd("5 May 2025") == "2025-05-05")
        #expect(ymd("2026-03-01") == "2026-03-01")
        #expect(ymd("2026-03-01 12:30:00") == "2026-03-01")
        #expect(ymd("15/03/2026") == "2026-03-15")
        #expect(ymd("3 mag 2026") == "2026-05-03")
        #expect(ymd("31 Feb 2026") == nil)
        #expect(ymd("") == nil)
        #expect(ymd("ciao") == nil)
    }

    @Test func timeFormats() {
        #expect(DateParsing.parseTime("09:05")?.hour == 9)
        #expect(DateParsing.parseTime("23:59:58")?.second == 58)
        #expect(DateParsing.parseTime("24:00") == nil)
        #expect(DateParsing.parseTime("") == nil)
    }

    // MARK: Importazione dal foglio Numbers (dati reali)

    @Test func import9x21ReproducesTheSheet() {
        let r = NumbersImport.parse(text: sheet9x21, caliber: cal9x21)
        #expect(r.fatalError == nil)
        #expect(r.issues.isEmpty)
        #expect(r.rowsRead == 25)
        #expect(r.rowsChecked == 25)
        #expect(r.movements.count == 26)                  // 2 saldi iniziali + 24 righe con un movimento (una è vuota)
        #expect(r.finalBalance == Balance(reloaded: 54, bought: 0))
        #expect(r.sheetFinalTotal == 54)

        // Saldo iniziale della prima riga: 4 ricaricate + 85 comprate, il 18 dicembre 2022.
        let openings = r.movements.filter { $0.kind == .opening }
        #expect(openings.count == 2)
        #expect(openings.first(where: { $0.provenance == .reloaded })?.quantity == 4)
        #expect(openings.first(where: { $0.provenance == .bought })?.quantity == 85)
        #expect(openings.allSatisfy { isoDay($0.date) == "2022-12-18" })

        // Il registro rifà la colonna TOTALE: stesso valore a fine di ogni giorno con movimenti.
        let totals = endOfDayTotals(Ledger(movements: r.movements))
        let expected: [String: Int] = [
        "2022-12-18": 4,
        "2023-02-28": 154,
        "2023-03-01": 204,
        "2023-03-19": 134,
        "2024-01-14": 34,
        "2024-03-06": 134,
        "2024-03-24": 64,
        "2024-04-05": 164,
        "2024-11-09": 94,
        "2025-02-28": 194,
        "2025-03-02": 124,
        "2025-03-20": 224,
        "2025-05-03": 154,
        "2025-05-06": 304,
        "2025-11-21": 204,
        "2026-03-01": 174,
        "2026-03-09": 224,
        "2026-03-15": 154,
        "2026-03-30": 254,
        "2026-03-31": 154,
        "2026-05-16": 124,
        "2026-10-16": 54,
        "2026-10-29": 154,
        "2026-10-30": 54
        ]
        #expect(totals == expected)
    }

    @Test func import9x21WithWindowsLineEndings() {
        let crlf = sheet9x21.replacingOccurrences(of: "\n", with: "\r\n")
        let r = NumbersImport.parse(text: crlf, caliber: cal9x21)
        #expect(r.issues.isEmpty)
        #expect(r.movements.count == 26)
        #expect(r.finalBalance == Balance(reloaded: 54, bought: 0))
    }

    @Test func import22ReproducesTheSheet() {
        let r = NumbersImport.parse(text: sheet22, caliber: cal22)
        #expect(r.fatalError == nil)
        #expect(r.issues.isEmpty)
        #expect(r.rowsRead == 4)
        #expect(r.rowsChecked == 4)
        #expect(r.movements.count == 3)                   // saldo iniziale implicito 400 + due spari
        #expect(r.finalBalance == Balance(reloaded: 0, bought: 370))
        let opening = r.movements.first
        #expect(opening?.kind == .opening)
        #expect(opening?.quantity == 400)
        #expect(opening?.provenance == .bought)
        let totals = endOfDayTotals(Ledger(movements: r.movements))
        #expect(totals == ["2022-12-18": 400, "2026-05-16": 397, "2026-10-30": 370])
    }

    @Test func importDetectsAWrongTotal() {
        // Altero un solo TOTALE nel foglio: l'app lo deve segnalare (una differenza) e i saldi restano giusti.
        let broken = sheet9x21.replacingOccurrences(of: "3 May 2025,224,0,,,70,,154,14",
                                                    with: "3 May 2025,224,0,,,70,,155,14")
        #expect(broken != sheet9x21)
        let r = NumbersImport.parse(text: broken, caliber: cal9x21)
        #expect(r.issues.count == 1)
        #expect(r.finalBalance == Balance(reloaded: 54, bought: 0))
    }

    @Test func importIgnoresRowsWithoutDateAndReportsThem() {
        let text = sheet22 + "\nTotale,,,\n"
        let r = NumbersImport.parse(text: text, caliber: cal22)
        #expect(r.rowsRead == 4)
        #expect(r.issues.count == 1)
    }

    @Test func importIdsAreStable() {
        let a = NumbersImport.parse(text: sheet9x21, caliber: cal9x21).movements.map { $0.id }
        let b = NumbersImport.parse(text: sheet9x21, caliber: cal9x21).movements.map { $0.id }
        #expect(a == b)
        #expect(Set(a).count == a.count)
        #expect(a.allSatisfy { $0.hasPrefix(NumbersImport.idPrefix(for: "9x21")) })
    }

    @Test func importWithoutHeaderFails() {
        let r = NumbersImport.parse(text: "a,b\n1,2", caliber: cal9x21)
        #expect(r.fatalError != nil)
        #expect(r.movements.isEmpty)
    }

    // MARK: movimenti.csv

    @Test func movementCSVRoundTrip() {
        let w = Weapon(id: "W1", name: "Glock 34", caliberID: "9x21", serial: "ABC123")
        let list = [
            Movement(id: "a", date: Cal.stamp(day: day(2026, 3, 1), kind: .opening), hasTime: false, kind: .opening,
                     provenance: .reloaded, caliberID: "9x21", quantity: 204),
            Movement(id: "b", date: Cal.make(year: 2026, month: 3, day: 1, hour: 15, minute: 30, second: 12)!, hasTime: true,
                     kind: .shot, provenance: .reloaded, caliberID: "9x21", quantity: 30, weaponID: "W1",
                     note: "poligono, prima uscita \"lunga\""),
            Movement(id: "c", date: Cal.stamp(day: day(2026, 3, 9), kind: .added), hasTime: false, kind: .added,
                     provenance: .bought, caliberID: "22lr", quantity: 100),
            Movement(id: "d", date: Cal.stamp(day: day(2026, 3, 10), kind: .adjustment), hasTime: false, kind: .adjustment,
                     provenance: .reloaded, caliberID: "9x21", quantity: -4, note: "conteggio fisico")
        ]
        let text = MovementCSV.encode(list, weapons: [w])
        let back = MovementCSV.decode(text, weapons: [w])
        #expect(back.isValid)
        #expect(back.skipped == 0)
        #expect(back.movements == list)
    }

    @Test func movementCSVReadsWeaponByNameAndSkipsBadRows() {
        let w = Weapon(id: "W1", name: "Glock 34", caliberID: "9x21", serial: "ABC123")
        let text = """
        data,tipo,provenienza,calibro,quantita,arma
        2026-03-01,sparo,ricaricate,9x21,30,glock 34
        2026-03-02,sparo,ricaricate,9x21,0,
        2026-03-03,boh,ricaricate,9x21,5,
        2026-03-04,acquisto,,22lr,100,
        """
        let load = MovementCSV.decode(text, weapons: [w])
        #expect(load.isValid)
        #expect(load.skipped == 2)                          // quantità zero e tipo sconosciuto
        #expect(load.movements.count == 2)
        #expect(load.movements[0].weaponID == "W1")
        #expect(load.movements[1].kind == .added)           // "acquisto" implica l'aggiunta...
        #expect(load.movements[1].provenance == .bought)    // ...e la provenienza "comprate"
    }

    @Test func movementCSVWithUnknownHeaderIsInvalid() {
        let load = MovementCSV.decode("foo,bar\n1,2\n", weapons: [])
        #expect(!load.isValid)
        #expect(load.movements.isEmpty)
    }

    @Test func emptyMovementFileIsValid() {
        let load = MovementCSV.decode("", weapons: [])
        #expect(load.isValid)
        #expect(load.movements.isEmpty)
    }

    // MARK: Registro e saldi

    @Test func sameDayEntriesComeBeforeExits() {
        // Inseriti "al contrario" (prima lo sparo): a parità di giorno le entrate vengono prima, quindi nessun saldo negativo.
        let d = day(2026, 5, 16)
        let shot = Movement(id: "s", date: Cal.stamp(day: d, kind: .shot), hasTime: false, kind: .shot,
                            provenance: .reloaded, caliberID: "9x21", quantity: 50)
        let add = Movement(id: "a", date: Cal.stamp(day: d, kind: .added), hasTime: false, kind: .added,
                           provenance: .reloaded, caliberID: "9x21", quantity: 100)
        let ledger = Ledger(movements: [shot, add])
        #expect(ledger.rows.map { $0.id } == ["a", "s"])
        #expect(ledger.overdrawnCount == 0)
        #expect(ledger.balance(for: "9x21") == Balance(reloaded: 50, bought: 0))
    }

    @Test func overdrawnShotIsFlagged() {
        let add = Movement(id: "a", date: Cal.stamp(day: day(2026, 1, 1), kind: .added), hasTime: false, kind: .added,
                           provenance: .reloaded, caliberID: "9x21", quantity: 30)
        let shot = Movement(id: "s", date: Cal.stamp(day: day(2026, 1, 2), kind: .shot), hasTime: false, kind: .shot,
                            provenance: .reloaded, caliberID: "9x21", quantity: 50)
        let ledger = Ledger(movements: [add, shot])
        #expect(ledger.overdrawnCount == 1)
        #expect(ledger.row(id: "s")?.isOverdrawn == true)
        #expect(ledger.balance(for: "9x21").reloaded == -20)
    }

    @Test func balancesAreSeparatePerCaliber() {
        let a = Movement(id: "a", date: day(2026, 1, 1), hasTime: false, kind: .opening, provenance: .reloaded,
                         caliberID: "9x21", quantity: 10)
        let b = Movement(id: "b", date: day(2026, 1, 1), hasTime: false, kind: .opening, provenance: .bought,
                         caliberID: "22lr", quantity: 400)
        let ledger = Ledger(movements: [a, b])
        #expect(ledger.balance(for: "9x21").total == 10)
        #expect(ledger.balance(for: "22lr").total == 400)
        #expect(ledger.balance(for: nil).total == 410)
    }

    // MARK: Statistiche (sui dati reali del 9x21)

    @Test func statsOnRealData() {
        let movements = NumbersImport.parse(text: sheet9x21, caliber: cal9x21).movements
        let ledger = Ledger(movements: movements)
        let now = day(2026, 11, 14)

        let s = Stats.summary(ledger: ledger, movements: movements, caliberID: "9x21", since: nil, now: now)
        #expect(s.shots == 1035)
        #expect(s.shotsReloaded == 950)
        #expect(s.shotsBought == 85)
        #expect(s.addedReloaded == 1000)                  // le ricaricate fatte dal 2023
        #expect(s.sessions == 14)
        #expect(s.stock == Balance(reloaded: 54, bought: 0))
        #expect(s.runwayMonths != nil)

        let months = Stats.monthly(movements: movements, kind: .shot, caliberID: "9x21", since: nil, until: now)
        #expect(months.count == 48)                       // dicembre 2022 … novembre 2026, compresi i mesi vuoti
        func bucket(_ y: Int, _ m: Int) -> MonthBucket? {
            months.first { Cal.sameMonth($0.month, day(y, m, 1)) }
        }
        #expect(bucket(2022, 12)?.bought == 85)
        #expect(bucket(2023, 3)?.reloaded == 70)
        #expect(bucket(2026, 3)?.reloaded == 200)         // 30 (1 marzo) + 70 (15 marzo) + 100 (31 marzo)
        #expect(bucket(2026, 10)?.reloaded == 170)
        #expect(bucket(2026, 11)?.total == 0)

        let sessions = Stats.sessions(movements: movements, caliberID: "9x21", since: nil)
        #expect(sessions.count == 14)
        #expect(sessions.reduce(0) { $0 + $1.shots } == 1035)

        let bins = Stats.histogram(values: sessions.map { $0.shots }, binSize: 50)
        #expect(bins.reduce(0) { $0 + $1.count } == 14)
    }

    @Test func stockSeriesStartsAndEndsOnTheRightDays() {
        let movements = NumbersImport.parse(text: sheet22, caliber: cal22).movements
        let ledger = Ledger(movements: movements)
        let points = Stats.stock(rows: ledger.rows, caliberID: "22lr", since: nil, until: day(2026, 11, 14))
        #expect(isoDay(points.first!.day) == "2022-12-18")
        #expect(points.first!.total == 400)
        #expect(isoDay(points.last!.day) == "2026-11-14")
        #expect(points.last!.total == 370)
    }

    @Test func statsByWeapon() {
        let w = Weapon(id: "W1", name: "Glock 34", caliberID: "9x21")
        let config = Config(totalLimit: 1000, calibers: [cal9x21], weapons: [w])
        let m1 = Movement(id: "1", date: day(2026, 1, 1), hasTime: false, kind: .shot, provenance: .reloaded,
                          caliberID: "9x21", quantity: 40, weaponID: "W1")
        let m2 = Movement(id: "2", date: day(2026, 1, 8), hasTime: false, kind: .shot, provenance: .reloaded,
                          caliberID: "9x21", quantity: 60, weaponID: "W1")
        let m3 = Movement(id: "3", date: day(2026, 1, 8), hasTime: false, kind: .shot, provenance: .reloaded,
                          caliberID: "9x21", quantity: 10)          // senza arma
        let totals = Stats.byWeapon(movements: [m1, m2, m3], config: config, caliberID: nil, since: nil, includeEmpty: true)
        #expect(totals.first?.weaponID == "W1")
        #expect(totals.first?.shots == 100)
        #expect(totals.first?.sessions == 2)
        #expect(totals.contains { $0.weaponID == nil && $0.shots == 10 })
    }

    // MARK: Configurazione

    @Test func configRoundTripAndForwardCompatibility() throws {
        let config = Config.standard
        let data = try JSONEncoder().encode(config)
        let back = try JSONDecoder().decode(Config.self, from: data)
        #expect(back == config)

        // Un armi.json scritto a mano e incompleto si legge lo stesso, con i valori predefiniti.
        let sparse = Data(#"{"calibers":[{"id":"9x21"}],"weapons":[{"name":"Beretta","caliberID":"9x21"}]}"#.utf8)
        let decoded = try JSONDecoder().decode(Config.self, from: sparse)
        #expect(decoded.calibers.first?.allowsReload == true)
        #expect(decoded.weapons.first?.name == "Beretta")
        #expect(decoded.weapons.first?.isArchived == false)
    }

    @Test func caliberSlug() {
        #expect(Caliber.slug(".22 LR") == "22lr")
        #expect(Caliber.slug("9x21") == "9x21")
        #expect(Caliber.slug("") == "calibro")
    }

    // MARK: Archivio su file (scrittura atomica e backup)

    @Test func archiveWritesAndBacksUp() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("AmmoTrackTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let files = ArchiveFiles(folder: folder)
        try files.prepare()
        let missing = try files.loadMovementsText()
        #expect(missing == nil)

        try files.saveMovements(text: "uno\n", backup: .none)                  // file nuovo: niente da copiare
        let first = try files.loadMovementsText()
        #expect(first == "uno\n")

        try files.saveMovements(text: "due\n", backup: .always)                // modifica: copia del file precedente
        let second = try files.loadMovementsText()
        #expect(second == "due\n")
        let backups = try FileManager.default.contentsOfDirectory(atPath: files.backupURL.path)
        #expect(backups.count == 1)
        let copy = try String(contentsOf: files.backupURL.appendingPathComponent(backups[0]), encoding: .utf8)
        #expect(copy == "uno\n")

        try files.saveMovements(text: "tre\n", backup: .dailyIfNeeded)         // già c'è una copia di oggi: non ne fa altre
        let after = try FileManager.default.contentsOfDirectory(atPath: files.backupURL.path)
        #expect(after.count == 1)
    }
}
