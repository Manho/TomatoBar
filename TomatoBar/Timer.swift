import KeyboardShortcuts
import SwiftUI

private struct TBActiveInterval {
    let kind: TBIntervalKind
    let startedAt: Date
    let plannedSeconds: Int
}

private struct TBIntervalRecord: Codable, Identifiable {
    let id: UUID
    let kind: TBIntervalKind
    let startedAt: Date
    let endedAt: Date
    let plannedSeconds: Int
    let actualSeconds: Int
}

private final class TBHistoryStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileURL: URL
    private let calendar = Calendar.current

    private(set) var records: [TBIntervalRecord] = []

    init() {
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601

        let fileManager = FileManager.default
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        fileURL = supportDirectory.appendingPathComponent("TomatoBar", isDirectory: true)
            .appendingPathComponent("History.json")

        load()
    }

    func append(record: TBIntervalRecord) {
        records.append(record)
        save()
    }

    func summaryForToday() -> TBStatsSummary {
        summary(for: Date())
    }

    func summary(for date: Date) -> TBStatsSummary {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let dayRecords = records.filter { $0.endedAt >= startOfDay && $0.endedAt < endOfDay }

        return TBStatsSummary(
            pomodoroCount: dayRecords.filter { $0.kind == .work }.count,
            breakSeconds: dayRecords.filter { $0.kind.isBreak }.reduce(0) { $0 + $1.actualSeconds }
        )
    }

    func heatmapDays(for range: TBHeatmapRange) -> [TBHeatmapDay] {
        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -(range.dayCount - 1), to: endDate)!
        var countsByDay: [Date: Int] = [:]

        for record in records where record.kind == .work {
            let day = calendar.startOfDay(for: record.endedAt)
            if day >= startDate, day <= endDate {
                countsByDay[day, default: 0] += 1
            }
        }

        return (0 ..< range.dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startDate)!
            return TBHeatmapDay(date: date, count: countsByDay[date, default: 0])
        }
    }

    private func load() {
        let fileManager = FileManager.default
        let directoryURL = fileURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            records = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            records = try decoder.decode([TBIntervalRecord].self, from: data)
        } catch {
            print("cannot load history file: \(error)")
            records = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("cannot save history file: \(error)")
        }
    }
}

class TBTimer: ObservableObject {
    static let shared = TBTimer()

    @AppStorage("stopAfterBreak") var stopAfterBreak = false
    @AppStorage("showTimerInMenuBar") var showTimerInMenuBar = true
    @AppStorage("workIntervalLength") var workIntervalLength = 25
    @AppStorage("shortRestIntervalLength") var shortRestIntervalLength = 5
    @AppStorage("longRestIntervalLength") var longRestIntervalLength = 15
    @AppStorage("workIntervalsInSet") var workIntervalsInSet = 4
    // This preference is "hidden"
    @AppStorage("overrunTimeLimit") var overrunTimeLimit = -60.0

    public let player = TBPlayer()
    private let historyStore = TBHistoryStore()
    private var notificationCenter = TBNotificationCenter()
    private var finishTime: Date?
    private var timerFormatter = DateComponentsFormatter()
    private var summaryFormatter = DateComponentsFormatter()
    private var activeInterval: TBActiveInterval?
    @Published private(set) var state: TBTimerState = .idle
    @Published private(set) var timeLeftString: String = "00:00"
    @Published private(set) var timer: DispatchSourceTimer?
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var currentIntervalKind: TBIntervalKind?
    @Published private(set) var completedPomodorosInSession: Int = 0
    @Published private(set) var completedBreakSecondsInSession: Int = 0
    @Published private(set) var todaySummary = TBStatsSummary()

    init() {
        timerFormatter.unitsStyle = .positional
        timerFormatter.allowedUnits = [.minute, .second]
        timerFormatter.zeroFormattingBehavior = .pad

        summaryFormatter.unitsStyle = .abbreviated
        summaryFormatter.allowedUnits = [.hour, .minute]
        summaryFormatter.maximumUnitCount = 2
        summaryFormatter.zeroFormattingBehavior = .dropAll

        timeLeftString = timerFormatter.string(from: 0) ?? "00:00"

        KeyboardShortcuts.onKeyUp(for: .startStopTimer, action: performPrimaryAction)
        notificationCenter.setActionHandler(handler: onNotificationAction)
        refreshHistoryDerivedState()
        startObservingDayChanges()

        let aem: NSAppleEventManager = NSAppleEventManager.shared()
        aem.setEventHandler(self,
                            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
                            forEventClass: AEEventClass(kInternetEventClass),
                            andEventID: AEEventID(kAEGetURL))
    }

    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor,
                                 withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.forKeyword(AEKeyword(keyDirectObject))?.stringValue else {
            print("url handling error: cannot get url")
            return
        }
        let url = URL(string: urlString)
        guard url != nil,
              let scheme = url!.scheme,
              let host = url!.host else {
            print("url handling error: cannot parse url")
            return
        }
        guard scheme.caseInsensitiveCompare("tomatobar") == .orderedSame else {
            print("url handling error: unknown scheme \(scheme)")
            return
        }
        switch host.lowercased() {
        case "startstop":
            performPrimaryAction()
        default:
            print("url handling error: unknown command \(host)")
            return
        }
    }

    @objc private func handleCalendarDayChanged() {
        refreshHistoryDerivedState()
    }

    @objc private func handleApplicationDidBecomeActive() {
        refreshHistoryDerivedState()
    }

    var isIdle: Bool {
        state.isIdle
    }

    var isPaused: Bool {
        state.isPaused
    }

    var isRunning: Bool {
        state.isRunning
    }

    var canReset: Bool {
        !state.isIdle
    }

    var primaryActionTitle: String {
        switch state {
        case .idle:
            return NSLocalizedString("TBPopoverView.start.label", comment: "Start label")
        case .workRunning, .restRunning:
            return NSLocalizedString("TBPopoverView.pause.label", comment: "Pause label")
        case .workPaused, .restPaused:
            return NSLocalizedString("TBPopoverView.resume.label", comment: "Resume label")
        }
    }

    var phaseDisplayText: String {
        let key: String
        switch state {
        case .idle:
            key = "TBTimer.phase.idle"
        case .workRunning:
            key = "TBTimer.phase.work"
        case .workPaused, .restPaused:
            key = "TBTimer.phase.paused"
        case .restRunning:
            key = currentIntervalKind == .longRest ? "TBTimer.phase.longRest" : "TBTimer.phase.shortRest"
        }

        return NSLocalizedString(key, comment: "Timer phase")
    }

    var currentSetNumber: Int {
        (completedPomodorosInSession / max(workIntervalsInSet, 1)) + 1
    }

    var currentPomodoroNumber: Int {
        (completedPomodorosInSession % max(workIntervalsInSet, 1)) + 1
    }

    var progressFraction: Double {
        guard let activeInterval else {
            return 0
        }

        let plannedSeconds = max(activeInterval.plannedSeconds, 1)
        let elapsedSeconds = max(activeInterval.plannedSeconds - remainingSeconds, 0)
        return min(max(Double(elapsedSeconds) / Double(plannedSeconds), 0), 1)
    }

    func performPrimaryAction() {
        switch state {
        case .idle:
            start()
        case .workRunning, .restRunning:
            pause()
        case .workPaused, .restPaused:
            resume()
        }
    }

    func pause() {
        switch state {
        case .workRunning:
            transition(to: .workPaused, event: .pause)
            captureRemainingTime()
            stopTimer()
            player.stopTicking()
            updateTimeLeft()
        case .restRunning:
            transition(to: .restPaused, event: .pause)
            captureRemainingTime()
            stopTimer()
            updateTimeLeft()
        default:
            return
        }
    }

    func resume() {
        switch state {
        case .workPaused:
            transition(to: .workRunning, event: .resume)
            startWorkInterval(newInterval: false)
        case .restPaused:
            transition(to: .restRunning, event: .resume)
            startRestInterval(kind: currentIntervalKind ?? .shortRest, newInterval: false)
        default:
            return
        }
    }

    func resetCurrentInterval() {
        guard !state.isIdle else {
            return
        }

        transition(to: .idle, event: .reset)
        player.stopTicking()
        clearCurrentInterval()
        TBStatusItem.shared?.setIcon(name: .idle)
        updateTimeLeft()
    }

    func skipRest() {
        guard state.isRest else {
            return
        }

        transition(to: .workRunning, event: .skipRest)
        clearCurrentInterval()
        startWorkInterval(newInterval: true)
    }

    func formattedDuration(seconds: Int) -> String {
        summaryFormatter.string(from: TimeInterval(seconds)) ?? "0m"
    }

    func heatmapDays(for range: TBHeatmapRange) -> [TBHeatmapDay] {
        historyStore.heatmapDays(for: range)
    }

    func updateTimeLeft() {
        timeLeftString = timerFormatter.string(from: TimeInterval(max(remainingSeconds, 0))) ?? "00:00"
        if !state.isIdle, showTimerInMenuBar {
            TBStatusItem.shared?.setTitle(title: timeLeftString)
        } else {
            TBStatusItem.shared?.setTitle(title: nil)
        }
    }

    private func startTimer(seconds: Int) {
        stopTimer()
        remainingSeconds = max(seconds, 0)
        finishTime = Date().addingTimeInterval(TimeInterval(seconds))

        let queue = DispatchQueue(label: "Timer")
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer!.schedule(deadline: .now(), repeating: .seconds(1), leeway: .never)
        timer!.setEventHandler(handler: onTimerTick)
        timer!.setCancelHandler(handler: onTimerCancel)
        timer!.resume()
        updateTimeLeft()
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func onTimerTick() {
        /* Cannot publish updates from background thread */
        DispatchQueue.main.async { [self] in
            guard state.isRunning, let finishTime else {
                return
            }

            let timeLeft = finishTime.timeIntervalSince(Date())
            remainingSeconds = max(Int(ceil(timeLeft)), 0)
            updateTimeLeft()
            if timeLeft <= 0 {
                /*
                 Ticks can be missed during the machine sleep.
                 Stop the timer if it goes beyond an overrun time limit.
                 */
                if timeLeft < overrunTimeLimit {
                    resetCurrentInterval()
                } else {
                    handleTimerFired()
                }
            }
        }
    }

    private func onTimerCancel() {
        DispatchQueue.main.async { [self] in
            updateTimeLeft()
        }
    }

    private func onNotificationAction(action: TBNotification.Action) {
        if action == .skipRest, state.isRest {
            skipRest()
        }
    }

    private func start() {
        guard state == .idle else {
            return
        }

        transition(to: .workRunning, event: .start)
        startWorkInterval(newInterval: true)
    }

    private func handleTimerFired() {
        switch state {
        case .workRunning:
            completeCurrentInterval()
            player.playDing()
            transition(to: .restRunning, event: .timerFired)
            startRestInterval(kind: nextRestKind(), newInterval: true)
        case .restRunning:
            completeCurrentInterval()
            notificationCenter.send(
                title: NSLocalizedString("TBTimer.onRestFinish.title", comment: "Break is over title"),
                body: NSLocalizedString("TBTimer.onRestFinish.body", comment: "Break is over body"),
                category: .restFinished
            )

            if stopAfterBreak {
                transition(to: .idle, event: .timerFired)
                clearCurrentInterval()
                TBStatusItem.shared?.setIcon(name: .idle)
                updateTimeLeft()
            } else {
                transition(to: .workRunning, event: .timerFired)
                clearCurrentInterval()
                startWorkInterval(newInterval: true)
            }
        default:
            return
        }
    }

    private func startWorkInterval(newInterval: Bool) {
        TBStatusItem.shared?.setIcon(name: .work)

        if newInterval {
            let plannedSeconds = plannedSeconds(for: .work)
            activeInterval = TBActiveInterval(kind: .work, startedAt: Date(), plannedSeconds: plannedSeconds)
            currentIntervalKind = .work
            remainingSeconds = plannedSeconds
            player.playWindup()
        }

        player.startTicking()
        startTimer(seconds: remainingSeconds)
    }

    private func startRestInterval(kind: TBIntervalKind, newInterval: Bool) {
        TBStatusItem.shared?.setIcon(name: kind == .longRest ? .longRest : .shortRest)

        if newInterval {
            let plannedSeconds = plannedSeconds(for: kind)
            activeInterval = TBActiveInterval(kind: kind, startedAt: Date(), plannedSeconds: plannedSeconds)
            currentIntervalKind = kind
            remainingSeconds = plannedSeconds

            let bodyKey = kind == .longRest ? "TBTimer.onRestStart.long.body" : "TBTimer.onRestStart.short.body"
            notificationCenter.send(
                title: NSLocalizedString("TBTimer.onRestStart.title", comment: "Time's up title"),
                body: NSLocalizedString(bodyKey, comment: "Break body"),
                category: .restStarted
            )
        }

        startTimer(seconds: remainingSeconds)
    }

    private func completeCurrentInterval() {
        guard let activeInterval else {
            return
        }

        let record = TBIntervalRecord(
            id: UUID(),
            kind: activeInterval.kind,
            startedAt: activeInterval.startedAt,
            endedAt: Date(),
            plannedSeconds: activeInterval.plannedSeconds,
            actualSeconds: activeInterval.plannedSeconds
        )

        historyStore.append(record: record)
        if activeInterval.kind == .work {
            completedPomodorosInSession += 1
        } else {
            completedBreakSecondsInSession += record.actualSeconds
        }

        refreshHistoryDerivedState()
        player.stopTicking()
        clearCurrentInterval()
    }

    private func captureRemainingTime() {
        if let finishTime {
            remainingSeconds = max(Int(ceil(finishTime.timeIntervalSinceNow)), 0)
        }
    }

    private func clearCurrentInterval() {
        stopTimer()
        finishTime = nil
        remainingSeconds = 0
        activeInterval = nil
        currentIntervalKind = nil
    }

    private func plannedSeconds(for kind: TBIntervalKind) -> Int {
        switch kind {
        case .work:
            return workIntervalLength * 60
        case .shortRest:
            return shortRestIntervalLength * 60
        case .longRest:
            return longRestIntervalLength * 60
        }
    }

    private func nextRestKind() -> TBIntervalKind {
        completedPomodorosInSession.isMultiple(of: max(workIntervalsInSet, 1)) ? .longRest : .shortRest
    }

    private func refreshHistoryDerivedState() {
        todaySummary = historyStore.summaryForToday()
    }

    private func startObservingDayChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCalendarDayChanged),
            name: NSNotification.Name.NSCalendarDayChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    private func transition(to newState: TBTimerState, event: TBTimerEvent) {
        let previousState = state
        state = newState
        logger.append(event: TBLogEventTransition(event: event, fromState: previousState, toState: newState))
    }
}
