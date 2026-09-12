import Foundation

/// Pure decisions shared by the runtime and regression checks.
enum HingePolicy {
    static func closeProgress(angle: Double, thresholdAngle: Double = 90.0) -> Double {
        guard angle.isFinite, thresholdAngle > 0 else { return 0 }
        return min(max((thresholdAngle - angle) / thresholdAngle, 0), 1)
    }

    static func allowsDisplay(builtIn: Bool, active: Bool, mirrored: Bool) -> Bool {
        builtIn && active && !mirrored
    }

    static func shouldPrewarmCapture(angle: Double, thresholdAngle: Double = 90.0, prewarmMargin: Double = 3.0) -> Bool
    {
        guard angle.isFinite, thresholdAngle > 0 else { return false }
        return angle <= (thresholdAngle + prewarmMargin)
    }

}
/// Hinge inactivity, not keyboard or mouse inactivity. Identical HID reports
/// do not keep the effect awake; any changed angle resumes it.
struct HingeIdlePolicy {
    private var lastAngle: Double?
    private var lastMovement = 0.0

    mutating func isIdle(angle: Double, at time: Double) -> Bool {
        guard angle.isFinite, time.isFinite else { return false }
        if lastAngle != angle {
            lastAngle = angle
            lastMovement = time
        }
        return time - lastMovement >= 1.0
    }
}
