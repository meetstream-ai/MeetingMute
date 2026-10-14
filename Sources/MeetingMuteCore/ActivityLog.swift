import Foundation

public struct ActivityEntry: Codable, Identifiable, Sendable, Equatable {
    public var id = UUID()
    public var date: Date
    public let message: String
    /// The same message repeated close together is one entry ("Closed Granola popup ×3").
    public var count: Int

    public init(date: Date, message: String, count: Int = 1) {
        self.date = date
        self.message = message
        self.count = count
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try c.decode(Date.self, forKey: .date)
        message = try c.decode(String.self, forKey: .message)
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 1
    }

    public var text: String { count > 1 ? "\(message) ×\(count)" : message }
}

public enum ActivityLog {
    /// Adds a message to the top of the log, folding it into the newest entry when it repeats
    /// within `mergeWindow` seconds.
    public static func appending(_ message: String, at date: Date, to log: [ActivityEntry],
                                 mergeWindow: TimeInterval = 600, limit: Int = 200) -> [ActivityEntry] {
        var log = log
        if var first = log.first, first.message == message, date.timeIntervalSince(first.date) < mergeWindow {
            first.count += 1
            first.date = date
            log[0] = first
        } else {
            log.insert(ActivityEntry(date: date, message: message), at: 0)
        }
        if log.count > limit { log.removeLast(log.count - limit) }
        return log
    }
}
