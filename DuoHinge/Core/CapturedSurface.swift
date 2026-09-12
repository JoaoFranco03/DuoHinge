import CoreVideo
import Foundation

/// Immutable ownership token for read-only ScreenCaptureKit surfaces.
/// Neither CPU nor GPU writes to these buffers. Retaining the token keeps the
/// capture pool from recycling its surface until the consumer has finished.
nonisolated final class CapturedSurface: @unchecked Sendable {
    let buffer: CVPixelBuffer
    let texture: CVMetalTexture?

    init(buffer: CVPixelBuffer, texture: CVMetalTexture? = nil) {
        self.buffer = buffer
        self.texture = texture
    }
}

/// A lock-protected latest-frame slot shared by ScreenCaptureKit's callback queue
/// and the display renderer. Replacing a frame never waits for the main actor;
/// the renderer retains the surface it encodes until GPU completion.
nonisolated final class LatestCapturedFrame: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: CVPixelBuffer?

    func replace(with next: CVPixelBuffer?) {
        lock.lock()
        buffer = next
        lock.unlock()
    }

    func snapshot() -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}
