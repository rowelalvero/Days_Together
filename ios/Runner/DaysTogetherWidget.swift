import WidgetKit
import SwiftUI

struct DaysTogetherProvider: TimelineProvider {
    func placeholder(in context: Context) -> DaysTogetherEntry {
        DaysTogetherEntry(date: Date(), durationText: "1468 Days 07:23:41")
    }

    func getSnapshot(in context: Context, completion: @escaping (DaysTogetherEntry) -> ()) {
        let entry = createEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaysTogetherEntry>) -> ()) {
        let currentDate = Date()
        let entry = createEntry(for: currentDate)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate.addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func createEntry(for date: Date) -> DaysTogetherEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.szacheo.days_together")
        let startTimestamp = userDefaults?.string(forKey: "start_timestamp")
        let cachedText = userDefaults?.string(forKey: "duration_text")

        if let startTimestamp = startTimestamp, let start = parseISO(startTimestamp) {
            let text = calculateDuration(from: start, to: date)
            return DaysTogetherEntry(date: date, durationText: text)
        } else if let cachedText = cachedText, !cachedText.isEmpty {
            return DaysTogetherEntry(date: date, durationText: cachedText)
        } else {
            return DaysTogetherEntry(date: date, durationText: "0 Days 00:00:00")
        }
    }

    private func parseISO(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: string) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func calculateDuration(from start: Date, to current: Date) -> String {
        let diff = current.timeIntervalSince(start)
        if diff <= 0 { return "0 Days 00:00:00" }

        let totalSeconds = Int(diff)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%d Days %02d:%02d:%02d", days, hours, minutes, seconds)
    }
}

struct DaysTogetherEntry: TimelineEntry {
    let date: Date
    let durationText: String
}

struct DaysTogetherWidgetEntryView : View {
    var entry: DaysTogetherProvider.Entry

    var body: some View {
        VStack(spacing: 4) {
            Text("Days Together")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(red: 0.91, green: 0.28, blue: 0.49))
            Text(entry.durationText)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(red: 0.06, green: 0.07, blue: 0.17))
    }
}

@main
struct DaysTogetherWidget: Widget {
    let kind: String = "DaysTogetherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DaysTogetherProvider()) { entry in
            DaysTogetherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Days Together")
        .description("Displays elapsed relationship duration.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
