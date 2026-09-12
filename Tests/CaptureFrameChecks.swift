import CoreVideo
import Foundation

@main
enum CaptureFrameChecks {
    static func main() {
        let slot = LatestCapturedFrame()
        let old = NSObject()
        let current = NSObject()
        var pixel: CVPixelBuffer?
        precondition(CVPixelBufferCreate(nil, 2, 2, kCVPixelFormatType_32BGRA, nil, &pixel) == kCVReturnSuccess)
        let buffer = pixel!
        slot.activate(old)
        slot.replace(with: buffer, from: old)
        precondition(slot.snapshot() != nil)
        slot.activate(nil)
        slot.replace(with: buffer, from: old)
        precondition(slot.snapshot() == nil)
        slot.activate(current)
        slot.replace(with: buffer, from: old)
        precondition(slot.snapshot() == nil)
        slot.replace(with: buffer, from: current)
        precondition(slot.snapshot() != nil)
        print("Stopped and superseded capture callbacks are rejected.")
    }
}
