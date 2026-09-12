import Foundation

/// Display-paced critically damped motion; no extrapolated angle or fixed buffer.
/// Sparse HID reports update the target without jumping the displayed position.
struct HingeMotion {
    private var target: Double?
    private var sampleTime = 0.0
    private var frameTime = 0.0
    private var position = 0.0
    private var velocity = 0.0
    private var cadence = 0.1

    mutating func receive(angle next: Double, at time: Double) {
        guard next.isFinite, time.isFinite, (0...360).contains(next) else { return }
        if target != nil {
            guard time > sampleTime else { return }
            // Integrate the old target first; a report must not rewrite elapsed motion.
            _ = value(at: time)
            let interval = time - sampleTime
            if interval <= 0.6 {
                cadence = max(0.1, min(interval, 0.4))
            }
        } else {
            position = next
            frameTime = time
        }
        target = next
        sampleTime = time
    }

    mutating func value(at time: Double) -> Double? {
        guard let target, time.isFinite else { return nil }
        guard time > frameTime else { return position }
        let dt = time - frameTime
        frameTime = time
        // Broaden the response for 200–400 ms reports instead of exhausting a
        // 120 ms segment and holding still. This intentionally trades latency
        // for continuity; the hardware cannot supply the missing real angles.
        let omega = min(20.0, 3.0 / cadence)
        let error = position - target
        let coefficient = velocity + omega * error
        let decay = exp(-omega * dt)
        let next = target + (error + coefficient * dt) * decay
        velocity = (velocity - omega * coefficient * dt) * decay
        // Prevent momentum from crossing the target after an abrupt reversal.
        if (position - target) * (next - target) < 0 {
            position = target
            velocity = 0
        } else {
            position = min(max(next, 0), 360)
        }
        return position
    }

    mutating func reset() { self = HingeMotion() }
}
