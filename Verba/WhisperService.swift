import Foundation
import WhisperKit

struct WhisperModelOption: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let sizeLabel: String

    static let recommended: [WhisperModelOption] = [
        WhisperModelOption(id: "auto", name: "Auto", description: "Best model for this device", sizeLabel: "Auto"),
        WhisperModelOption(id: "openai_whisper-tiny", name: "Tiny", description: "Fastest, lowest quality", sizeLabel: "~75MB"),
        WhisperModelOption(id: "openai_whisper-base", name: "Base", description: "Fast, decent quality", sizeLabel: "~140MB"),
        WhisperModelOption(id: "openai_whisper-small", name: "Small", description: "Balanced", sizeLabel: "~460MB"),
        WhisperModelOption(id: "openai_whisper-large-v3-turbo", name: "Large V3 Turbo", description: "Best quality, recommended", sizeLabel: "~1.5GB"),
    ]
}

struct WhisperTranscriptionResult {
    let text: String
    let language: String?
}

class WhisperService {
    private var whisperKit: WhisperKit?
    private static let errorLogPath = "/tmp/verba-error.log"

    /// Track model loading crashes via UserDefaults flag
    private static let loadingFlagKey = "whisperModelLoading"
    private static let crashCountKey = "whisperModelCrashCount"

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

    /// Check if previous launch crashed during model loading
    static var didCrashDuringLastLoad: Bool {
        UserDefaults.standard.bool(forKey: loadingFlagKey)
    }

    static var crashCount: Int {
        UserDefaults.standard.integer(forKey: crashCountKey)
    }

    /// Clear CoreML compiled model cache to recover from shader compilation crashes
    private func clearCoreMLCache() {
        Self.writeLog("Clearing CoreML compiled model cache...")
        let fm = FileManager.default

        guard let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }

        // CoreML e5rt bundle cache — the actual location of compiled Metal shaders
        // Stored per-app under ~/Library/Caches/<bundleID>/com.apple.e5rt.e5bundlecache/
        if let bundleId = Bundle.main.bundleIdentifier {
            let e5rtCache = cachesDir.appendingPathComponent(bundleId).appendingPathComponent("com.apple.e5rt.e5bundlecache")
            if fm.fileExists(atPath: e5rtCache.path) {
                try? fm.removeItem(at: e5rtCache)
                Self.writeLog("Removed e5rt cache: \(e5rtCache.path)")
            }
        }

        // Also try generic CoreML cache
        let coremlCache = cachesDir.appendingPathComponent("com.apple.CoreML")
        if fm.fileExists(atPath: coremlCache.path) {
            try? fm.removeItem(at: coremlCache)
            Self.writeLog("Removed CoreML cache: \(coremlCache.path)")
        }
    }

    func loadModel(variant: String = "auto") async throws {
        let crashCount = Self.crashCount
        let didCrashLast = Self.didCrashDuringLastLoad

        if didCrashLast {
            let newCount = crashCount + 1
            UserDefaults.standard.set(newCount, forKey: Self.crashCountKey)
            Self.writeLog("⚠ Previous launch crashed during model load (crash #\(newCount)). Clearing CoreML cache...")
            clearCoreMLCache()
            // Add delay to let Metal/GPU resources settle after crash
            try? await Task.sleep(for: .seconds(2))
        }

        // Set loading flag — if app crashes during load, this stays true
        UserDefaults.standard.set(true, forKey: Self.loadingFlagKey)
        UserDefaults.standard.synchronize()

        Self.writeLog("Starting WhisperKit initialization with variant: \(variant)...")

        do {
            if variant == "auto" {
                whisperKit = try await WhisperKit(
                    verbose: true,
                    logLevel: .debug,
                    prewarm: false,
                    load: true,
                    download: true
                )
            } else {
                whisperKit = try await WhisperKit(
                    model: variant,
                    verbose: true,
                    logLevel: .debug,
                    prewarm: false,
                    load: true,
                    download: true
                )
            }

            // Model loaded successfully — clear crash flag
            UserDefaults.standard.set(false, forKey: Self.loadingFlagKey)
            if crashCount > 0 {
                UserDefaults.standard.set(0, forKey: Self.crashCountKey)
            }
            Self.writeLog("WhisperKit initialized successfully, model: \(whisperKit?.modelVariant.description ?? "unknown")")
        } catch {
            UserDefaults.standard.set(false, forKey: Self.loadingFlagKey)
            Self.writeLog("WhisperKit init FAILED: \(error)")
            throw error
        }
    }

    func transcribe(audioData: Data, language: String? = nil, initialPrompt: String? = nil) async throws -> WhisperTranscriptionResult {
        guard let whisperKit else {
            throw WhisperError.notInitialized
        }

        let samples = audioData.withUnsafeBytes { buffer -> [Float] in
            Array(buffer.bindMemory(to: Float.self))
        }

        // Convert initialPrompt string to token IDs for Whisper conditioning
        var tokens: [Int]? = nil
        if let prompt = initialPrompt, !prompt.isEmpty,
           let tokenizer = whisperKit.tokenizer {
            let encoded = tokenizer.encode(text: prompt)
            if !encoded.isEmpty { tokens = encoded }
        }

        let options = DecodingOptions(
            task: .transcribe,
            language: language,
            detectLanguage: language == nil,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            promptTokens: tokens,
            chunkingStrategy: .vad
        )

        let results: [TranscriptionResult] = try await whisperKit.transcribe(
            audioArray: samples,
            decodeOptions: options
        )

        let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let detectedLanguage = results.first?.language
        return WhisperTranscriptionResult(text: text, language: detectedLanguage)
    }

    /// Detect language from audio without full transcription.
    /// Returns language probability distribution for all supported languages.
    func detectLanguage(audioData: Data) async throws -> [String: Float] {
        guard let whisperKit else {
            throw WhisperError.notInitialized
        }

        let samples = audioData.withUnsafeBytes { buffer -> [Float] in
            Array(buffer.bindMemory(to: Float.self))
        }

        // WhisperKit method name has a typo: "detectLangauge"
        let result = try await whisperKit.detectLangauge(audioArray: samples)
        return result.langProbs
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
