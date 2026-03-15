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
    private var idleUnloadTask: Task<Void, Never>?
    private var activeLoadTask: Task<Void, Never>?

    /// How long to wait after last generation before unloading model (seconds)
    private let idleUnloadDelay: TimeInterval = 300

    private let hub = HubApi(
        downloadBase: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    )

    /// Check if a model is already downloaded
    func checkModelStatus(modelId: String) {
        let config = ModelConfiguration(id: modelId)
        let repo = Hub.Repo(id: config.name)
        let localPath = hub.localRepoLocation(repo)

        DebugLog.log("[LLM] checkModelStatus: modelId=\(modelId), config.name=\(config.name), localPath=\(localPath.path)")

        let fm = FileManager.default
        let exists = fm.fileExists(atPath: localPath.path)
        let contents = (try? fm.contentsOfDirectory(atPath: localPath.path)) ?? []
        let hasSafetensors = contents.contains(where: { $0.hasSuffix(".safetensors") })

        DebugLog.log("[LLM] checkModelStatus: exists=\(exists), contents=\(contents.count) files, hasSafetensors=\(hasSafetensors)")

        if exists && hasSafetensors {
            if currentModelId == modelId && modelContainer != nil {
                modelState = .ready
            } else {
                modelState = .downloaded
            }
        } else {
            modelState = .notDownloaded
        }
    }

    /// Wait for any in-progress download/load to complete
    func waitForReady() async {
        await activeLoadTask?.value
    }

    /// True if a download or load is currently in progress
    var isBusy: Bool {
        switch modelState {
        case .downloading, .loading: return true
        default: return false
        }
    }

    /// Download a model without loading it into memory
    func downloadOnly(modelId: String) async {
        // Guard: don't start if already busy
        guard !isBusy else {
            logger.info("downloadOnly: already busy, skipping")
            return
        }

        errorMessage = nil
        modelState = .downloading(progress: 0)

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let config = ModelConfiguration(id: modelId)

            do {
                _ = try await downloadModel(
                    hub: self.hub,
                    configuration: config
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.modelState = .downloading(progress: progress.fractionCompleted)
                    }
                }

                self.currentModelId = modelId
                self.modelState = .downloaded
                logger.info("Model downloaded (not loaded): \(modelId)")
            } catch {
                logger.error("Failed to download model: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.modelState = .notDownloaded
            }
        }
        activeLoadTask = task
        await task.value
        activeLoadTask = nil
    }

    /// Download and load a model
    func downloadAndLoad(modelId: String) async {
        // Guard: don't start if already busy
        guard !isBusy else {
            logger.info("downloadAndLoad: already busy, waiting for current task")
            await activeLoadTask?.value
            return
        }

        errorMessage = nil
        modelState = .downloading(progress: 0)

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let config = ModelConfiguration(id: modelId)

            do {
                // Download
                _ = try await downloadModel(
                    hub: self.hub,
                    configuration: config
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.modelState = .downloading(progress: progress.fractionCompleted)
                    }
                }

                self.modelState = .loading

                // Load into memory
                Memory.cacheLimit = 20 * 1024 * 1024

                let container = try await LLMModelFactory.shared.loadContainer(
                    hub: self.hub,
                    configuration: config
                ) { _ in }

                self.modelContainer = container
                self.currentModelId = modelId
                self.modelState = .ready
                logger.info("Local model loaded: \(modelId)")
            } catch {
                logger.error("Failed to load local model: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.modelState = .notDownloaded
            }
        }
        activeLoadTask = task
        await task.value
        activeLoadTask = nil
    }

    /// Load an already-downloaded model
    func loadModel(modelId: String) async {
        // Guard: don't start if already busy
        guard !isBusy else {
            logger.info("loadModel: already busy, waiting for current task")
            await activeLoadTask?.value
            return
        }
        guard modelState == .downloaded || currentModelId != modelId else { return }
        errorMessage = nil
        modelState = .loading

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let config = ModelConfiguration(id: modelId)

            do {
                Memory.cacheLimit = 20 * 1024 * 1024

                let container = try await LLMModelFactory.shared.loadContainer(
                    hub: self.hub,
                    configuration: config
                ) { _ in }

                self.modelContainer = container
                self.currentModelId = modelId
                self.modelState = .ready
                logger.info("Local model loaded: \(modelId)")
            } catch {
                logger.error("Failed to load model: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.modelState = .downloaded
            }
        }
        activeLoadTask = task
        await task.value
        activeLoadTask = nil
    }

    /// Unload the current model to free memory
    func unloadModel() {
        cancelIdleUnload()
        let wasReady = modelContainer != nil
        modelContainer = nil
        if case .ready = modelState {
            modelState = .downloaded
        }
        if wasReady {
            logger.info("LLM unloaded to free memory (model files still on disk: \(self.currentModelId ?? "nil"))")
        }
    }

    /// Schedule automatic unload after idle period
    func scheduleIdleUnload() {
        cancelIdleUnload()
        idleUnloadTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.idleUnloadDelay ?? 30))
            guard !Task.isCancelled, let self, self.modelContainer != nil else { return }
            logger.info("Idle timeout reached — unloading LLM to free memory")
            self.unloadModel()
        }
    }

    /// Cancel pending idle unload (e.g. when preloading for next use)
    func cancelIdleUnload() {
        idleUnloadTask?.cancel()
        idleUnloadTask = nil
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
        cancelIdleUnload()

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

            // Schedule unload after idle period
            scheduleIdleUnload()

            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            logger.error("Local generation error: \(error.localizedDescription)")
            scheduleIdleUnload()
            return nil
        }
    }

    /// Check if model is ready for generation
    var isReady: Bool {
        modelContainer != nil
    }
}
