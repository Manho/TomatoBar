import Foundation

enum TBTimerEvent: String {
    case start
    case pause
    case resume
    case reset
    case timerFired
    case skipRest
}

enum TBTimerState: String {
    case idle
    case workRunning
    case workPaused
    case restRunning
    case restPaused

    var isIdle: Bool {
        self == .idle
    }

    var isRunning: Bool {
        self == .workRunning || self == .restRunning
    }

    var isPaused: Bool {
        self == .workPaused || self == .restPaused
    }

    var isWork: Bool {
        self == .workRunning || self == .workPaused
    }

    var isRest: Bool {
        self == .restRunning || self == .restPaused
    }
}

enum TBIntervalKind: String, Codable {
    case work
    case shortRest
    case longRest

    var isBreak: Bool {
        self != .work
    }
}

enum TBHeatmapRange: String, CaseIterable, Identifiable {
    case last30Days
    case last365Days

    var id: String {
        rawValue
    }

    var dayCount: Int {
        switch self {
        case .last30Days:
            return 30
        case .last365Days:
            return 365
        }
    }
}

struct TBStatsSummary {
    var pomodoroCount: Int = 0
    var breakSeconds: Int = 0
}

struct TBHeatmapDay: Identifiable {
    let date: Date
    let count: Int

    var id: Date {
        date
    }
}
