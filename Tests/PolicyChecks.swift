import Foundation

@main
enum PolicyChecks {
    static func main() {
        var motion = HingeMotion()
        precondition(motion.value(at: 0) == nil)
        motion.receive(angle: 80, at: 1)
        precondition(motion.value(at: 1) == 80)
        motion.receive(angle: 70, at: 1.1)
        for i in 1...12 {
            let value = motion.value(at: 1.1 + Double(i) / 120)!
            precondition(value >= 67 && value <= 80)
        }
        let beforeReversal = motion.value(at: 1.2)!
        motion.receive(angle: 75, at: 1.21)
        let afterReversal = motion.value(at: 1.23)!
        precondition(afterReversal > beforeReversal)
        // Duplicate/out-of-order deliveries cannot refresh stale velocity.
        motion.receive(angle: 20, at: 1.1)
        precondition(motion.value(at: 1.5) == 75)
        motion.receive(angle: .nan, at: 2)
        precondition(motion.value(at: 2) == 75)
        motion.reset()
        precondition(motion.value(at: 3) == nil)
        // Compare the same 10 Hz movement at 60 Hz and 120 Hz presentation.
        func replay(fps: Int) -> Double {
            var filter = HingeMotion()
            filter.receive(angle: 90, at: 0)
            for frame in 0...(fps / 2) {
                let time = Double(frame) / Double(fps)
                if frame % (fps / 10) == 0 {
                    filter.receive(angle: 90 - time * 30, at: time)
                }
                _ = filter.value(at: time)
            }
            return filter.value(at: 0.5)!
        }
        precondition(abs(replay(fps: 60) - replay(fps: 120)) < 0.5)
        print("Prediction bounds, reversal, stale-data, reset, and frame-rate checks passed.")
        precondition(HingePolicy.closeProgress(angle: 90) == 0)
        precondition(HingePolicy.closeProgress(angle: 135) == 0)
        precondition(HingePolicy.closeProgress(angle: 0) == 1)
        precondition(HingePolicy.closeProgress(angle: -10) == 1)
        precondition(HingePolicy.closeProgress(angle: .nan) == 0)
        precondition(HingePolicy.closeProgress(angle: .infinity) == 0)
        precondition(abs(HingePolicy.closeProgress(angle: 89) - 1.0 / 90) < 1e-12)

        var previous = 1.0
        for angle in 0...135 {
            let progress = HingePolicy.closeProgress(angle: Double(angle))
            precondition((0...1).contains(progress) && progress <= previous)
            previous = progress
        }

        for threshold in [75.0, 90.0, 105.0, 120.0, 135.0] {
            precondition(HingePolicy.closeProgress(angle: threshold, thresholdAngle: threshold) == 0)
            precondition(HingePolicy.closeProgress(angle: threshold + 10, thresholdAngle: threshold) == 0)
            precondition(HingePolicy.closeProgress(angle: 0, thresholdAngle: threshold) == 1)
            precondition(abs(HingePolicy.closeProgress(angle: threshold / 2, thresholdAngle: threshold) - 0.5) < 1e-12)
        }

        for builtIn in [false, true] {
            for active in [false, true] {
                for mirrored in [false, true] {
                    precondition(
                        HingePolicy.allowsDisplay(builtIn: builtIn, active: active, mirrored: mirrored)
                            == (builtIn && active && !mirrored))
                }
            }
        }
        precondition(HingePolicy.shouldPrewarmCapture(angle: 93, thresholdAngle: 90, prewarmMargin: 3))
        precondition(HingePolicy.shouldPrewarmCapture(angle: 90, thresholdAngle: 90, prewarmMargin: 3))
        precondition(HingePolicy.shouldPrewarmCapture(angle: 45, thresholdAngle: 90, prewarmMargin: 3))
        precondition(!HingePolicy.shouldPrewarmCapture(angle: 93.1, thresholdAngle: 90, prewarmMargin: 3))
        precondition(!HingePolicy.shouldPrewarmCapture(angle: 120, thresholdAngle: 90, prewarmMargin: 3))
        precondition(!HingePolicy.shouldPrewarmCapture(angle: .nan, thresholdAngle: 90, prewarmMargin: 3))
        precondition(!HingePolicy.shouldPrewarmCapture(angle: .infinity, thresholdAngle: 90, prewarmMargin: 3))

        print("Angle and display policy checks passed.")
        var retry = CaptureRecoveryPolicy()
        precondition(retry.canAttempt(at: 0))
        retry.recordAttempt(at: 0)
        precondition(!retry.canAttempt(at: 0.5))
        precondition(retry.canAttempt(at: 1))
        retry.recordAttempt(at: 1)
        precondition(!retry.canAttempt(at: 3))
        precondition(retry.canAttempt(at: 4))
        retry.recordAttempt(at: 4)
        precondition(!retry.canAttempt(at: 1000))
        retry.reset()
        precondition(retry.attempts == 0 && retry.canAttempt(at: 1000))
        print("Bounded capture recovery checks passed.")
        precondition(HingeViewpoint.allCases.map(\.rawValue) == ["Front", "Desk"])
        precondition(HingeViewpoint.front.eye == SIMD3<Float>(0.5, 0.5, 2.8))
        precondition(HingeViewpoint.desk.eye == SIMD3<Float>(0.5, 0.35, 2.8))
        for viewpoint in HingeViewpoint.allCases {
            let eye = viewpoint.eye
            precondition(eye.z > 1)  // The rotating glass never reaches the assumed eye.
            for step in 0...90 {
                let angle = Double(step) * .pi / 180
                let depth = Double(eye.z) - sin(angle)
                precondition(depth > 0 && depth.isFinite)
            }
            precondition(HingeViewpoint(rawValue: viewpoint.rawValue) == viewpoint)
        }
        print("Front/Desk viewpoint checks passed.")
    }
}
