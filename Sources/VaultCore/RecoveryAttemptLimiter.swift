import Foundation

public struct RecoveryBackoffPolicy: Equatable, Sendable {
    public let baseDelay: TimeInterval
    public let maximumDelay: TimeInterval

    public init(baseDelay: TimeInterval, maximumDelay: TimeInterval) {
        precondition(baseDelay > 0)
        precondition(maximumDelay >= baseDelay)
        self.baseDelay = baseDelay
        self.maximumDelay = maximumDelay
    }

    public static let `default` = RecoveryBackoffPolicy(
        baseDelay: 1,
        maximumDelay: 30
    )

    public func delay(forFailureCount failureCount: Int) -> TimeInterval {
        guard failureCount > 0 else { return 0 }
        var delay = baseDelay
        if failureCount == 1 { return delay }
        for _ in 2...failureCount {
            if delay >= maximumDelay / 2 { return maximumDelay }
            delay *= 2
        }
        return min(delay, maximumDelay)
    }
}

public struct RecoveryAttemptLimiter: Equatable, Sendable {
    public private(set) var failureCount: Int
    public private(set) var nextAllowedAt: Date?
    public let policy: RecoveryBackoffPolicy

    public init(policy: RecoveryBackoffPolicy = .default) {
        self.policy = policy
        self.failureCount = 0
        self.nextAllowedAt = nil
    }

    public mutating func recordFailure(at date: Date) {
        failureCount += 1
        nextAllowedAt = date.addingTimeInterval(
            policy.delay(forFailureCount: failureCount)
        )
    }

    public mutating func recordSuccess() {
        failureCount = 0
        nextAllowedAt = nil
    }

    public func canAttempt(at date: Date) -> Bool {
        guard let nextAllowedAt else { return true }
        return date >= nextAllowedAt
    }

    public func remainingDelay(at date: Date) -> TimeInterval {
        guard let nextAllowedAt else { return 0 }
        return max(0, nextAllowedAt.timeIntervalSince(date))
    }
}
