import AppIntents
import JulepKit
import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry, Sendable {
    let date: Date
    let reading: JournalAccess.Reading

    /// What the gallery and the pre-render placeholder show. Redacted by WidgetKit, so the shape
    /// is what matters rather than the words.
    static let placeholder = TodayEntry(
        date: .now,
        reading: .glance(Glance(
            header: DayHeader(weekday: .monday, month: 1, day: 1, year: 2026),
            isCurrent: true,
            items: [
                Glance.OpenItem(lineIndex: 1, item: Item(text: "chase down the rebate")),
                Glance.OpenItem(lineIndex: 2, item: Item(text: "harass landlord")),
            ],
            canRoll: false
        ))
    )
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (TodayEntry) -> Void) {
        Task { completion(TodayEntry(date: .now, reading: await JournalAccess.read())) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TodayEntry>) -> Void) {
        Task {
            let entry = TodayEntry(date: .now, reading: await JournalAccess.read())
            // One entry, refreshed at midnight. Whether the newest block is today's is the only
            // thing here that changes on its own, and it changes exactly then -- so the widget
            // starts asking to be rolled at the start of the day without the app being opened.
            completion(Timeline(entries: [entry], policy: .after(Self.nextMidnight())))
        }
    }

    /// Local midnight: `NaturalDates.today()` is the local calendar day reinterpreted as a
    /// journal day, so the local day boundary is when its answer changes.
    private static func nextMidnight(now: Date = .now) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        return calendar.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60 * 60)
    }
}

/// Brings everything still open forward onto today, from the widget's own process.
///
/// Deliberately does not open the app: rolling forward should cost one action, and a launch in
/// the middle of it is the cost this removes. See `JournalAccess.roll` for why a second tap is
/// harmless.
struct RollIntent: AppIntent {
    static let title: LocalizedStringResource = "Roll"
    static let description = IntentDescription("Bring everything still open forward onto today.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        try await JournalAccess.roll()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Moves one item into `done`, from the widget's own process.
///
/// The margin's affordance, on the home screen. Which item it means is worked out against the
/// file as it stands rather than as the widget drew it -- see `JournalAccess.markDone`.
struct MarkDoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark done"
    static let description = IntentDescription("Move an item into the day's done section.")
    static let openAppWhenRun = false

    @Parameter(title: "Line") var lineIndex: Int
    @Parameter(title: "Item") var text: String

    init() {}

    init(lineIndex: Int, text: String) {
        self.lineIndex = lineIndex
        self.text = text
    }

    func perform() async throws -> some IntentResult {
        try await JournalAccess.markDone(lineIndex: lineIndex, text: text)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.quipsoteric.julep.today", provider: TodayProvider()) { entry in
            TodayView(reading: entry.reading)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("What is still open, and whether today's block has been rolled yet.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct JulepWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}
