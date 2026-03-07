import AVFoundation
import CoreAudio
import Foundation

struct MicDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
}

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var systemCapture: SystemAudioCapture?
    private var micData = Data()
    private let sampleRate: Double = 16000.0
    var onAudioLevel: ((Float) -> Void)?
    var captureSystemAudio = false
    var selectedDeviceUID: String = "" // empty = system default

    /// List available audio input devices
    static func availableInputDevices() -> [MicDevice] {
        var propSize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propSize) == noErr else { return [] }
        let deviceCount = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propSize, &deviceIDs) == noErr else { return [] }

        var result: [MicDevice] = []
        for deviceID in deviceIDs {
            // Check if device has input streams
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &streamSize) == noErr,
                  streamSize > 0 else { continue }

            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameRef: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &nameRef) == noErr else { continue }

            // Get device UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uidRef: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uidRef) == noErr else { continue }

            result.append(MicDevice(id: deviceID, uid: uidRef as String, name: nameRef as String))
        }
        return result
    }

    func requestMicPermission() async -> Bool {
        if #available(macOS 14.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func startRecording() throws {
        let engine = AVAudioEngine()

        // Set input device if specified
        if !selectedDeviceUID.isEmpty {
            let devices = Self.availableInputDevices()
            if let device = devices.first(where: { $0.uid == selectedDeviceUID }) {
                var deviceID = device.id
                let status = AudioUnitSetProperty(
                    engine.inputNode.audioUnit!,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &deviceID,
                    UInt32(MemoryLayout<AudioDeviceID>.size)
                )
                if status != noErr {
                    print("Failed to set input device: \(status)")
                }
            }
        }

        let inputNode = engine.inputNode
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        micData = Data()

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
            guard let self else { return }

            guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else { return }
            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * self.sampleRate / buffer.format.sampleRate
            )
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .haveData, let channelData = convertedBuffer.floatChannelData?[0] {
                let count = Int(convertedBuffer.frameLength)
                let bytes = Data(bytes: channelData, count: count * MemoryLayout<Float>.size)
                self.micData.append(bytes)

                // Compute RMS for waveform visualization
                var sumOfSquares: Float = 0
                for i in 0..<count {
                    sumOfSquares += channelData[i] * channelData[i]
                }
                let rms = sqrt(sumOfSquares / max(Float(count), 1))
                self.onAudioLevel?(rms)
            }
        }

        // Start system audio capture if enabled
        if captureSystemAudio {
            let capture = SystemAudioCapture()
            self.systemCapture = capture
            Task {
                try? await capture.startCapture()
            }
        }

        engine.prepare()
        try engine.start()
        self.audioEngine = engine
    }

    func stopRecording() -> Data {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        return micData
    }

    /// Stop recording and return audio data. If system audio was captured, mixes both streams.
    func stopRecordingAsync() async -> Data {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        guard let systemCapture else {
            return micData
        }

        let sysData = await systemCapture.stopCapture()
        self.systemCapture = nil

        return mixAudio(mic: micData, system: sysData)
    }

    /// Mix mic and system audio buffers by adding samples together.
    private func mixAudio(mic: Data, system: Data) -> Data {
        let micFloats = mic.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        let sysFloats = system.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        let count = max(micFloats.count, sysFloats.count)

        var mixed = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let m: Float = i < micFloats.count ? micFloats[i] : 0
            let s: Float = i < sysFloats.count ? sysFloats[i] : 0
            // Mix with clamp to prevent clipping
            mixed[i] = max(-1.0, min(1.0, m + s))
        }

        return mixed.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
