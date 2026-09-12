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
    private var source: ObjectIdentifier?

    func activate(_ owner: AnyObject?) {
        lock.lock()
        source = owner.map { ObjectIdentifier($0) }
        buffer = nil
        lock.unlock()
    }

    func replace(with next: CVPixelBuffer, from owner: AnyObject) {
        lock.lock()
        defer { lock.unlock() }
        guard source == ObjectIdentifier(owner) else { return }
        buffer = next
    }

    func snapshot() -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}
