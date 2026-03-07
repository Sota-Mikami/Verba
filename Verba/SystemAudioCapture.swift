import Foundation
import ScreenCaptureKit
import AVFoundation
import os

private let logger = Logger(subsystem: "com.sotamikami.verba", category: "SystemAudio")

/// Captures system audio using ScreenCaptureKit and converts to 16kHz mono Float32.
class SystemAudioCapture: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var capturedData = Data()
    private let targetSampleRate: Double = 16000.0
    private let dataQueue = DispatchQueue(label: "com.sotamikami.verba.systemaudio")

    /// Check and request screen recording permission (required even for audio-only).
    static func requestPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            logger.warning("Screen capture permission denied: \(error.localizedDescription)")
            return false
        }
    }

    func startCapture() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let selfBundleID = Bundle.main.bundleIdentifier ?? ""
        let excludedApps = content.applications.filter { $0.bundleIdentifier == selfBundleID }
        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.channelCount = 1
        config.sampleRate = 48000
        // Minimize video capture — we only need audio
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        dataQueue.sync { capturedData = Data() }

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
        try await stream.startCapture()
        self.stream = stream
        logger.info("System audio capture started")
    }

    func stopCapture() async -> Data {
        if let stream {
            try? await stream.stopCapture()
            self.stream = nil
        }
        let data = dataQueue.sync { capturedData }
        logger.info("System audio capture stopped, \(data.count) bytes")
        return data
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let blockBuffer = sampleBuffer.dataBuffer else { return }

        guard let formatDesc = sampleBuffer.formatDescription,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else { return }

        let sourceSampleRate = asbd.mSampleRate
        let length = CMBlockBufferGetDataLength(blockBuffer)

        var rawData = Data(count: length)
        _ = rawData.withUnsafeMutableBytes { ptr in
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
        }

        let sourceFloats = rawData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        let ratio = sourceSampleRate / targetSampleRate
        let outputCount = Int(Double(sourceFloats.count) / ratio)

        var resampled = [Float](repeating: 0, count: outputCount)
        for i in 0..<outputCount {
            let srcIndex = Int(Double(i) * ratio)
            if srcIndex < sourceFloats.count {
                resampled[i] = sourceFloats[srcIndex]
            }
        }

        let bytes = resampled.withUnsafeBufferPointer { Data(buffer: $0) }
        dataQueue.sync { capturedData.append(bytes) }
    }

    enum CaptureError: Error {
        case noDisplay
    }
}
