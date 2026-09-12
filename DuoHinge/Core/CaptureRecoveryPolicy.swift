import Foundation

/// Avoid a capture/re-prompt loop when macOS denies or cannot start a stream.
struct CaptureRecoveryPolicy {
    private(set) var attempts = 0
    private var nextAttempt = 0.0

    func canAttempt(at time: TimeInterval) -> Bool {
        attempts < 3 && time >= nextAttempt
    }

    mutating func recordAttempt(at time: TimeInterval) {
        attempts += 1
        nextAttempt = time + (attempts == 1 ? 1 : 3)
    }

    mutating func reset() {
        self = Self()
    }
}
