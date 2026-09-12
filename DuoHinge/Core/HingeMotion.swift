import Foundation

/// Presentation-only interpolation. Raw sensor angles still control capture and visibility.
/// Keeping a short history lets display frames interpolate between consecutive real
/// lid reports rather than showing each roughly 10 Hz report as a discrete step.
struct HingeMotion {
    private struct Sample {
        let angle: Double
        let time: Double
    }

    // The tested sensor usually reports every 100–120 ms. This delay keeps one
    // complete segment available for interpolation while remaining responsive.
    private static let presentationDelay = 0.120
    private var samples: [Sample] = []

    mutating func receive(angle next: Double, at time: Double) {
        guard next.isFinite, time.isFinite, (0...360).contains(next) else { return }
        if let latest = samples.last {
            guard time > latest.time else { return }
        }
        samples.append(Sample(angle: next, time: time))
        // A few samples cover the presentation delay and a delayed report without
        // allowing this small history to grow indefinitely.
        if samples.count > 6 { samples.removeFirst(samples.count - 6) }
    }

    mutating func value(at time: Double) -> Double? {
        guard time.isFinite, let first = samples.first, let latest = samples.last else { return nil }
        let presentationTime = time - Self.presentationDelay
        guard samples.count > 1, presentationTime > first.time else { return first.angle }
        guard presentationTime < latest.time else { return latest.angle }

        for index in 1..<samples.count {
            let left = samples[index - 1]
            let right = samples[index]
            guard presentationTime <= right.time else { continue }
            let interval = right.time - left.time
            guard interval > 0 else { return right.angle }
            let fraction = min(max((presentationTime - left.time) / interval, 0), 1)
            return left.angle + (right.angle - left.angle) * fraction
        }
        return latest.angle
    }

    mutating func reset() { self = HingeMotion() }
}
