import Foundation
import Metal

// Run with the built app's default.metallib path. No screen capture or overlay is opened.
@main
enum MetalChecks {
    static func main() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let library = try device.makeLibrary(URL: URL(fileURLWithPath: CommandLine.arguments[1]))
        let queue = device.makeCommandQueue()!
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb, width: 32, height: 24, mipmapped: false)
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .shared
        let source = device.makeTexture(descriptor: descriptor)!
        var pixels = [UInt8](repeating: 255, count: 32 * 24 * 4)
        for y in 0..<24 {
            for x in 0..<32 {
                let i = (y * 32 + x) * 4
                pixels[i] = UInt8(x * 7)
                pixels[i + 1] = UInt8(y * 9)
                pixels[i + 2] = 127
            }
        }
        pixels.withUnsafeBytes {
            source.replace(
                region: MTLRegionMake2D(0, 0, 32, 24), mipmapLevel: 0,
                withBytes: $0.baseAddress!, bytesPerRow: 128)
        }
        var input = source
        let command = queue.makeCommandBuffer()!
        for name in ["hingeProject", "hingeBlurX", "hingeBlurY", "hingeDispersion"] {
            let pipeline = MTLRenderPipelineDescriptor()
            pipeline.vertexFunction = library.makeFunction(name: "hingeVertex")
            pipeline.fragmentFunction = library.makeFunction(name: name)
            pipeline.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
            let state = try device.makeRenderPipelineState(descriptor: pipeline)
            let output = device.makeTexture(descriptor: descriptor)!
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = output
            pass.colorAttachments[0].loadAction = .dontCare
            pass.colorAttachments[0].storeAction = .store
            let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
            // Half-size point bounds also check Retina coordinate conversion.
            let uniforms = [SIMD4<Float>(16, 12, 0, 1), SIMD4<Float>(1, 1, 0, 0), SIMD4<Float>(0.5, 0.35, 2.8, 0)]
            encoder.setRenderPipelineState(state)
            encoder.setFragmentTexture(input, index: 0)
            uniforms.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 0) }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            input = output
        }
        command.commit()
        command.waitUntilCompleted()
        precondition(command.status == .completed, String(describing: command.error))
        var result = [UInt8](repeating: 0, count: pixels.count)
        result.withUnsafeMutableBytes {
            input.getBytes(
                $0.baseAddress!, bytesPerRow: 128,
                from: MTLRegionMake2D(0, 0, 32, 24), mipmapLevel: 0)
        }
        precondition(
            zip(pixels, result).allSatisfy { abs(Int($0) - Int($1)) <= 1 },
            "Neutral geometry, orientation, alpha, or sRGB roundtrip changed")
        print("Metal pipelines and Retina neutral-frame color/orientation checks passed.")
    }
}
