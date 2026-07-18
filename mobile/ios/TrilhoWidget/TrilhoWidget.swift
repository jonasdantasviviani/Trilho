import WidgetKit
import SwiftUI

struct TrilhoEntry: TimelineEntry {
    let date: Date
    let lineName: String
    let status: String
    let statusColor: String
    let crowdLevel: String
    let lastUpdated: String
}

struct TrilhoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrilhoEntry {
        TrilhoEntry(
            date: Date(),
            lineName: "Linha 4 - Amarela",
            status: "Operando",
            statusColor: "#4CAF50",
            crowdLevel: "Média",
            lastUpdated: "agora"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TrilhoEntry) -> Void) {
        let entry = TrilhoEntry(
            date: Date(),
            lineName: UserDefaults(suiteName: "group.com.trilho.trilho")?.string(forKey: "lineName") ?? "Selecione uma linha",
            status: UserDefaults(suiteName: "group.com.trilho.trilho")?.string(forKey: "status") ?? "Carregando...",
            statusColor: UserDefaults(suiteName: "group.com.trilho.trilho")?.string(forKey: "statusColor") ?? "#4CAF50",
            crowdLevel: UserDefaults(suiteName: "group.com.trilho.trilho")?.string(forKey: "crowdLevel") ?? "-",
            lastUpdated: UserDefaults(suiteName: "group.com.trilho.trilho")?.string(forKey: "lastUpdated") ?? ""
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrilhoEntry>) -> Void) {
        let entry = TrilhoEntry(
            date: Date(),
            lineName: UserDefaults(suiteName: "group.com.trilho.trilho")?.string(forKey: "lineName") ?? "Selecione uma linha",
            status: UserDefaults(suiteName: "group.com.trilho.trilho")?.string(forKey: "status") ?? "Carregando...",
            statusColor: UserDefaults(suiteName: "group.com.trilho.trilho")?.string(forKey: "statusColor") ?? "#4CAF50",
            crowdLevel: UserDefaults(suiteName: "group.com.trilho.trilho")?.string(forKey: "crowdLevel") ?? "-",
            lastUpdated: UserDefaults(suiteName: "group.com.trilho.trilho")?.string(forKey: "lastUpdated") ?? ""
        )
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct TrilhoWidgetEntryView: View {
    var entry: TrilhoProvider.Entry

    var statusColor: Color {
        let hex = entry.statusColor.replacingOccurrences(of: "#", with: "")
        return Color(hex: String(hex)) ?? .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundColor(.blue)
                Text("Trilho")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
            }
            
            Text(entry.lineName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(entry.status)
                    .font(.caption)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                Text("Lotação: \(entry.crowdLevel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Atualizado: \(entry.lastUpdated)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct TrilhoWidget: Widget {
    let kind: String = "TrilhoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrilhoProvider()) { entry in
            TrilhoWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Trilho Status")
        .description("Veja o status das linhas de metrô e CPTM.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

#Preview(as: .systemSmall) {
    TrilhoWidget()
} timeline: {
    TrilhoEntry(
        date: Date(),
        lineName: "Linha 4 - Amarela",
        status: "Operando",
        statusColor: "#4CAF50",
        crowdLevel: "Média",
        lastUpdated: "agora"
    )
}
