import Foundation
import Hub
import MLX
import MLXLLM
import MLXLMCommon
import os

private let logger = Logger(subsystem: "com.sotamikami.verba", category: "LocalLLM")

/// Available local models for text formatting
struct LocalModelOption: Identifiable, Hashable {
    let id: String // HuggingFace model ID
    let name: String
    let description: String
    let sizeLabel: String

    static let recommended: [LocalModelOption] = [
        LocalModelOption(
            id: "mlx-community/Qwen3-0.6B-4bit",
            name: "Qwen3 0.6B",
            description: "Ultra-light, fastest",
            sizeLabel: "~400MB"
        ),
        LocalModelOption(
            id: "mlx-community/Qwen3-1.7B-4bit",
            name: "Qwen3 1.7B",
            description: "Good balance",
            sizeLabel: "~1GB"
        ),
        LocalModelOption(
            id: "mlx-community/Qwen3-4B-4bit",
            name: "Qwen3 4B",
            description: "Best quality for most Macs",
            sizeLabel: "~2.5GB"
        ),
        LocalModelOption(
            id: "mlx-community/gemma-3-1b-it-qat-4bit",
            name: "Gemma 3 1B",
            description: "Lightweight, multilingual",
            sizeLabel: "~800MB"
        ),
        LocalModelOption(
            id: "mlx-community/SmolLM3-3B-4bit",
            name: "SmolLM3 3B",
            description: "Compact and capable",
            sizeLabel: "~2GB"
        ),
    ]
}

enum LocalModelState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case loading
    case ready

    static func == (lhs: LocalModelState, rhs: LocalModelState) -> Bool {
        switch (lhs, rhs) {
        case (.notDownloaded, .notDownloaded): return true
        case (.downloading(let a), .downloading(let b)): return a == b
        case (.downloaded, .downloaded): return true
        case (.loading, .loading): return true
        case (.ready, .ready): return true
        default: return false
        }
    }
}

@MainActor
class LocalLLMService: ObservableObject {
    @Published var modelState: LocalModelState = .notDownloaded
    @Published var errorMessage: String?

    private var modelContainer: ModelContainer?
    private var currentModelId: String?

    private let hub = HubApi(
        downloadBase: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    )

    /// Check if a model is already downloaded
    func checkModelStatus(modelId: String) {
        let config = ModelConfiguration(id: modelId)
        let repo = Hub.Repo(id: config.name)
        let localPath = hub.localRepoLocation(repo)

        let fm = FileManager.default
        if fm.fileExists(atPath: localPath.path),
           let contents = try? fm.contentsOfDirectory(atPath: localPath.path),
           contents.contains(where: { $0.hasSuffix(".safetensors") }) {
            if currentModelId == modelId && modelContainer != nil {
                modelState = .ready
            } else {
                modelState = .downloaded
            }
        } else {
            modelState = .notDownloaded
        }
    }

    /// Download and load a model
    func downloadAndLoad(modelId: String) async {
        errorMessage = nil
        modelState = .downloading(progress: 0)

        let config = ModelConfiguration(id: modelId)

        do {
            // Download
            _ = try await downloadModel(
                hub: hub,
                configuration: config
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.modelState = .downloading(progress: progress.fractionCompleted)
                }
            }

            modelState = .loading

            // Load into memory
            Memory.cacheLimit = 20 * 1024 * 1024

            let container = try await LLMModelFactory.shared.loadContainer(
                hub: hub,
                configuration: config
            ) { _ in }

            modelContainer = container
            currentModelId = modelId
            modelState = .ready
            logger.info("Local model loaded: \(modelId)")
        } catch {
            logger.error("Failed to load local model: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            modelState = .notDownloaded
        }
    }

    /// Load an already-downloaded model
    func loadModel(modelId: String) async {
        guard modelState == .downloaded || currentModelId != modelId else { return }
        errorMessage = nil
        modelState = .loading

        let config = ModelConfiguration(id: modelId)

        do {
            Memory.cacheLimit = 20 * 1024 * 1024

            let container = try await LLMModelFactory.shared.loadContainer(
                hub: hub,
                configuration: config
            ) { _ in }

            modelContainer = container
            currentModelId = modelId
            modelState = .ready
            logger.info("Local model loaded: \(modelId)")
        } catch {
            logger.error("Failed to load model: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            modelState = .downloaded
        }
    }

    /// Unload the current model to free memory
    func unloadModel() {
        modelContainer = nil
        currentModelId = nil
        if case .ready = modelState {
            modelState = .downloaded
        }
    }

    /// Delete a downloaded model from disk
    func deleteModel(modelId: String) {
        if currentModelId == modelId {
            unloadModel()
        }

        let config = ModelConfiguration(id: modelId)
        let repo = Hub.Repo(id: config.name)
        let localPath = hub.localRepoLocation(repo)

        try? FileManager.default.removeItem(at: localPath)
        modelState = .notDownloaded
        logger.info("Deleted local model: \(modelId)")
    }

    /// Generate formatted text using the local model
    func generate(systemPrompt: String, userMessage: String) async -> String? {
        guard let container = modelContainer else {
            logger.error("No model loaded for generation")
            return nil
        }

        let chat: [Chat.Message] = [
            .system(systemPrompt),
            .user(userMessage),
        ]

        let userInput = UserInput(
            chat: chat,
            additionalContext: ["enable_thinking": false]
        )

        do {
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            let lmInput = try await container.prepare(input: userInput)
            let parameters = GenerateParameters(maxTokens: 2048, temperature: 0.3)
            let stream = try await container.generate(input: lmInput, parameters: parameters)

            var output = ""
            for await result in stream {
                if let chunk = result.chunk {
                    output += chunk
                }
            }

            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            logger.error("Local generation error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Check if model is ready for generation
    var isReady: Bool {
        modelContainer != nil
    }
}
