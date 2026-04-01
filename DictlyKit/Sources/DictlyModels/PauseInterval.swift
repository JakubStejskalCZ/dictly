import Foundation

/// A closed time range (in seconds from recording start) during which recording was paused.
/// Stored as JSON on `Session.pauseIntervalsJSON` for Mac timeline gap rendering (Story 4.2).
public struct PauseInterval: Codable, Equatable {
    /// Seconds from recording start when the pause began.
    public let start: TimeInterval
    /// Seconds from recording start when recording resumed.
    public let end: TimeInterval

    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }
}

public extension Session {
    /// Decoded pause intervals from `pauseIntervalsJSON`. Returns empty array if JSON is missing or invalid.
    var pauseIntervals: [PauseInterval] {
        get {
            guard let json = pauseIntervalsJSON, let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([PauseInterval].self, from: data)) ?? []
        }
        set {
            guard !newValue.isEmpty else { pauseIntervalsJSON = nil; return }
            guard let data = try? JSONEncoder().encode(newValue) else { pauseIntervalsJSON = nil; return }
            pauseIntervalsJSON = String(data: data, encoding: .utf8)
        }
    }
}
