import AVFoundation
import CoreImage
import CoreVideo
import Darwin
import Foundation
import ImageIO
import Metal

private let framesPerSecond: Int32 = 60
private let durationSeconds = 3.0
private let frameCount = Int(durationSeconds * Double(framesPerSecond))
private let maximumEdge = 1_920.0

// This compute kernel is the supplied SwiftUI layerEffect shader adapted only
// to read two Metal textures and write a video frame. The ripple displacement
// and lighting equations are intentionally unchanged.
private let rippleShaderSource = #"""
#include <metal_stdlib>
using namespace metal;

struct RippleParameters {
    float2 origin;
    float time;
    float amplitude;
    float frequency;
    float decay;
    float speed;
    float blend;
    uint2 size;
};

kernel void ripple_transition(
    texture2d<half, access::sample> beforeLayer [[texture(0)]],
    texture2d<half, access::sample> afterLayer [[texture(1)]],
    texture2d<half, access::write> output [[texture(2)]],
    constant RippleParameters& parameters [[buffer(0)]],
    uint2 pixel [[thread_position_in_grid]]
) {
    if (any(pixel >= parameters.size)) {
        return;
    }

    constexpr sampler layerSampler(
        coord::pixel,
        address::clamp_to_edge,
        filter::linear
    );

    float2 position = float2(pixel) + 0.5;

    // The distance of the current pixel position from origin
    float distance = length(position - parameters.origin);

    // The amount of time it takes for the ripple to arrive at the current pixel
    float delay = distance / parameters.speed;

    // Adjust for delay, clamp to 0
    float adjustedTime = max(0.0, parameters.time - delay);

    // The ripple is a sine wave scaled by exponential decay
    float rippleAmount =
        parameters.amplitude
        * sin(parameters.frequency * adjustedTime)
        * exp(-parameters.decay * adjustedTime);

    // A vector that points away from origin
    float2 n = distance > 0
        ? normalize(position - parameters.origin)
        : float2(0, 0);

    // New position moves toward or away from origin based on ripple
    float2 newPosition = position + rippleAmount * n;

    // Sample the composited layer at the new position
    half4 beforeColor = beforeLayer.sample(layerSampler, newPosition);
    half4 afterColor = afterLayer.sample(layerSampler, newPosition);
    half4 color = mix(beforeColor, afterColor, half(parameters.blend));

    // Lighten or darken based on ripple amount
    color.rgb += half(0.3 * (rippleAmount / parameters.amplitude)) * color.a;

    output.write(color, pixel);
}
"""#

private struct RippleParameters {
    var origin: SIMD2<Float>
    var time: Float
    var amplitude: Float
    var frequency: Float
    var decay: Float
    var speed: Float
    var blend: Float
    var size: SIMD2<UInt32>
}

private struct RenderSummary: Codable {
    let width: Int
    let height: Int
    let frames: Int
    let durationSeconds: Double
    let framesPerSecond: Int32
}

private enum RenderError: LocalizedError {
    case invalidArguments
    case invalidOrigin
    case imageUnreadable
    case invalidImageSize
    case metalUnavailable
    case shaderUnavailable
    case textureUnavailable
    case encoderUnavailable
    case frameUnavailable
    case renderFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "The renderer received an invalid job."
        case .invalidOrigin:
            return "Choose a ripple origin inside the frame."
        case .imageUnreadable:
            return "One of the selected images could not be decoded."
        case .invalidImageSize:
            return "The before image has invalid dimensions."
        case .metalUnavailable:
            return "Metal is not available on this Mac."
        case .shaderUnavailable:
            return "The ripple shader could not be prepared."
        case .textureUnavailable:
            return "A Metal texture could not be created."
        case .encoderUnavailable:
            return "The H.264 video encoder could not be started."
        case .frameUnavailable:
            return "A video frame could not be allocated."
        case .renderFailed:
            return "Metal could not render a video frame."
        case .writeFailed:
            return "The MP4 could not be written."
        }
    }
}

private final class RippleRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let coreImageContext: CIContext
    private var textureCache: CVMetalTextureCache

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue()
        else {
            throw RenderError.metalUnavailable
        }

        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: rippleShaderSource, options: nil)
        } catch {
            throw RenderError.shaderUnavailable
        }

        guard let function = library.makeFunction(name: "ripple_transition") else {
            throw RenderError.shaderUnavailable
        }

        let pipeline: MTLComputePipelineState
        do {
            pipeline = try device.makeComputePipelineState(function: function)
        } catch {
            throw RenderError.shaderUnavailable
        }

        var textureCache: CVMetalTextureCache?
        let cacheStatus = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &textureCache
        )
        guard cacheStatus == kCVReturnSuccess, let textureCache else {
            throw RenderError.textureUnavailable
        }

        self.device = device
        self.commandQueue = commandQueue
        self.pipeline = pipeline
        self.coreImageContext = CIContext(mtlDevice: device)
        self.textureCache = textureCache
    }

    func render(
        beforeURL: URL,
        afterURL: URL,
        outputURL: URL,
        origin: SIMD2<Float>
    ) throws -> RenderSummary {
        let beforeImage = try loadOrientedImage(from: beforeURL)
        let afterImage = try loadOrientedImage(from: afterURL)

        let dimensions = try outputDimensions(for: beforeImage.extent)
        let width = dimensions.width
        let height = dimensions.height
        let beforeTexture = try makeInputTexture(
            from: beforeImage,
            width: width,
            height: height
        )
        let afterTexture = try makeInputTexture(
            from: afterImage,
            width: width,
            height: height
        )

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let bitrate = max(4_000_000, width * height * 6)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: framesPerSecond,
                AVVideoMaxKeyFrameIntervalKey: framesPerSecond,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        writerInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
        )

        guard writer.canAdd(writerInput) else {
            throw RenderError.encoderUnavailable
        }
        writer.add(writerInput)
        guard writer.startWriting() else {
            throw RenderError.encoderUnavailable
        }
        writer.startSession(atSourceTime: .zero)
        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            writer.cancelWriting()
            throw RenderError.encoderUnavailable
        }

        do {
            for frame in 0..<frameCount {
                while !writerInput.isReadyForMoreMediaData {
                    guard writer.status == .writing else {
                        throw RenderError.writeFailed
                    }
                    Thread.sleep(forTimeInterval: 0.001)
                }

                var pixelBuffer: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(
                    kCFAllocatorDefault,
                    pixelBufferPool,
                    &pixelBuffer
                ) == kCVReturnSuccess,
                let pixelBuffer else {
                    throw RenderError.frameUnavailable
                }

                try renderFrame(
                    frame,
                    into: pixelBuffer,
                    beforeTexture: beforeTexture,
                    afterTexture: afterTexture,
                    width: width,
                    height: height,
                    origin: origin
                )

                let presentationTime = CMTime(
                    value: Int64(frame),
                    timescale: framesPerSecond
                )
                guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                    throw RenderError.writeFailed
                }
            }
        } catch {
            writerInput.markAsFinished()
            writer.cancelWriting()
            throw error
        }

        writerInput.markAsFinished()
        let completion = DispatchSemaphore(value: 0)
        writer.finishWriting {
            completion.signal()
        }
        completion.wait()

        guard writer.status == .completed else {
            throw RenderError.writeFailed
        }

        return RenderSummary(
            width: width,
            height: height,
            frames: frameCount,
            durationSeconds: durationSeconds,
            framesPerSecond: framesPerSecond
        )
    }

    private func loadOrientedImage(from url: URL) throws -> CIImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw RenderError.imageUnreadable
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?
            .int32Value ?? 1
        guard (1...8).contains(orientation) else {
            throw RenderError.imageUnreadable
        }

        return CIImage(cgImage: cgImage).oriented(forExifOrientation: orientation)
    }

    private func renderFrame(
        _ frame: Int,
        into pixelBuffer: CVPixelBuffer,
        beforeTexture: MTLTexture,
        afterTexture: MTLTexture,
        width: Int,
        height: Int,
        origin: SIMD2<Float>
    ) throws {
        var cvTexture: CVMetalTexture?
        let textureStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        guard textureStatus == kCVReturnSuccess,
              let cvTexture,
              let outputTexture = CVMetalTextureGetTexture(cvTexture),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            throw RenderError.frameUnavailable
        }

        let seconds = Float(frame) / Float(framesPerSecond)
        let rippleStart: Float = 0.35
        let transitionStart: Float = 0.45
        let transitionEnd: Float = 1.65
        let transitionProgress = smoothstep(
            edge0: transitionStart,
            edge1: transitionEnd,
            value: seconds
        )
        var parameters = RippleParameters(
            origin: SIMD2(Float(width) * origin.x, Float(height) * origin.y),
            time: max(0, seconds - rippleStart),
            amplitude: 18,
            frequency: 16,
            decay: 5,
            speed: 1_500,
            blend: transitionProgress,
            size: SIMD2(UInt32(width), UInt32(height))
        )

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(beforeTexture, index: 0)
        encoder.setTexture(afterTexture, index: 1)
        encoder.setTexture(outputTexture, index: 2)
        encoder.setBytes(
            &parameters,
            length: MemoryLayout<RippleParameters>.stride,
            index: 0
        )

        let threadWidth = pipeline.threadExecutionWidth
        let threadHeight = max(1, pipeline.maxTotalThreadsPerThreadgroup / threadWidth)
        encoder.dispatchThreads(
            MTLSize(width: width, height: height, depth: 1),
            threadsPerThreadgroup: MTLSize(
                width: threadWidth,
                height: threadHeight,
                depth: 1
            )
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard commandBuffer.status == .completed else {
            throw RenderError.renderFailed
        }
    }

    private func makeInputTexture(
        from image: CIImage,
        width: Int,
        height: Int
    ) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw RenderError.textureUnavailable
        }

        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let fittedImage = aspectFill(image, into: bounds)
        // Core Image uses a bottom-left origin while Metal textures and video
        // pixel buffers use a top-left origin. Flip exactly once after applying
        // EXIF orientation so the encoded frame matches Finder and Preview.
        let textureImage = fittedImage.transformed(
            by: CGAffineTransform(
                a: 1,
                b: 0,
                c: 0,
                d: -1,
                tx: 0,
                ty: bounds.height
            )
        )
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw RenderError.textureUnavailable
        }
        coreImageContext.render(
            textureImage,
            to: texture,
            commandBuffer: nil,
            bounds: bounds,
            colorSpace: colorSpace
        )
        return texture
    }

    private func aspectFill(_ image: CIImage, into bounds: CGRect) -> CIImage {
        let extent = image.extent
        let normalized = image.transformed(
            by: CGAffineTransform(
                translationX: -extent.minX,
                y: -extent.minY
            )
        )
        let scale = max(
            bounds.width / extent.width,
            bounds.height / extent.height
        )
        let scaled = normalized.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )
        let translated = scaled.transformed(
            by: CGAffineTransform(
                translationX: (bounds.width - scaled.extent.width) * 0.5,
                y: (bounds.height - scaled.extent.height) * 0.5
            )
        )
        return translated.cropped(to: bounds)
    }

    private func outputDimensions(for extent: CGRect) throws -> (width: Int, height: Int) {
        guard extent.width.isFinite,
              extent.height.isFinite,
              extent.width >= 2,
              extent.height >= 2
        else {
            throw RenderError.invalidImageSize
        }

        let scale = min(1, maximumEdge / max(extent.width, extent.height))
        let width = max(2, (Int((extent.width * scale).rounded()) / 2) * 2)
        let height = max(2, (Int((extent.height * scale).rounded()) / 2) * 2)
        return (width, height)
    }

    private func smoothstep(edge0: Float, edge1: Float, value: Float) -> Float {
        let progress = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }
}

@main
private enum RippleRendererCommand {
    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count == 6 else {
            fail(RenderError.invalidArguments)
        }
        guard let originX = Float(arguments[4]),
              let originY = Float(arguments[5]),
              originX.isFinite,
              originY.isFinite,
              (0...1).contains(originX),
              (0...1).contains(originY)
        else {
            fail(RenderError.invalidOrigin)
        }

        let beforeURL = URL(fileURLWithPath: arguments[1])
        let afterURL = URL(fileURLWithPath: arguments[2])
        let outputURL = URL(fileURLWithPath: arguments[3])

        do {
            let renderer = try RippleRenderer()
            let summary = try renderer.render(
                beforeURL: beforeURL,
                afterURL: afterURL,
                outputURL: outputURL,
                origin: SIMD2(originX, originY)
            )
            let data = try JSONEncoder().encode(summary)
            FileHandle.standardOutput.write(data)
            exit(EXIT_SUCCESS)
        } catch {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            fail(error)
        }
    }

    private static func fail(_ error: Error) -> Never {
        let description = (error as? LocalizedError)?.errorDescription
            ?? "The ripple video could not be rendered."
        FileHandle.standardError.write(Data(description.utf8))
        exit(EXIT_FAILURE)
    }
}
