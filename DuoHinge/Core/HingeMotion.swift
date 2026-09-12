import Foundation

/// Presentation-only estimate. Raw sensor angles still control capture and visibility.
/// Prediction is limited to 60 ms and 3 degrees, then withdrawn when reports go stale.
struct HingeMotion {
    private var angle: Double?
    private var sampleTime = 0.0
    private var velocity = 0.0
    private var presented: Double?
    private var frameTime: Double?
    private var correctionUntil = 0.0

    mutating func receive(angle next: Double, at time: Double) {
        guard next.isFinite, time.isFinite, (0...360).contains(next) else { return }
        if let angle {
            guard time > sampleTime else { return }
            let dt = time - sampleTime
            let delta = next - angle
            if dt >= 0.02 && dt <= 0.25 && abs(delta) >= 1 {
                let measured = min(max(delta / dt, -240), 240)
                if measured * velocity < 0 {
                    // Do not carry momentum in the old direction through a reversal.
                    velocity = measured
                    correctionUntil = time + 0.05
                } else {
                    velocity = 0.75 * measured + 0.25 * velocity
                }
            } else {
                velocity = 0
            }
        } else {
            presented = next
        }
        angle = next
        sampleTime = time
    }

    mutating func value(at time: Double) -> Double? {
        guard let angle, time.isFinite else { return nil }
        let age = max(time - sampleTime, 0)
        let taper = 1 - min(max((age - 0.10) / 0.10, 0), 1)
        let lead = min(max(velocity * min(age, 0.060), -3), 3) * taper
        let target = min(max(angle + lead, 0), 360)
        let dt = min(max(time - (frameTime ?? time), 0), 0.05)
        let tau = time < correctionUntil ? 0.012 : 0.025
        var output = presented ?? angle
        output += (target - output) * (1 - exp(-dt / tau))
        if age >= 0.25 || abs(target - output) < 0.001 { output = target }
        presented = output
        frameTime = time
        return output
    }

    mutating func reset() { self = HingeMotion() }
}
