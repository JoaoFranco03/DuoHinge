import Foundation

@main
enum PolicyChecks {
    static func main() {
        var idle = HingeIdlePolicy()
        precondition(!idle.isIdle(angle: 60, at: 0))
        precondition(!idle.isIdle(angle: 60, at: 0.9))
        precondition(idle.isIdle(angle: 60, at: 1))
        precondition(!idle.isIdle(angle: 61, at: 1.1))
        precondition(!idle.isIdle(angle: 61, at: 2))
        precondition(idle.isIdle(angle: 61, at: 2.2))
        var motion = HingeMotion()
        precondition(motion.value(at: 0) == nil)
        motion.receive(angle: 80, at: 1)
        precondition(motion.value(at: 1) == 80)
        motion.receive(angle: 70, at: 1.1)
        var previousPrediction = 80.0
        for i in 1...12 {
            let value = motion.value(at: 1.1 + Double(i) / 120)!
            precondition(value >= 70 && value <= previousPrediction)
            previousPrediction = value
        }
        motion.receive(angle: 75, at: 1.21)
        // Reversals interpolate through their real reports without overshooting.
        let reversal = motion.value(at: 1.36)!
        precondition((70...80).contains(reversal))
        // Duplicate/out-of-order deliveries cannot alter the retained history.
        motion.receive(angle: 20, at: 1.1)
        precondition(abs(motion.value(at: 1.5)! - 75) < 0.5)
        motion.receive(angle: .nan, at: 2)
        precondition(abs(motion.value(at: 2)! - 75) < 0.01)
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
        // A fast, 10 Hz physical movement should be reconstructed in small
        // display-paced increments rather than rendering each sensor report as a step.
        var steppedMotion = HingeMotion()
        steppedMotion.receive(angle: 90, at: 0)
        var previousFrame = 90.0
        var largestFrameDelta = 0.0
        for frame in 1...36 {
            let time = Double(frame) / 120
            if frame % 12 == 0 {
                steppedMotion.receive(angle: 90 - time * 120, at: time)
            }
            let currentFrame = steppedMotion.value(at: time)!
            largestFrameDelta = max(largestFrameDelta, abs(currentFrame - previousFrame))
            previousFrame = currentFrame
        }
        precondition(largestFrameDelta < 2)
        // Reproduce slow movement with the measured 400 ms report gaps.
        var sparse = HingeMotion()
        sparse.receive(angle: 85, at: 0)
        var previousSparse = 85.0
        for frame in 1...240 {
            let time = Double(frame) / 120
            let before = sparse.value(at: time)!
            if frame % 48 == 0 {
                sparse.receive(angle: 85 - Double(frame / 48) * 4, at: time)
                precondition(abs(sparse.value(at: time)! - before) < 1e-9)
            }
            let current = sparse.value(at: time)!
            precondition(current <= previousSparse + 1e-9)
            if frame > 60 { precondition(previousSparse - current > 0.00001) }
            precondition(previousSparse - current < 0.5)
            previousSparse = current
        }
        precondition(abs(sparse.value(at: 5)! - 65) < 0.01)
        print("Motion continuity, sparse reports, reversal, settling, and frame-rate checks passed.")
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
