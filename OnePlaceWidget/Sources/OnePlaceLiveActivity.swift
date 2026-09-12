import ActivityKit
import SwiftUI
import WidgetKit

struct OnePlaceTasksWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.one-place.app.widget.tasks", provider: OnePlaceTasksTimelineProvider()) { entry in
            OnePlaceTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("OnePlace Tasks")
        .description("Keep your tasks handy on your Home Screen or Lock Screen, even after a Live Activity ends.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

private struct OnePlaceTasksEntry: TimelineEntry {
    let date: Date
    let tasks: [OnePlaceLiveTask]
}

private struct OnePlaceTasksTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> OnePlaceTasksEntry {
        OnePlaceTasksEntry(
            date: .now,
            tasks: [
                OnePlaceLiveTask(id: "sample-1", title: "Plan the day", isCompleted: false, priority: .normal),
                OnePlaceLiveTask(id: "sample-2", title: "Call the bank", isCompleted: false, priority: .high)
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (OnePlaceTasksEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OnePlaceTasksEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private func entry() -> OnePlaceTasksEntry {
        OnePlaceTasksEntry(
            date: .now,
            tasks: OnePlaceTaskCache.load()
                .filter { !$0.isCompleted }
                .sortedForWidget()
        )
    }
}

private struct OnePlaceTasksWidgetView: View {
    let entry: OnePlaceTasksEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 3) {
                    Label("\(entry.tasks.count) open tasks", systemImage: "checklist")
                        .font(.headline)
                    ForEach(entry.tasks.prefix(2)) { task in
                        Text(task.title).font(.caption).lineLimit(1)
                    }
                    if entry.tasks.isEmpty { Text("All clear. Enjoy your day.").font(.caption) }
                }
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 1) {
                        Image(systemName: "checklist").font(.caption)
                        Text("\(entry.tasks.count)").font(.headline)
                    }
                }
                .accessibilityLabel("\(entry.tasks.count) open tasks")
            case .accessoryInline:
                Label(entry.tasks.first?.title ?? "All tasks complete", systemImage: "checklist")
            default:
                homeScreenContent
            }
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(OnePlaceDeepLink.tasks)
    }

    private var homeScreenContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Tasks", systemImage: "checklist")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(entry.tasks.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.teal)
            }

            if entry.tasks.isEmpty {
                Spacer()
                Label("All clear", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.tasks.prefix(4)) { task in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(priorityColor(for: task.priority))
                                .frame(width: 6, height: 6)
                            Text(task.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func priorityColor(for priority: OnePlaceLivePriority) -> Color {
        switch priority {
        case .high: return .orange
        case .normal, .none: return .teal
        case .low: return .blue
        }
    }
}

struct OnePlaceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OnePlaceActivityAttributes.self) { context in
            OnePlaceLockScreenView(state: context.state)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("OnePlace", systemImage: "checklist")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(openTasks(in: context.state).count) open")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(openTasks(in: context.state).prefix(4)) { task in
                            OnePlaceLiveTaskRow(task: task, density: .balanced, showsDueDate: false)
                        }

                        if openTasks(in: context.state).count > 4 {
                            Text("+\(openTasks(in: context.state).count - 4) more")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                    .widgetURL(OnePlaceDeepLink.tasks)
                }
            } compactLeading: {
                Image(systemName: "checklist")
                    .foregroundStyle(.teal)
            } compactTrailing: {
                Text("\(openTasks(in: context.state).count)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
            } minimal: {
                Image(systemName: "checklist")
                    .foregroundStyle(.teal)
            }
        }
    }
}

private extension Array where Element == OnePlaceLiveTask {
    func sortedForWidget() -> [OnePlaceLiveTask] {
        sorted {
            if $0.priority != $1.priority {
                return $0.priority.rawValue > $1.priority.rawValue
            }

            if let leftOrder = $0.manualOrder,
               let rightOrder = $1.manualOrder,
               leftOrder != rightOrder {
                return leftOrder < rightOrder
            }

            if let leftDue = $0.dueDate, let rightDue = $1.dueDate {
                return leftDue < rightDue
            }

            if $0.dueDate != nil {
                return true
            }

            if $1.dueDate != nil {
                return false
            }

            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }
}

private func openTasks(in state: OnePlaceActivityAttributes.ContentState) -> [OnePlaceLiveTask] {
    state.tasks.filter { !$0.isCompleted }
}

private struct OnePlaceLockScreenView: View {
    let state: OnePlaceActivityAttributes.ContentState

    private var visibleTasks: [OnePlaceLiveTask] { openTasks(in: state) }
    private var totalOpenCount: Int { max(state.totalOpenCount, visibleTasks.count) }
    private var hiddenCount: Int { max(0, totalOpenCount - visibleTasks.count) }

    var body: some View {
        Group {
            if totalOpenCount <= 4 {
                ViewThatFits(in: .vertical) {
                    activityBody(density: .roomy)
                    activityBody(density: .balanced)
                    activityBody(density: .dense)
                }
            } else if totalOpenCount <= 8 {
                ViewThatFits(in: .vertical) {
                    activityBody(density: .balanced)
                    activityBody(density: .dense)
                }
            } else {
                activityBody(density: .dense)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(OnePlaceDeepLink.tasks)
    }

    private var footerText: String {
        if totalOpenCount == 0 { return "All clear" }
        if hiddenCount > 0 { return "\(visibleTasks.count) of \(totalOpenCount) open" }
        return totalOpenCount == 1 ? "1 open task" : "\(totalOpenCount) open tasks"
    }

    private func activityBody(density: OnePlaceLiveActivityDensity) -> some View {
        VStack(alignment: .leading, spacing: density.sectionSpacing) {
            header(density: density)

            if visibleTasks.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: density.rowFontSize, weight: .semibold))
                        .foregroundStyle(.teal)
                    Text("No open tasks")
                        .font(.system(size: density.rowFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .frame(height: density.rowHeight, alignment: .center)
            } else {
                taskGrid(density: density)
            }
        }
        .padding(.horizontal, density.horizontalPadding)
        .padding(.vertical, density.verticalPadding)
    }

    private func header(density: OnePlaceLiveActivityDensity) -> some View {
        HStack(spacing: density.headerSpacing) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.teal, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "checklist")
                    .font(.system(size: density.iconGlyphSize, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: density.iconSize, height: density.iconSize)

            VStack(alignment: .leading, spacing: 0) {
                Text("OnePlace")
                    .font(.system(size: density.titleSize, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(footerText)
                    .font(.system(size: density.subtitleSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(totalOpenCount)")
                .font(.system(size: density.ringFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: density.ringSize, height: density.ringSize)
                .background(Circle().stroke(Color.secondary.opacity(0.32), lineWidth: density.ringWidth))
        }
    }

    @ViewBuilder
    private func taskGrid(density: OnePlaceLiveActivityDensity) -> some View {
        let displayTasks = Array(visibleTasks.prefix(density.maxCells))
        let overflowCount = max(0, totalOpenCount - displayTasks.count)

        LazyVGrid(columns: density.columns, alignment: .leading, spacing: density.rowSpacing) {
            ForEach(displayTasks) { task in
                OnePlaceLiveTaskRow(task: task, density: density, showsDueDate: density == .roomy)
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(size: density.rowFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(height: density.rowHeight)
            }
        }
    }
}

private struct OnePlaceLiveTaskRow: View {
    let task: OnePlaceLiveTask
    var density: OnePlaceLiveActivityDensity = .roomy
    var showsDueDate: Bool = true

    var body: some View {
        Button(intent: ToggleOnePlaceTaskIntent(taskID: task.id)) {
            HStack(spacing: density.rowIconSpacing) {
                checkmark

                VStack(alignment: .leading, spacing: 0) {
                    Text(task.title)
                        .font(.system(size: density.rowFontSize, weight: .medium, design: .rounded))
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if showsDueDate, let dueDate = task.dueDate, !task.isCompleted {
                        Text(dueText(dueDate))
                            .font(.system(size: density.captionSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(height: density.rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(task.isCompleted ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .tint(.primary)
        .clipped()
    }

    private var checkmark: some View {
        ZStack {
            Circle()
                .stroke(task.isCompleted ? priorityColor : Color.secondary.opacity(0.45), lineWidth: 2)
                .frame(width: density.checkSize, height: density.checkSize)

            if task.isCompleted {
                Circle()
                    .fill(priorityColor)
                    .frame(width: density.checkSize, height: density.checkSize)
                Image(systemName: "checkmark")
                    .font(.system(size: density.checkSize * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: density.hitSize, height: density.rowHeight)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .none, .normal: return .teal
        case .low: return .blue
        case .high: return .orange
        }
    }

    private func dueText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.month().day())
    }
}

private enum OnePlaceLiveActivityDensity: Equatable {
    case roomy
    case balanced
    case dense

    var columns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0), spacing: columnSpacing),
            GridItem(.flexible(minimum: 0), spacing: columnSpacing)
        ]
    }

    var horizontalPadding: CGFloat { self == .roomy ? 13 : self == .balanced ? 12 : 11 }
    var verticalPadding: CGFloat { self == .roomy ? 9 : self == .balanced ? 8 : 7 }
    var sectionSpacing: CGFloat { self == .roomy ? 8 : self == .balanced ? 7 : 5 }
    var rowSpacing: CGFloat { self == .roomy ? 3 : self == .balanced ? 2 : 1 }
    var columnSpacing: CGFloat { self == .roomy ? 10 : self == .balanced ? 9 : 8 }
    var headerSpacing: CGFloat { self == .roomy ? 9 : self == .balanced ? 8 : 7 }
    var iconSize: CGFloat { self == .roomy ? 28 : self == .balanced ? 25 : 22 }
    var iconGlyphSize: CGFloat { self == .roomy ? 13 : self == .balanced ? 12 : 10 }
    var titleSize: CGFloat { self == .roomy ? 17 : self == .balanced ? 16 : 14 }
    var subtitleSize: CGFloat { self == .roomy ? 12 : self == .balanced ? 11 : 10 }
    var rowHeight: CGFloat { self == .roomy ? 31 : self == .balanced ? 24 : 18 }
    var rowFontSize: CGFloat { self == .roomy ? 15 : self == .balanced ? 13 : 11 }
    var captionSize: CGFloat { self == .roomy ? 11 : self == .balanced ? 10 : 9 }
    var checkSize: CGFloat { self == .roomy ? 22 : self == .balanced ? 19 : 15 }
    var hitSize: CGFloat { self == .roomy ? 30 : self == .balanced ? 25 : 20 }
    var rowIconSpacing: CGFloat { self == .roomy ? 9 : self == .balanced ? 7 : 5 }
    var ringSize: CGFloat { self == .roomy ? 28 : self == .balanced ? 25 : 22 }
    var ringWidth: CGFloat { self == .roomy ? 3 : self == .balanced ? 2.6 : 2.3 }
    var ringFontSize: CGFloat { self == .roomy ? 9 : self == .balanced ? 8 : 7 }
    var maxCells: Int { self == .roomy ? 4 : self == .balanced ? 8 : 12 }
}
