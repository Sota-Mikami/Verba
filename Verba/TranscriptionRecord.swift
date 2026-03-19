import Foundation

enum TranscriptionStatus: String, Codable {
    case transcribing
    case formatting
    case success
    case failed
}

enum HistoryRetention: String, CaseIterable {
    case sevenDays = "7 Days"
    case thirtyDays = "30 Days"
    case ninetyDays = "90 Days"
    case unlimited = "Unlimited"

    var days: Int? {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        case .unlimited: return nil
        }
    }
}

struct TranscriptionRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let audioData: Data
    var language: String?
    let mode: TranscriptionMode
    var rawText: String?
    var formattedText: String?
    var status: TranscriptionStatus
    var errorMessage: String?

    // Codable: audioData is stored separately as a .pcm file, not in JSON
    enum CodingKeys: String, CodingKey {
        case id, timestamp, language, mode, rawText, formattedText, status, errorMessage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        mode = try c.decode(TranscriptionMode.self, forKey: .mode)
        rawText = try c.decodeIfPresent(String.self, forKey: .rawText)
        formattedText = try c.decodeIfPresent(String.self, forKey: .formattedText)
        status = try c.decode(TranscriptionStatus.self, forKey: .status)
        errorMessage = try c.decodeIfPresent(String.self, forKey: .errorMessage)
        // audioData loaded separately by HistoryStore
        audioData = Data()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encodeIfPresent(language, forKey: .language)
        try c.encode(mode, forKey: .mode)
        try c.encodeIfPresent(rawText, forKey: .rawText)
        try c.encodeIfPresent(formattedText, forKey: .formattedText)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(errorMessage, forKey: .errorMessage)
    }

    var displayText: String {
        formattedText ?? rawText ?? ""
    }

    var duration: TimeInterval {
        // 16kHz mono Float32 = 64000 bytes per second
        Double(audioData.count) / 64000.0
    }

    /// Convert raw PCM (16kHz mono Float32) to WAV Data for playback.
    var wavData: Data {
        let sampleRate: UInt32 = 16000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 32
        let bytesPerSample = bitsPerSample / 8
        let dataSize = UInt32(audioData.count)
        let fileSize = 36 + dataSize

        var header = Data()
        header.append(contentsOf: "RIFF".utf8)
        header.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // chunk size
        header.append(withUnsafeBytes(of: UInt16(3).littleEndian) { Data($0) })  // IEEE float
        header.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        let byteRate = sampleRate * UInt32(channels) * UInt32(bytesPerSample)
        header.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        let blockAlign = channels * bytesPerSample
        header.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        header.append(contentsOf: "data".utf8)
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        return header + audioData
    }

    init(audioData: Data, language: String?, mode: TranscriptionMode) {
        self.id = UUID()
        self.timestamp = Date()
        self.audioData = audioData
        self.language = language
        self.mode = mode
        self.status = .transcribing
    }

    /// Internal init used by HistoryStore to rehydrate audioData after JSON decode
    init(restoringAudioData audioData: Data, from decoded: TranscriptionRecord) {
        self.id = decoded.id
        self.timestamp = decoded.timestamp
        self.audioData = audioData
        self.language = decoded.language
        self.mode = decoded.mode
        self.rawText = decoded.rawText
        self.formattedText = decoded.formattedText
        self.status = decoded.status
        self.errorMessage = decoded.errorMessage
    }
}
