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
    let days: [TBHeatmapDay]

    private var columns: [[TBHeatmapDay?]] {
        var result: [[TBHeatmapDay?]] = []
        var currentColumn: [TBHeatmapDay?] = []

        for day in days {
            currentColumn.append(day)
            if currentColumn.count == 7 {
                result.append(currentColumn)
                currentColumn = []
            }
        }

        if !currentColumn.isEmpty {
            while currentColumn.count < 7 {
                currentColumn.append(nil)
            }
            result.append(currentColumn)
        }

        return result
    }

    private func color(for count: Int) -> Color {
        switch count {
        case ..<1:
            return Color.orange.opacity(0.12)
        case 1:
            return Color.orange.opacity(0.35)
        case 2:
            return Color.orange.opacity(0.55)
        case 3:
            return Color.orange.opacity(0.75)
        default:
            return Color.orange
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 4) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(spacing: 4) {
                        ForEach(Array(column.enumerated()), id: \.offset) { _, day in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color(for: day?.count ?? 0))
                                .frame(width: 11, height: 11)
                                .help(day.map { heatmapHelpText(for: $0) } ?? "")
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func heatmapHelpText(for day: TBHeatmapDay) -> String {
        let dateText = heatmapDateText(for: day.date)
        return "\(dateText): \(day.count)"
    }
}

private struct StatsView: View {
    @EnvironmentObject var timer: TBTimer
    @State private var heatmapRange = TBHeatmapRange.last30Days

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
                    Picker("", selection: $heatmapRange) {
                        Text(NSLocalizedString("StatsView.heatmap.30d.label", comment: "30 day heatmap label"))
                            .tag(TBHeatmapRange.last30Days)
                        Text(NSLocalizedString("StatsView.heatmap.365d.label", comment: "365 day heatmap label"))
                            .tag(TBHeatmapRange.last365Days)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)

                    HeatmapGridView(days: timer.heatmapDays(for: heatmapRange))
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
    }
}

private struct ClockDialView: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.14), lineWidth: 14)

            Circle()
                .stroke(Color.primary.opacity(0.05), lineWidth: 2)
                .padding(18)

            Circle()
                .trim(from: 0, to: max(progress, 0.01))
                .stroke(tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
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
        VStack(spacing: 18) {
            ClockDialView(progress: timer.progressFraction, tint: dialTint)
                .frame(width: 240, height: 240)
                .overlay(
                    VStack(spacing: 6) {
                        Text(timer.timeLeftString)
                            .font(.system(size: 34, weight: .semibold, design: .monospaced))
                        Text(timer.phaseDisplayText)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                )

            Text(targetText)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Button(timer.primaryActionTitle) {
                    timer.performPrimaryAction()
                }
                .keyboardShortcut(.defaultAction)

                if timer.canReset {
                    Button(NSLocalizedString("TBPopoverView.reset.label", comment: "Reset label")) {
                        timer.resetCurrentInterval()
                    }
                }
            }
            .controlSize(.large)

            Toggle(isOn: $controller.isPinned) {
                Text(NSLocalizedString("ClockWindow.pin.label", comment: "Pin window label"))
            }
            .toggleStyle(.switch)
        }
        .padding(22)
        .frame(minWidth: 320, minHeight: 360)
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
                HStack(spacing: 10) {
                    primaryActionButton
                        .frame(maxWidth: .infinity)
                    resetActionButton
                        .frame(maxWidth: .infinity)
                }
            } else {
                primaryActionButton
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
                        .fill(Color.accentColor.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
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
