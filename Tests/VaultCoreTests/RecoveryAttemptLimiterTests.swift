import Foundation
import Testing
@testable import VaultCore

@Test func recoveryBackoffStartsAfterFirstFailureAndGrowsExponentially() {
    var limiter = RecoveryAttemptLimiter(policy: .default)
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    limiter.recordFailure(at: start)
    #expect(limiter.failureCount == 1)
    #expect(limiter.remainingDelay(at: start) == 1)

    let secondAttempt = start.addingTimeInterval(1)
    limiter.recordFailure(at: secondAttempt)
    #expect(limiter.failureCount == 2)
    #expect(limiter.remainingDelay(at: secondAttempt) == 2)

    let thirdAttempt = secondAttempt.addingTimeInterval(2)
    limiter.recordFailure(at: thirdAttempt)
    #expect(limiter.failureCount == 3)
    #expect(limiter.remainingDelay(at: thirdAttempt) == 4)
}

@Test func recoveryBackoffCapsAtConfiguredMaximum() {
    var limiter = RecoveryAttemptLimiter(policy: RecoveryBackoffPolicy(baseDelay: 1, maximumDelay: 8))
    var now = Date(timeIntervalSince1970: 1_700_000_000)
    for _ in 0..<10 {
        limiter.recordFailure(at: now)
        now = limiter.nextAllowedAt ?? now
    }
    let lastFailureTime = now.addingTimeInterval(-8)
    #expect(limiter.remainingDelay(at: lastFailureTime) == 8)
}

@Test func successfulRecoveryResetsBackoffState() {
    var limiter = RecoveryAttemptLimiter(policy: .default)
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    limiter.recordFailure(at: now)
    limiter.recordFailure(at: now.addingTimeInterval(1))
    limiter.recordSuccess()
    #expect(limiter.failureCount == 0)
    #expect(limiter.nextAllowedAt == nil)
    #expect(limiter.canAttempt(at: now))
}

@Test func attemptIsBlockedUntilNextAllowedTime() {
    var limiter = RecoveryAttemptLimiter(policy: .default)
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    limiter.recordFailure(at: now)
    #expect(!limiter.canAttempt(at: now.addingTimeInterval(0.5)))
    #expect(limiter.canAttempt(at: now.addingTimeInterval(1)))
    #expect(limiter.remainingDelay(at: now.addingTimeInterval(2)) == 0)
}
