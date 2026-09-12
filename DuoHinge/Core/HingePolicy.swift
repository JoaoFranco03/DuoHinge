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
