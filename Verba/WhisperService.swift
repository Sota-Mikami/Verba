import Foundation
import WhisperKit

class WhisperService {
    private var whisperKit: WhisperKit?
    private static let errorLogPath = "/tmp/verba-error.log"

    private static func writeLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: errorLogPath) {
                if let handle = FileHandle(forWritingAtPath: errorLogPath) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: errorLogPath, contents: data)
            }
        }
    }

    func loadModel() async throws {
        Self.writeLog("Starting WhisperKit initialization...")

        do {
            // Let WhisperKit auto-select the best model for this device
            whisperKit = try await WhisperKit(
                verbose: true,
                logLevel: .debug,
                prewarm: false,
                load: true,
                download: true
            )
            Self.writeLog("WhisperKit initialized successfully, model: \(whisperKit?.modelVariant.description ?? "unknown")")
        } catch {
            Self.writeLog("WhisperKit init FAILED: \(error)")
            throw error
        }
    }

    func transcribe(audioData: Data, language: String? = nil) async throws -> String {
        guard let whisperKit else {
            throw WhisperError.notInitialized
        }

        let samples = audioData.withUnsafeBytes { buffer -> [Float] in
            Array(buffer.bindMemory(to: Float.self))
        }

        let options = DecodingOptions(
            task: .transcribe,
            language: language,
            detectLanguage: language == nil,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )

        let results: [TranscriptionResult] = try await whisperKit.transcribe(
            audioArray: samples,
            decodeOptions: options
        )

        let text = results.map { $0.text }.joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum WhisperError: LocalizedError {
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .notInitialized: "Whisper not initialized. Please wait for model to load."
        }
    }
}
