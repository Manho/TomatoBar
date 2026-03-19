import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

extension KeyboardShortcuts.Name {
    static let startStopTimer = Self("startStopTimer")
}

private func localizedTargetText(setNumber: Int, pomodoroNumber: Int) -> String {
    let format = NSLocalizedString("StatsView.target.format", comment: "Target format")
    return String.localizedStringWithFormat(format, setNumber, pomodoroNumber)
}

private func heatmapDateText(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

private func localizedTomatoTreeCountText(_ count: Int) -> String {
    let format = NSLocalizedString("StatsView.heatmap.tomatoTrees.format", comment: "Tomato tree count text")
    return String.localizedStringWithFormat(format, count)
}

private struct IntervalsView: View {
    @EnvironmentObject var timer: TBTimer
    private var minStr = NSLocalizedString("IntervalsView.min", comment: "min")

    var body: some View {
        VStack {
            Stepper(value: $timer.workIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.workIntervalLength.label",
                                           comment: "Work interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.workIntervalLength))
                }
            }
            Stepper(value: $timer.shortRestIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.shortRestIntervalLength.label",
                                           comment: "Short rest interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.shortRestIntervalLength))
                }
            }
            Stepper(value: $timer.longRestIntervalLength, in: 1 ... 60) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.longRestIntervalLength.label",
                                           comment: "Long rest interval label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String.localizedStringWithFormat(minStr, timer.longRestIntervalLength))
                }
            }
            .help(NSLocalizedString("IntervalsView.longRestIntervalLength.help",
                                    comment: "Long rest interval hint"))
            Stepper(value: $timer.workIntervalsInSet, in: 1 ... 10) {
                HStack {
                    Text(NSLocalizedString("IntervalsView.workIntervalsInSet.label",
                                           comment: "Work intervals in a set label"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(timer.workIntervalsInSet)")
                }
            }
            .help(NSLocalizedString("IntervalsView.workIntervalsInSet.help",
                                    comment: "Work intervals in set hint"))
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

private struct SettingsView: View {
    @EnvironmentObject var timer: TBTimer
    @ObservedObject private var launchAtLogin = LaunchAtLogin.observable

    var body: some View {
        VStack {
            KeyboardShortcuts.Recorder(for: .startStopTimer) {
                Text(NSLocalizedString("SettingsView.shortcut.label",
                                       comment: "Shortcut label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle(isOn: $timer.stopAfterBreak) {
                Text(NSLocalizedString("SettingsView.stopAfterBreak.label",
                                       comment: "Stop after break label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            Toggle(isOn: $timer.showTimerInMenuBar) {
                Text(NSLocalizedString("SettingsView.showTimerInMenuBar.label",
                                       comment: "Show timer in menu bar label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
                .onChange(of: timer.showTimerInMenuBar) { _ in
                    timer.updateTimeLeft()
                }
            Toggle(isOn: $launchAtLogin.isEnabled) {
                Text(NSLocalizedString("SettingsView.launchAtLogin.label",
                                       comment: "Launch at login label"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.switch)
            Spacer().frame(minHeight: 0)
        }
        .padding(4)
    }
}

private struct VolumeSlider: View {
    @Binding var volume: Double

    var body: some View {
        Slider(value: $volume, in: 0...2) {
            Text(String(format: "%.1f", volume))
        }.gesture(TapGesture(count: 2).onEnded({
            volume = 1.0
        }))
    }
}

private struct SoundsView: View {
    @EnvironmentObject var player: TBPlayer

    private var columns = [
        GridItem(.flexible()),
        GridItem(.fixed(110))
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            Text(NSLocalizedString("SoundsView.isWindupEnabled.label",
                                   comment: "Windup label"))
            VolumeSlider(volume: $player.windupVolume)
            Text(NSLocalizedString("SoundsView.isDingEnabled.label",
                                   comment: "Ding label"))
            VolumeSlider(volume: $player.dingVolume)
            Text(NSLocalizedString("SoundsView.isTickingEnabled.label",
                                   comment: "Ticking label"))
            VolumeSlider(volume: $player.tickingVolume)
        }.padding(4)
        Spacer().frame(minHeight: 0)
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

private struct StatsSectionView: View {
    let title: String
    let rows: [(String, String)]

    var body: some View {
        GroupBox(label: Text(title)) {
            VStack(spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    StatRow(label: row.0, value: row.1)
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct HeatmapGridView: View {
    private struct HeatmapCell: Identifiable {
        let id: String
        let day: TBHeatmapDay?
    }

    let days: [TBHeatmapDay]
    @State private var hoveredDayID: Date?

    private let calendar = Calendar.current

    private var maxCount: Int {
        max(days.map(\.count).max() ?? 0, 1)
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var todayDay: TBHeatmapDay? {
        days.last { calendar.isDate($0.date, inSameDayAs: today) }
    }

    private var displayedDay: TBHeatmapDay? {
        if let hoveredDayID {
            return days.first { $0.id == hoveredDayID }
        }

        return todayDay ?? days.last
    }

    private var columns: [[HeatmapCell]] {
        var result: [[HeatmapCell]] = []
        var currentColumn: [HeatmapCell] = []

        for day in days {
            let columnIndex = result.count
            let rowIndex = currentColumn.count
            currentColumn.append(
                HeatmapCell(
                    id: "\(columnIndex)-\(rowIndex)-\(day.id.timeIntervalSinceReferenceDate)",
                    day: day
                )
            )
            if currentColumn.count == 7 {
                result.append(currentColumn)
                currentColumn = []
            }
        }

        if !currentColumn.isEmpty {
            while currentColumn.count < 7 {
                let columnIndex = result.count
                let rowIndex = currentColumn.count
                currentColumn.append(
                    HeatmapCell(
                        id: "\(columnIndex)-\(rowIndex)-empty",
                        day: nil
                    )
                )
            }
            result.append(currentColumn)
        }

        return result
    }

    private func color(for count: Int) -> Color {
        guard count > 0 else {
            return Color(red: 0.96, green: 0.93, blue: 0.89)
        }

        let normalized = min(Double(count) / Double(maxCount), 1.0)
        let opacity = 0.35 + (sqrt(normalized) * 0.65)
        return Color(red: 1.0, green: 0.47, blue: 0.16).opacity(opacity)
    }

    private func isToday(_ day: TBHeatmapDay?) -> Bool {
        guard let day else {
            return false
        }

        return calendar.isDate(day.date, inSameDayAs: today)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let displayedDay {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(for: displayedDay.count))
                        .frame(width: 10, height: 10)
                    Text(heatmapHelpText(for: displayedDay))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(columns.indices, id: \.self) { columnIndex in
                        let column = columns[columnIndex]
                        VStack(spacing: 4) {
                            ForEach(column) { cell in
                                let day = cell.day
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color(for: day?.count ?? 0))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(isToday(day) ? Color.primary.opacity(0.45) : .clear, lineWidth: 1)
                                    )
                                    .frame(width: 12, height: 12)
                                    .contentShape(Rectangle())
                                    .onHover { isHovering in
                                        hoveredDayID = isHovering ? day?.id : nil
                                    }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func heatmapHelpText(for day: TBHeatmapDay) -> String {
        let dateText = heatmapDateText(for: day.date)
        return "\(dateText) · \(localizedTomatoTreeCountText(day.count))"
    }
}

private struct StatsView: View {
    @EnvironmentObject var timer: TBTimer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsSectionView(
                title: NSLocalizedString("StatsView.session.title", comment: "Session title"),
                rows: [
                    (
                        NSLocalizedString("StatsView.pomodoros.label", comment: "Pomodoros label"),
                        "\(timer.completedPomodorosInSession)"
                    ),
                    (
                        NSLocalizedString("StatsView.breakDuration.label", comment: "Break duration label"),
                        timer.formattedDuration(seconds: timer.completedBreakSecondsInSession)
                    ),
                    (
                        NSLocalizedString("StatsView.currentPhase.label", comment: "Current phase label"),
                        timer.phaseDisplayText
                    ),
                    (
                        NSLocalizedString("StatsView.target.label", comment: "Target label"),
                        localizedTargetText(setNumber: timer.currentSetNumber, pomodoroNumber: timer.currentPomodoroNumber)
                    )
                ]
            )

            StatsSectionView(
                title: NSLocalizedString("StatsView.today.title", comment: "Today title"),
                rows: [
                    (
                        NSLocalizedString("StatsView.pomodoros.label", comment: "Pomodoros label"),
                        "\(timer.todaySummary.pomodoroCount)"
                    ),
                    (
                        NSLocalizedString("StatsView.breakDuration.label", comment: "Break duration label"),
                        timer.formattedDuration(seconds: timer.todaySummary.breakSeconds)
                    )
                ]
            )

            GroupBox(label: Text(NSLocalizedString("StatsView.heatmap.title", comment: "Heatmap title"))) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("StatsView.heatmap.365d.label", comment: "365 day heatmap label"))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    HeatmapGridView(days: timer.heatmapDays(for: .last365Days))
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
    }
}

private struct ClockDialView: View {
    let diameter: CGFloat
    let progress: Double
    let tint: Color

    private var progressLineWidth: CGFloat {
        min(max(diameter * 0.05, 10), 16)
    }

    private var innerLineWidth: CGFloat {
        min(max(diameter * 0.008, 1.5), 2.5)
    }

    private var innerPadding: CGFloat {
        min(max(diameter * 0.065, 12), 20)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.14), lineWidth: progressLineWidth)

            Circle()
                .stroke(Color.primary.opacity(0.05), lineWidth: innerLineWidth)
                .padding(innerPadding)

            Circle()
                .trim(from: 0, to: max(progress, 0.01))
                .stroke(tint, style: StrokeStyle(lineWidth: progressLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct TBClockWindowView: View {
    @ObservedObject var timer: TBTimer
    @ObservedObject var controller: TBClockWindowController

    private var targetText: String {
        localizedTargetText(setNumber: timer.currentSetNumber, pomodoroNumber: timer.currentPomodoroNumber)
    }

    private var dialTint: Color {
        switch timer.currentIntervalKind {
        case .work:
            return .orange
        case .shortRest:
            return .green
        case .longRest:
            return .blue
        case nil:
            return .orange
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Unified scale factor: reference size 400pt = 1.0
            let referenceDimension: CGFloat = 400
            let shortSide = min(size.width, size.height)
            let scaleFactor = max(shortSide / referenceDimension, 0.35)

            // All dimensions derived from single scale factor
            let dialSize = min(220 * scaleFactor, shortSide * 0.7)
            let timeFontSize = max(36 * scaleFactor, 14)
            let phaseFontSize = max(16 * scaleFactor, 11)
            let targetFontSize = max(14 * scaleFactor, 11)
            let pinLabelFontSize = max(13 * scaleFactor, 11)
            let buttonWidth = max(100 * scaleFactor, 48)
            let buttonSpacing = max(10 * scaleFactor, 4)

            // Inner spacing: generous breathing room between elements
            let dialToTextSpacing = max(16 * scaleFactor, 6)
            let textToButtonSpacing = max(16 * scaleFactor, 6)

            // Only 2 simple thresholds for hiding secondary elements
            let showDetails = shortSide >= 200
            let showPin = shortSide >= 300
            let controlSize: ControlSize = scaleFactor < 0.6 ? .mini : (scaleFactor < 0.85 ? .regular : .large)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Clock dial with overlaid time text
                ClockDialView(diameter: dialSize, progress: timer.progressFraction, tint: dialTint)
                    .frame(width: dialSize, height: dialSize)
                    .overlay(
                        VStack(spacing: max(4 * scaleFactor, 0)) {
                            Text(timer.timeLeftString)
                                .font(.system(size: timeFontSize, weight: .semibold, design: .monospaced))
                            if showDetails {
                                Text(timer.phaseDisplayText)
                                    .font(.system(size: phaseFontSize, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    )

                // Target text (set/pomodoro info)
                if showDetails {
                    Text(targetText)
                        .font(.system(size: targetFontSize, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.top, dialToTextSpacing)
                }

                // Action buttons
                HStack(spacing: buttonSpacing) {
                    Button(timer.primaryActionTitle) {
                        timer.performPrimaryAction()
                    }
                    .keyboardShortcut(.defaultAction)
                    .frame(width: buttonWidth)

                    if timer.canReset {
                        Button(NSLocalizedString("TBPopoverView.reset.label", comment: "Reset label")) {
                            timer.resetCurrentInterval()
                        }
                        .frame(width: buttonWidth)
                    }
                }
                .controlSize(controlSize)
                .padding(.top, showDetails ? textToButtonSpacing : dialToTextSpacing)

                // Pin toggle
                if showPin {
                    Toggle(isOn: $controller.isPinned) {
                        Text(NSLocalizedString("ClockWindow.pin.label", comment: "Pin window label"))
                            .font(.system(size: pinLabelFontSize, weight: .medium))
                    }
                    .toggleStyle(.switch)
                    .padding(.top, max(12 * scaleFactor, 4))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, max(4 * scaleFactor, 2))
            .padding(.vertical, max(2 * scaleFactor, 1))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 148, minHeight: 150)
    }
}

private enum ChildView {
    case intervals, settings, sounds, stats
}

struct TBPopoverView: View {
    @ObservedObject var timer: TBTimer
    @ObservedObject var clockWindowController: TBClockWindowController
    @State private var activeChildView = ChildView.intervals

    @ViewBuilder
    private var primaryActionButton: some View {
        Button(timer.primaryActionTitle) {
            timer.performPrimaryAction()
            TBStatusItem.shared?.closePopover(nil)
        }
        .foregroundColor(.white)
        .font(.system(.body).weight(.semibold))
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
    }

    @ViewBuilder
    private var resetActionButton: some View {
        Button(NSLocalizedString("TBPopoverView.reset.label", comment: "Reset label")) {
            timer.resetCurrentInterval()
            TBStatusItem.shared?.closePopover(nil)
        }
        .controlSize(.large)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if timer.canReset {
                HStack(spacing: 8) {
                    primaryActionButton
                        .frame(width: 112)
                    resetActionButton
                        .frame(width: 112)
                }
                .frame(maxWidth: .infinity)
            } else {
                primaryActionButton
                    .frame(width: 112)
                    .frame(maxWidth: .infinity)
            }

            if timer.canReset {
                HStack {
                    Text(timer.phaseDisplayText)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(timer.timeLeftString)
                        .font(.system(.headline).monospacedDigit())
                }
            }

            Button {
                clockWindowController.toggle()
                TBStatusItem.shared?.closePopover(nil)
            } label: {
                HStack {
                    Image(systemName: clockWindowController.isVisible ? "clock.badge.xmark" : "clock.badge")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            clockWindowController.isVisible
                                ? NSLocalizedString("TBPopoverView.clockWindow.hide.label", comment: "Hide clock window label")
                                : NSLocalizedString("TBPopoverView.clockWindow.show.label", comment: "Show clock window label")
                        )
                        .font(.headline)
                        .foregroundColor(.primary)

                        Text(timer.canReset ? timer.phaseDisplayText : timer.timeLeftString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(timer.timeLeftString)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.05))
                )
            }
            .buttonStyle(.plain)

            Picker("", selection: $activeChildView) {
                Text(NSLocalizedString("TBPopoverView.intervals.label",
                                       comment: "Intervals label")).tag(ChildView.intervals)
                Text(NSLocalizedString("TBPopoverView.settings.label",
                                       comment: "Settings label")).tag(ChildView.settings)
                Text(NSLocalizedString("TBPopoverView.sounds.label",
                                       comment: "Sounds label")).tag(ChildView.sounds)
                Text(NSLocalizedString("TBPopoverView.stats.label",
                                       comment: "Stats label")).tag(ChildView.stats)
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .pickerStyle(.segmented)

            GroupBox {
                switch activeChildView {
                case .intervals:
                    IntervalsView().environmentObject(timer)
                case .settings:
                    SettingsView().environmentObject(timer)
                case .sounds:
                    SoundsView().environmentObject(timer.player)
                case .stats:
                    StatsView().environmentObject(timer)
                }
            }

            Group {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel()
                } label: {
                    Text(NSLocalizedString("TBPopoverView.about.label",
                                           comment: "About label"))
                    Spacer()
                    Text("⌘ A").foregroundColor(Color.gray)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("a")
                Button {
                    NSApplication.shared.terminate(self)
                } label: {
                    Text(NSLocalizedString("TBPopoverView.quit.label",
                                           comment: "Quit label"))
                    Spacer()
                    Text("⌘ Q").foregroundColor(Color.gray)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }
        }
        #if DEBUG
            /*
             After several hours of Googling and trying various StackOverflow
             recipes I still haven't figured a reliable way to auto resize
             popover to fit all it's contents (pull requests are welcome!).
             The following code block is used to determine the optimal
             geometry of the popover.
             */
            .overlay(
                GeometryReader { proxy in
                    debugSize(proxy: proxy)
                }
            )
        #endif
            /* Use values from GeometryReader */
//            .frame(width: 240, height: 276)
            .padding(12)
            .frame(width: 336)
    }
}

#if DEBUG
    func debugSize(proxy: GeometryProxy) -> some View {
        print("Optimal popover size:", proxy.size)
        return Color.clear
    }
#endif
