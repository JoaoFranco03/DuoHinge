import CoreVideo

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
