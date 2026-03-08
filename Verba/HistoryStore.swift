import Foundation
import os

private let logger = Logger(subsystem: "com.sotamikami.verba", category: "HistoryStore")

/// Persists transcription history to Application Support.
/// Metadata is stored in history.json; audio data as individual .pcm files.
struct HistoryStore {
    private static var directory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Verba/history", isDirectory: true)
    }

    private static var metadataURL: URL {
        directory.appendingPathComponent("history.json")
    }

    private static func audioURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).pcm")
    }

    static func load() -> [TranscriptionRecord] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: metadataURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: metadataURL)
            let decoded = try JSONDecoder().decode([TranscriptionRecord].self, from: data)
            // Rehydrate audio data from individual files
            let records: [TranscriptionRecord] = decoded.compactMap { record in
                let audioFile = audioURL(for: record.id)
                guard let audioData = try? Data(contentsOf: audioFile) else {
                    logger.warning("Audio file missing for record \(record.id), skipping")
                    return nil
                }
                return TranscriptionRecord(restoringAudioData: audioData, from: record)
            }
            logger.info("Loaded \(records.count) history records from disk")
            return records
        } catch {
            logger.error("Failed to load history: \(error.localizedDescription)")
            return []
        }
    }

    static func save(_ records: [TranscriptionRecord]) {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)

            // Save metadata
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(records)
            try data.write(to: metadataURL, options: .atomic)

            // Save audio files for each record
            let currentIDs = Set(records.map { $0.id })
            for record in records {
                let audioFile = audioURL(for: record.id)
                if !fm.fileExists(atPath: audioFile.path) {
                    try record.audioData.write(to: audioFile, options: .atomic)
                }
            }

            // Clean up orphaned audio files
            if let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "pcm" {
                    let idString = file.deletingPathExtension().lastPathComponent
                    if let uuid = UUID(uuidString: idString), !currentIDs.contains(uuid) {
                        try? fm.removeItem(at: file)
                    }
                }
            }
        } catch {
            logger.error("Failed to save history: \(error.localizedDescription)")
        }
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}
