import WidgetKit
import SwiftUI

// MARK: - Days Together Widget

struct DaysTogetherProvider: TimelineProvider {
    func placeholder(in context: Context) -> DaysTogetherEntry {
        DaysTogetherEntry(date: Date(), durationText: "1468 Days 07:23:41", imagePath: nil)
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
        let renderPath = userDefaults?.string(forKey: "days_together_render_path")
        let startTimestamp = userDefaults?.string(forKey: "start_timestamp")
        let cachedText = userDefaults?.string(forKey: "duration_text")

        var text = "0 Days 00:00:00"
        if let startTimestamp = startTimestamp, let start = parseISO(startTimestamp) {
            text = calculateDuration(from: start, to: date)
        } else if let cachedText = cachedText, !cachedText.isEmpty {
            text = cachedText
        }

        return DaysTogetherEntry(date: date, durationText: text, imagePath: renderPath)
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
    let imagePath: String?
}

struct DaysTogetherWidgetEntryView : View {
    var entry: DaysTogetherProvider.Entry

    var body: some View {
        Group {
            if let path = entry.imagePath, let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.06, green: 0.07, blue: 0.17))
            }
        }
        .widgetURL(URL(string: "daystogether://duration"))
    }
}

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

// MARK: - NoteIt Widget

struct NoteitProvider: TimelineProvider {
    func placeholder(in context: Context) -> NoteitEntry {
        NoteitEntry(date: Date(), imagePath: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NoteitEntry) -> ()) {
        let entry = createEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NoteitEntry>) -> ()) {
        let currentDate = Date()
        let entry = createEntry(for: currentDate)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate) ?? currentDate.addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func createEntry(for date: Date) -> NoteitEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.szacheo.days_together")
        let renderPath = userDefaults?.string(forKey: "noteit_render_path")
        return NoteitEntry(date: date, imagePath: renderPath)
    }
}

struct NoteitEntry: TimelineEntry {
    let date: Date
    let imagePath: String?
}

struct NoteitWidgetEntryView : View {
    var entry: NoteitProvider.Entry

    var body: some View {
        Group {
            if let path = entry.imagePath, let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 0.91, green: 0.28, blue: 0.49))
                    Text("NoteIt")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Tap to draw note 💕")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.06, green: 0.07, blue: 0.17))
            }
        }
        .widgetURL(URL(string: "daystogether://noteit"))
    }
}

struct NoteitWidget: Widget {
    let kind: String = "NoteitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NoteitProvider()) { entry in
            NoteitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NoteIt Partner Note")
        .description("Displays your partner's latest handwritten drawing note.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Bundle Entry Point

@main
struct DaysTogetherWidgetBundle: WidgetBundle {
    var body: some Widget {
        DaysTogetherWidget()
        NoteitWidget()
    }
}
