import AVFoundation
import CoreImage
import WebRTC

/// Serial encoding with at most two queued frames. Drops frames rather than building latency.
final class ScreenRecorder: NSObject, RTCVideoRenderer {
    private let queue = DispatchQueue(label: "still.recording", qos: .userInitiated)
    private let slots = DispatchSemaphore(value: 2)
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var destination: URL?
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var origin: Int64?
    private var lastTime: Int64 = -1
    private var canvas = CGSize.zero
    private var failure: Error?
    private var errorReported = false
    var onFailure: ((String) -> Void)?
    func start(at url: URL) { queue.async { self.destination = url; self.origin = nil; self.lastTime = -1; self.failure = nil; self.errorReported = false } }
    func setSize(_ size: CGSize) {}
    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame, slots.wait(timeout: .now()) == .success else { return }
        queue.async {
            defer { self.slots.signal() }
            guard let url = self.destination, self.failure == nil else { return }
            do {
                if self.origin == nil { self.origin = frame.timeStampNs }
                let elapsed = frame.timeStampNs - (self.origin ?? frame.timeStampNs)
                guard elapsed >= 0, self.lastTime < 0 || elapsed - self.lastTime >= 41_666_666 else { return }
                guard elapsed < 1_800_000_000_000 else { throw RecordingError.limit }
                if let available = try url.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage, available < 100_000_000 { throw RecordingError.storage }
                var image = try self.image(frame)
                if self.writer == nil { try self.prepare(url: url, size: image.extent.size) }
                guard let writer = self.writer, writer.status == .writing, let input = self.input, input.isReadyForMoreMediaData, let adaptor = self.adaptor else { return }
                let scale = min(self.canvas.width / image.extent.width, self.canvas.height / image.extent.height)
                image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY)).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                image = image.transformed(by: CGAffineTransform(translationX: (self.canvas.width-image.extent.width)/2, y: (self.canvas.height-image.extent.height)/2))
                let background = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: self.canvas))
                var buffer: CVPixelBuffer?
                guard let pool = adaptor.pixelBufferPool, CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else { throw RecordingError.encoding }
                self.context.render(image.composited(over: background), to: buffer)
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: elapsed, timescale: 1_000_000_000)) else { throw writer.error ?? RecordingError.encoding }
                self.lastTime = elapsed
            } catch {
                self.failure = error
                if !self.errorReported { self.errorReported = true; self.onFailure?(error.localizedDescription) }
            }
        }
    }
    func finish(_ completion: @escaping (Result<URL, Error>) -> Void) {
        queue.async {
            let url = self.destination; self.destination = nil
            guard let writer = self.writer, let url else { if let url { try? FileManager.default.removeItem(at: url) }; completion(.failure(RecordingError.noFrames)); return }
            if writer.status != .writing {
                self.writer = nil; self.input = nil; self.adaptor = nil
                try? FileManager.default.removeItem(at: url); completion(.failure(writer.error ?? RecordingError.encoding)); return
            }
            self.input?.markAsFinished(); self.writer = nil; self.input = nil; self.adaptor = nil
            writer.finishWriting {
                if writer.status == .completed { completion(.success(url)) }
                else { try? FileManager.default.removeItem(at: url); completion(.failure(writer.error ?? RecordingError.encoding)) }
            }
        }
    }
    private func prepare(url: URL, size: CGSize) throws {
        let ratio = min(1, 1280/max(size.width,size.height))
        canvas = CGSize(width: max(2, floor(size.width*ratio/2)*2), height: max(2, floor(size.height*ratio/2)*2))
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(canvas.width), AVVideoHeightKey: Int(canvas.height), AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 4_000_000, AVVideoExpectedSourceFrameRateKey: 24]])
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { throw RecordingError.encoding }; writer.add(input)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:Int(canvas.width),kCVPixelBufferHeightKey as String:Int(canvas.height),kCVPixelBufferIOSurfacePropertiesKey as String:[:]])
        guard writer.startWriting() else { throw writer.error ?? RecordingError.encoding }; writer.startSession(atSourceTime: .zero)
        self.writer = writer; self.input = input; self.adaptor = adaptor
    }
    private func image(_ frame: RTCVideoFrame) throws -> CIImage {
        let image: CIImage
        if let native = frame.buffer as? RTCCVPixelBuffer { image = CIImage(cvPixelBuffer: native.pixelBuffer) }
        else {
            let i420 = frame.buffer.toI420(); let width = Int(i420.width), height = Int(i420.height)
            var pixel: CVPixelBuffer?
            guard CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, [kCVPixelBufferIOSurfacePropertiesKey as String:[:]] as CFDictionary, &pixel) == kCVReturnSuccess, let pixel else { throw RecordingError.encoding }
            CVPixelBufferLockBaseAddress(pixel, [])
            defer { CVPixelBufferUnlockBaseAddress(pixel, []) }
            guard let y = CVPixelBufferGetBaseAddressOfPlane(pixel, 0), let uv = CVPixelBufferGetBaseAddressOfPlane(pixel, 1) else { throw RecordingError.encoding }
            for row in 0..<height { memcpy(y.advanced(by: row*CVPixelBufferGetBytesPerRowOfPlane(pixel,0)), i420.dataY.advanced(by: row*Int(i420.strideY)), width) }
            for row in 0..<((height+1)/2) {
                let target = uv.advanced(by: row*CVPixelBufferGetBytesPerRowOfPlane(pixel,1)).assumingMemoryBound(to: UInt8.self)
                for column in 0..<((width+1)/2) { target[column*2] = i420.dataU[row*Int(i420.strideU)+column]; target[column*2+1] = i420.dataV[row*Int(i420.strideV)+column] }
            }
            image = CIImage(cvPixelBuffer: pixel)
        }
        switch frame.rotation {
        case ._90: return image.oriented(.right)
        case ._180: return image.oriented(.down)
        case ._270: return image.oriented(.left)
        default: return image
        }
    }
}
private enum RecordingError: LocalizedError {
    case limit, storage, encoding, noFrames
    var errorDescription: String? { switch self {
    case .limit: return "The 30-minute recording limit was reached. Your completed video will be saved."
    case .storage: return "Storage is getting low. Recording stopped to protect your device."
    case .encoding: return "The recording could not be encoded. Try a lighter screen-sharing quality."
    case .noFrames: return "No screen frames were received to record."
    } }
}
