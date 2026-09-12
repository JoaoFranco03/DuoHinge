import AppKit
import CoreVideo
import MetalKit

/// Retains the capture surface through GPU completion. No CPU image conversion or readback.
@MainActor
final class HingeMetalRenderer: NSObject, MTKViewDelegate {
    let view: MTKView
    var progress: Float = 0
    var style: HingeStyle = .frosted
    var viewpoint: HingeViewpoint = .desk
    var thresholdAngle = 90.0
    private var motion = HingeMotion()

    func receive(angle: Double, at time: Double) {
        motion.receive(angle: angle, at: time)
    }

    func resetMotion() {
        motion.reset()
        progress = 0
    }
    private let capture: ScreenCaptureService
    private let queue: MTLCommandQueue
    private var cache: CVMetalTextureCache
    private var pipelines: [MTLRenderPipelineState] = []
    private var targets: [MTLTexture] = []
    // One GPU frame at a time: skip work instead of queuing old hinge positions.
    private let frameSlot = DispatchSemaphore(value: 1)

    init(capture: ScreenCaptureService) throws {
        guard let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue(),
            let library = device.makeDefaultLibrary()
        else { throw RendererError.unavailable }
        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) == kCVReturnSuccess,
            let cache
        else { throw RendererError.unavailable }
        self.cache = cache
        self.queue = queue
        self.capture = capture
        view = MTKView(frame: .zero, device: device)
        super.init()
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.isPaused = true
        view.layer?.isOpaque = false
        view.delegate = self
        for name in ["hingeProject", "hingeBlurX", "hingeBlurY", "hingeDispersion"] {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "hingeVertex")
            descriptor.fragmentFunction = library.makeFunction(name: name)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
            pipelines.append(try device.makeRenderPipelineState(descriptor: descriptor))
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        targets.removeAll()
    }

    /// Clear a reused panel before registering it for capture exclusion.
    func clear() {
        resetMotion()
        view.isPaused = true
        view.draw()
    }

    func draw(in view: MTKView) {
        guard frameSlot.wait(timeout: .now()) == .success else { return }
        var committed = false
        defer { if !committed { frameSlot.signal() } }
        guard let drawable = view.currentDrawable,
            let command = queue.makeCommandBuffer()
        else { return }
        // Evaluate immediately before encoding, paced by MTKView's display refresh.
        if !view.isPaused, let angle = motion.value(at: ProcessInfo.processInfo.systemUptime) {
            progress = Float(HingePolicy.closeProgress(angle: angle, thresholdAngle: thresholdAngle))
        }
        let buffer = capture.pixelBuffer
        var surface: CVMetalTexture?
        if progress > 0, let buffer {
            let result = CVMetalTextureCacheCreateTextureFromImage(
                nil, cache, buffer, nil, .bgra8Unorm_srgb,
                CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 0, &surface)
            guard result == kCVReturnSuccess else { return }
        }
        if let surface, let input = CVMetalTextureGetTexture(surface) {
            let width = drawable.texture.width
            let height = drawable.texture.height
            if targets.first?.width != width || targets.first?.height != height {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
                descriptor.usage = [.renderTarget, .shaderRead]
                descriptor.storageMode = .private
                targets = (0..<3).compactMap { _ in view.device?.makeTexture(descriptor: descriptor) }
            }
            guard targets.count == 3, view.bounds.width > 0, view.bounds.height > 0 else { return }
            let uniforms = [
                SIMD4<Float>(Float(view.bounds.width), Float(view.bounds.height), progress, style.blur),
                SIMD4<Float>(style.darkness, style.chromaticAberration, 0, 0),
                SIMD4<Float>(viewpoint.eye, 0),
            ]
            let count = style.chromaticAberration > 0 ? 4 : 3
            var source = input
            for index in 0..<count {
                let destination = index == count - 1 ? drawable.texture : targets[index]
                let pass = MTLRenderPassDescriptor()
                pass.colorAttachments[0].texture = destination
                pass.colorAttachments[0].loadAction = .dontCare
                pass.colorAttachments[0].storeAction = .store
                guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
                encoder.setRenderPipelineState(pipelines[index])
                encoder.setFragmentTexture(source, index: 0)
                uniforms.withUnsafeBytes {
                    encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 0)
                }
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                encoder.endEncoding()
                source = destination
            }
        } else {
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = drawable.texture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            pass.colorAttachments[0].storeAction = .store
            guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
            encoder.endEncoding()
        }
        let slot = frameSlot
        let retainedSurface = buffer.map { CapturedSurface(buffer: $0, texture: surface) }
        command.addCompletedHandler { [retainedSurface] _ in
            withExtendedLifetime(retainedSurface) {}
            slot.signal()
        }
        command.present(drawable)
        command.commit()
        committed = true
    }

    private enum RendererError: Error { case unavailable }
}
