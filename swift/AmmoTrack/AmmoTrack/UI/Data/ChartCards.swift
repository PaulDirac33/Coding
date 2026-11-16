//
//  ChartCards.swift
//
//  I singoli grafici (Swift Charts) in schede di vetro: giacenza nel tempo, spari e entrate per mese,
//  colpi per arma, distribuzione dei colpi per uscita, più i riquadri riassuntivi.
//  Il passaggio del mouse (o il tocco, su iOS) mostra i valori: chartXSelection + annotazione.
//

import SwiftUI
import Charts

// MARK: - Contenitore e piccoli pezzi

/// Scheda di vetro con titolo, legenda a destra e il grafico.
struct ChartCard<Accessory: View, Content: View>: View {
    let title: String
    let subtitle: String?
    let accessory: Accessory
    let content: Content

    init(title: String,
         subtitle: String? = nil,
         @ViewBuilder accessory: () -> Accessory,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 8)
                accessory
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 22)
    }
}

extension ChartCard where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, accessory: { EmptyView() }, content: content)
    }
}

/// Quadratino per le barre, trattino per le linee.
struct LegendItem: View {
    let color: Color
    var line = false
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            if line {
                Capsule()
                    .fill(color)
                    .frame(width: 18, height: 4)
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 11, height: 11)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(Palette.muted)
        }
    }
}

struct EmptyChart: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, minHeight: 120)
    }
}

struct TooltipRow: Identifiable {
    let color: Color?
    let label: String
    let value: String
    var id: String { label }
}

/// Banner dei valori: vetro fumé scuro, leggibile qualunque cosa ci sia dietro.
struct ChartTooltip: View {
    let title: String
    let rows: [TooltipRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
            ForEach(rows) { r in
                HStack(spacing: 8) {
                    if let c = r.color {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(c)
                            .frame(width: 10, height: 10)
                    } else {
                        Color.clear.frame(width: 10, height: 10)
                    }
                    Text(r.label)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.75))
                    Spacer(minLength: 10)
                    Text(r.value)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.white)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.06).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
        )
    }
}

/// Per le frequenze mostro solo tick interi (0, 10, 20 ...), mai 2.5.
func isWhole(_ value: AxisValue) -> Bool {
    guard let v = value.as(Double.self) else { return true }
    return abs(v - v.rounded()) < 1e-9
}
/// Testo di un'etichetta numerica dell'asse, con i separatori del sistema.
func axisNumberText(_ value: AxisValue) -> String {
    if let n = value.as(Int.self) { return numText(n) }
    if let d = value.as(Double.self) { return decimalText(d) }
    return ""
}

/// Asse Y con le linee della griglia e fondo leggero del grafico (come nell'altra app).
func gridPlot<C: View>(_ chart: C, integerY: Bool = true) -> some View {
    chart
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if !integerY || isWhole(value) {
                    AxisGridLine().foregroundStyle(Palette.grid)
                    AxisValueLabel { Text(axisNumberText(value)) }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.background(Color.white.opacity(0.03))
        }
}

/// Un grafico a barre/linee per mese: etichette dei mesi più rade se i mesi sono tanti.
func monthAxisStride(_ count: Int) -> Int {
    if count <= 12 { return 1 }
    if count <= 30 { return 3 }
    return 6
}

func monthAxisFormat(_ count: Int) -> Date.FormatStyle {
    if count <= 12 {
        return Date.FormatStyle().month(.abbreviated)
    }
    return Date.FormatStyle().month(.abbreviated).year(.twoDigits)
}

// MARK: - Riquadri riassuntivi

struct StatTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Palette.muted)
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(cornerRadius: 20)
    }
}

struct SummaryStrip: View {
    let summary: Summary

    private var lastText: String {
        guard let d = summary.lastSession else { return "—" }
        return dayText(d)
    }

    private var lastDetail: String {
        guard let d = summary.lastSession else { return "nessuno sparo nel periodo" }
        let days = Cal.cal.dateComponents([.day], from: Cal.startOfDay(d), to: Cal.startOfDay(Date())).day ?? 0
        if days <= 0 { return "oggi" }
        return days == 1 ? "ieri" : "\(days) giorni fa"
    }

    private var runwayText: String {
        guard let m = summary.runwayMonths else { return "—" }
        if m < 1 { return "< 1 mese" }
        return "≈ \(decimalText(m)) mesi"
    }

    private var runwayDetail: String {
        guard summary.runwayMonths != nil else { return "serve almeno uno sparo" }
        return "\(numText(summary.stock.total)) in giacenza, \(decimalText(summary.monthlyRate, maxFraction: 0)) colpi/mese"
    }

    var body: some View {
        HStack(spacing: 14) {
            StatTile(title: "Colpi sparati",
                     value: numText(summary.shots),
                     detail: "\(numText(summary.shotsReloaded)) ricaricate · \(numText(summary.shotsBought)) comprate")
            StatTile(title: "Uscite",
                     value: numText(summary.sessions),
                     detail: summary.sessions > 0
                        ? "in media \(decimalText(summary.averagePerSession, maxFraction: 0)) colpi a uscita"
                        : "nessuna nel periodo")
            StatTile(title: "Ultima uscita", value: lastText, detail: lastDetail)
            StatTile(title: "Autonomia", value: runwayText, detail: runwayDetail)
        }
    }
}

// MARK: - Giacenza nel tempo

struct StockCard: View {
    let points: [DayBalance]
    let limit: Int?
    let limitLabel: String

    @State private var selected: Date? = nil

    private var topValue: Int {
        let peak = max(points.map { $0.total }.max() ?? 0, limit ?? 0)
        return max(10, peak + max(1, peak / 12))
    }

    private var selectedPoint: DayBalance? {
        guard let s = selected else { return nil }
        return points.last(where: { $0.day <= s }) ?? points.first
    }

    private var legend: some View {
        HStack(spacing: 14) {
            LegendItem(color: Palette.reloaded, text: "Ricaricate")
            LegendItem(color: Palette.bought, text: "Comprate")
            if limit != nil {
                LegendItem(color: Color.white.opacity(0.6), line: true, text: limitLabel)
            }
        }
    }

    var body: some View {
        ChartCard(title: "Giacenza nel tempo", accessory: { legend }) {
            if points.isEmpty {
                EmptyChart(text: "Nessun dato nel periodo")
            } else {
                chart
            }
        }
    }

    private var chart: some View {
        let top = topValue
        let styled = Chart {
            ForEach(points) { p in
                AreaMark(x: .value("Data", p.day),
                         y: .value("Cartucce", max(p.reloaded, 0)),
                         series: .value("Provenienza", Provenance.reloaded.label),
                         stacking: .standard)
                    .foregroundStyle(by: .value("Provenienza", Provenance.reloaded.label))
                    .interpolationMethod(.stepEnd)
                AreaMark(x: .value("Data", p.day),
                         y: .value("Cartucce", max(p.bought, 0)),
                         series: .value("Provenienza", Provenance.bought.label),
                         stacking: .standard)
                    .foregroundStyle(by: .value("Provenienza", Provenance.bought.label))
                    .interpolationMethod(.stepEnd)
            }
            if let limit {
                RuleMark(y: .value("Limite", limit))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
            }
            if let sel = selectedPoint {
                RuleMark(x: .value("Data", sel.day))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .annotation(position: .top, spacing: 4) {
                        ChartTooltip(title: dayText(sel.day),
                                     rows: [TooltipRow(color: Palette.reloaded, label: "Ricaricate", value: numText(sel.reloaded)),
                                            TooltipRow(color: Palette.bought, label: "Comprate", value: numText(sel.bought)),
                                            TooltipRow(color: nil, label: "Totale", value: numText(sel.total))])
                    }
            }
        }
        .chartForegroundStyleScale(domain: [Provenance.reloaded.label, Provenance.bought.label],
                                   range: [Palette.reloaded, Palette.bought])
        .chartLegend(.hidden)
        .chartYScale(domain: 0...top)
        .chartXSelection(value: $selected)
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Palette.grid)
                AxisValueLabel()
            }
        }
        return gridPlot(styled)
            .frame(height: 240)
    }
}

// MARK: - Mesi (spari o entrate)

struct MonthlyCard: View {
    let title: String
    let buckets: [MonthBucket]
    let emptyText: String
    var showAverage = false

    @State private var selected: Date? = nil

    private var selectedBucket: MonthBucket? {
        guard let s = selected else { return nil }
        return buckets.first { Cal.sameMonth($0.month, s) }
    }

    private var average: Int {
        guard !buckets.isEmpty else { return 0 }
        let sum = buckets.reduce(0) { $0 + $1.total }
        return Int((Double(sum) / Double(buckets.count)).rounded())
    }

    private var topValue: Int {
        let peak = max(buckets.map { $0.total }.max() ?? 0, showAverage ? average : 0)
        return max(10, peak + max(1, peak / 10))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            LegendItem(color: Palette.reloaded, text: "Ricaricate")
            LegendItem(color: Palette.bought, text: "Comprate")
            if showAverage {
                LegendItem(color: Color.white.opacity(0.6), line: true, text: "Media \(numText(average))/mese")
            }
        }
    }

    var body: some View {
        ChartCard(title: title, accessory: { legend }) {
            if buckets.allSatisfy({ $0.total == 0 }) {
                EmptyChart(text: emptyText)
            } else {
                chart
            }
        }
    }

    private var chart: some View {
        let top = topValue
        let count = buckets.count
        let styled = Chart {
            ForEach(buckets) { b in
                BarMark(x: .value("Mese", b.month, unit: .month),
                        y: .value("Colpi", b.reloaded))
                    .foregroundStyle(by: .value("Provenienza", Provenance.reloaded.label))
                BarMark(x: .value("Mese", b.month, unit: .month),
                        y: .value("Colpi", b.bought))
                    .foregroundStyle(by: .value("Provenienza", Provenance.bought.label))
            }
            if showAverage {
                RuleMark(y: .value("Media", average))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
            }
            if let sel = selectedBucket {
                RuleMark(x: .value("Mese", sel.month, unit: .month))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .annotation(position: .top, spacing: 4) {
                        ChartTooltip(title: sel.month.formatted(.dateTime.month(.wide).year()),
                                     rows: [TooltipRow(color: Palette.reloaded, label: "Ricaricate", value: numText(sel.reloaded)),
                                            TooltipRow(color: Palette.bought, label: "Comprate", value: numText(sel.bought)),
                                            TooltipRow(color: nil, label: "Totale", value: numText(sel.total))])
                    }
            }
        }
        .chartForegroundStyleScale(domain: [Provenance.reloaded.label, Provenance.bought.label],
                                   range: [Palette.reloaded, Palette.bought])
        .chartLegend(.hidden)
        .chartYScale(domain: 0...top)
        .chartXSelection(value: $selected)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: monthAxisStride(count))) { _ in
                AxisGridLine().foregroundStyle(Palette.grid)
                AxisValueLabel(format: monthAxisFormat(count))
            }
        }
        return gridPlot(styled)
            .frame(height: 220)
    }
}

// MARK: - Colpi per arma

struct WeaponsCard: View {
    let items: [WeaponTotal]

    var body: some View {
        ChartCard(title: "Colpi per arma", subtitle: "nel periodo") {
            if items.isEmpty {
                EmptyChart(text: "Nessuno sparo nel periodo")
            } else {
                chart
            }
        }
    }

    private var chart: some View {
        Chart(items) { w in
            BarMark(x: .value("Colpi", w.shots),
                    y: .value("Arma", w.name))
                .foregroundStyle(Palette.data.opacity(0.75))
                .annotation(position: .trailing) {
                    Text("\(numText(w.shots)) · \(w.sessions) usc.")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(Palette.grid)
                AxisValueLabel { Text(axisNumberText(value)) }
            }
        }
        .chartPlotStyle { plot in
            plot.background(Color.white.opacity(0.03))
        }
        .frame(height: CGFloat(max(110, items.count * 46 + 34)))
    }
}

// MARK: - Distribuzione dei colpi per uscita

struct HistogramCard: View {
    let bins: [HistBin]
    let sessionCount: Int
    @Binding var binSize: Int

    static let binSizes = [10, 25, 50, 100]

    @State private var selected: Double? = nil

    private var maxEnd: Double {
        Double(bins.map { $0.end }.max() ?? 1)
    }

    private var topValue: Int {
        let peak = bins.map { $0.count }.max() ?? 1
        return max(2, peak + max(1, peak / 8))
    }

    private var selectedBin: HistBin? {
        guard let s = selected else { return nil }
        return bins.first { Double($0.start) <= s && s < Double($0.end) }
    }

    private var sizePicker: some View {
        HStack(spacing: 8) {
            Text("Ampiezza")
                .font(.caption)
                .foregroundStyle(Palette.muted)
            GlassSegmented(options: HistogramCard.binSizes,
                           selection: $binSize,
                           segmentWidth: 48) { n, selected in
                glassLabel("\(n)", selected: selected)
            }
        }
    }

    var body: some View {
        ChartCard(title: "Distribuzione dei colpi per uscita", accessory: { sizePicker }) {
            if bins.isEmpty {
                EmptyChart(text: "Nessuno sparo nel periodo")
            } else {
                chart
            }
        }
    }

    private var chart: some View {
        let gap = Double(binSize) * 0.04
        let top = topValue
        let upper = maxEnd
        let styled = Chart {
            ForEach(bins) { b in
                RectangleMark(xStart: .value("Da", Double(b.start) + gap),
                              xEnd: .value("A", Double(b.end) - gap),
                              yStart: .value("Zero", 0),
                              yEnd: .value("Uscite", b.count))
                    .foregroundStyle(Palette.data.opacity(0.70))
            }
            if let sel = selectedBin {
                RectangleMark(xStart: .value("Da", Double(sel.start) + gap),
                              xEnd: .value("A", Double(sel.end) - gap),
                              yStart: .value("Zero", 0),
                              yEnd: .value("Uscite", sel.count))
                    .foregroundStyle(Palette.data)
                    .annotation(position: .top, spacing: 4) {
                        ChartTooltip(title: "\(numText(sel.start)) – \(numText(sel.end - 1)) colpi",
                                     rows: [TooltipRow(color: Palette.data, label: "Uscite", value: "\(sel.count)"),
                                            TooltipRow(color: nil, label: "Quota",
                                                       value: share(sel.count))])
                    }
            }
        }
        .chartXScale(domain: 0...upper)
        .chartYScale(domain: 0...top)
        .chartXSelection(value: $selected)
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(Palette.grid)
                AxisValueLabel { Text(axisNumberText(value)) }
            }
        }
        return gridPlot(styled)
            .frame(height: 220)
    }

    private func share(_ count: Int) -> String {
        guard sessionCount > 0 else { return "—" }
        let v = Double(count) / Double(sessionCount)
        return v.formatted(.percent.precision(.fractionLength(0...1)))
    }
}
