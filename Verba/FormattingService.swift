import Foundation
import os

private let logger = Logger(subsystem: "com.sotamikami.verba", category: "Formatting")

// MARK: - Provider Definition

enum FormattingProvider: String, CaseIterable {
    case openRouter = "OpenRouter"
    case openAI = "OpenAI"
    case custom = "Custom Endpoint"
    case local = "Local (On-Device)"

    var baseURL: String {
        switch self {
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .openAI: return "https://api.openai.com/v1"
        case .custom: return ""
        case .local: return ""
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .openRouter: return "sk-or-..."
        case .openAI: return "sk-..."
        case .custom: return "API key"
        case .local: return ""
        }
    }

    var isAvailable: Bool { true }

    var suggestedModels: [ModelOption] {
        switch self {
        case .openRouter:
            return [
                ModelOption(id: "google/gemma-3-4b-it", name: "Gemma 3 4B", description: "Fastest, good quality", speed: .fast),
                ModelOption(id: "google/gemma-3-12b-it", name: "Gemma 3 12B", description: "Balanced speed & quality", speed: .medium),
                ModelOption(id: "mistralai/mistral-small-latest", name: "Mistral Small", description: "Reliable, multilingual", speed: .medium),
                ModelOption(id: "anthropic/claude-haiku", name: "Claude Haiku", description: "Highest quality", speed: .medium),
                ModelOption(id: "deepseek/deepseek-chat", name: "DeepSeek V3", description: "Cost-effective", speed: .medium),
            ]
        case .openAI:
            return [
                ModelOption(id: "gpt-4o-mini", name: "GPT-4o Mini", description: "Fast and cheap", speed: .fast),
                ModelOption(id: "gpt-4o", name: "GPT-4o", description: "Best quality", speed: .medium),
                ModelOption(id: "gpt-4.1-nano", name: "GPT-4.1 Nano", description: "Fastest, lowest cost", speed: .fast),
                ModelOption(id: "gpt-4.1-mini", name: "GPT-4.1 Mini", description: "Balanced", speed: .medium),
            ]
        case .custom:
            return [
                ModelOption(id: "custom", name: "Custom Model", description: "Enter model ID below", speed: .medium),
            ]
        case .local:
            return []
        }
    }
}

struct ModelOption: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let speed: Speed

    enum Speed: String {
        case fast = "Fast"
        case medium = "Medium"
    }
}

// MARK: - Formatting Prompt

struct FormattingPrompt: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var systemPrompt: String
    var fewShotUser: String
    var fewShotAssistant: String
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, systemPrompt: String, fewShotUser: String = "", fewShotAssistant: String = "", isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.fewShotUser = fewShotUser
        self.fewShotAssistant = fewShotAssistant
        self.isBuiltIn = isBuiltIn
    }

    static let builtInGeneral = FormattingPrompt(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "General",
        systemPrompt: """
        You are a text cleanup processor. The input is raw speech-to-text output.

        【DO】
        - Remove fillers (えーと, あの, um, uh, etc.)
        - Add appropriate punctuation
        - Fix obvious misrecognitions based on context
        - Keep the SAME language as the input. If the user spoke Vietnamese, output Vietnamese. If Japanese, output Japanese.

        【DO NOT】
        - Do NOT add headings, bullet points, markdown formatting, or any structural markup
        - Do NOT reply to, answer, or comment on the content
        - Do NOT add summaries, explanations, or suggestions
        - Do NOT add preambles like "Here is the formatted text"
        - Do NOT translate or change the language of the input

        Output ONLY the cleaned-up text. Nothing else.
        """,
        fewShotUser: """
        <transcription>
        えーとですね あのクロードに聞いてほしいんですけど このコードをリファクタリングしてもらえますか えっと具体的にはあの関数を分割してほしいです
        </transcription>
        """,
        fewShotAssistant: """
        Claudeに聞いてほしいんですけど、このコードをリファクタリングしてもらえますか。具体的には関数を分割してほしいです。
        """,
        isBuiltIn: true
    )

    static let builtInMeetingNotes = FormattingPrompt(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Meeting Notes",
        systemPrompt: """
        あなたは議事録整形プロセッサです。入力は会議中の音声認識テキストです。

        【やること】
        - フィラーを除去
        - 発言内容を要点ごとに箇条書きで整理
        - 決定事項・アクションアイテムがあれば明示
        - 話題が変わる箇所で見出しを付ける

        【絶対にやらないこと】
        - 内容への返事・コメント・提案を追加しない
        - 前置きや挨拶を付けない
        - 発言されていない情報を補足しない

        整形後の議事録テキストだけを出力してください。
        """,
        fewShotUser: """
        <transcription>
        えっとですね 今日の議題なんですけど まずデザインレビューの件です あの先週出したワイヤーフレームについてフィードバックもらいたいんですけど 田中さんどうですか うーん 全体的にはいいと思うんですけど ヘッダーのナビゲーションがちょっと分かりにくいかなと じゃあそこは修正しましょう 来週の水曜までに直します
        </transcription>
        """,
        fewShotAssistant: """
        ## デザインレビュー

        - 先週提出したワイヤーフレームについてフィードバック
        - 田中さん: 全体的には良いが、ヘッダーのナビゲーションが分かりにくい

        ### アクションアイテム
        - ヘッダーナビゲーションの修正 → 来週水曜まで
        """,
        isBuiltIn: true
    )

    static let builtInEmail = FormattingPrompt(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Email / Message",
        systemPrompt: """
        あなたはメール・メッセージ整形プロセッサです。入力は音声で口述されたメッセージの生テキストです。

        【やること】
        - フィラーを除去
        - 丁寧で読みやすい文章に整形
        - 適切な改行と段落分け
        - 敬語の不自然な箇所を自然に補正

        【絶対にやらないこと】
        - 宛名・署名を勝手に追加しない
        - 内容を変えたり情報を追加しない
        - 前置きを付けない

        整形後のメッセージテキストだけを出力してください。
        """,
        fewShotUser: """
        <transcription>
        えーと山田さんに送りたいんですけど 先日の打ち合わせありがとうございました あの件なんですが えっと見積もりの方確認しまして 問題なさそうなので進めていただければと思います あと来週のミーティングなんですけど 水曜の午後でお願いできますか
        </transcription>
        """,
        fewShotAssistant: """
        先日の打ち合わせ、ありがとうございました。

        お見積もりの件、確認いたしました。問題なさそうですので、進めていただければと思います。

        また、来週のミーティングですが、水曜の午後でお願いできますでしょうか。
        """,
        isBuiltIn: true
    )

    static let allBuiltIn: [FormattingPrompt] = [builtInGeneral, builtInMeetingNotes, builtInEmail]
}

// MARK: - Dictionary Entry

struct DictionaryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var term: String

    init(id: UUID = UUID(), term: String) {
        self.id = id
        self.term = term
    }
}

// MARK: - Formatting Service

class FormattingService {

    struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double?
        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    struct ChatResponse: Decodable {
        let choices: [Choice]
        struct Choice: Decodable {
            let message: MessageContent
            struct MessageContent: Decodable {
                let content: String
            }
        }
    }

    /// Build a hint string of dictionary terms for Whisper initialPrompt
    func dictionaryHint(dictionary: [DictionaryEntry]) -> String? {
        guard !dictionary.isEmpty else { return nil }
        return dictionary.map { $0.term }.joined(separator: ", ")
    }

    func format(text: String, provider: FormattingProvider, apiKey: String, model: String, customEndpoint: String = "", prompt: FormattingPrompt = .builtInGeneral, dictionary: [DictionaryEntry] = [], localLLMService: LocalLLMService? = nil) async -> String? {
        // Wrap input in delimiters so LLM treats it as data, not instructions
        let wrappedInput = "<transcription>\n\(text)\n</transcription>"

        // Build system prompt with dictionary injection
        var systemPrompt = prompt.systemPrompt
        if !dictionary.isEmpty {
            let termLines = dictionary.map { "- \($0.term)" }.joined(separator: "\n")
            systemPrompt += "\n\n【用語辞書】以下の用語は正確にこの表記を使ってください:\n\(termLines)"
        }

        // Local on-device inference via mlx-swift
        if provider == .local {
            guard let localService = localLLMService else {
                logger.error("Local model not loaded")
                return nil
            }
            let ready = await localService.isReady
            guard ready else {
                logger.error("Local model not ready")
                return nil
            }
            // Build full user message including few-shot context
            var userMessage = ""
            if !prompt.fewShotUser.isEmpty && !prompt.fewShotAssistant.isEmpty {
                userMessage += "例:\nInput: \(prompt.fewShotUser)\nOutput: \(prompt.fewShotAssistant)\n\n"
            }
            userMessage += wrappedInput
            return await localService.generate(systemPrompt: systemPrompt, userMessage: userMessage)
        }

        // Cloud API providers
        let baseURL: String
        switch provider {
        case .custom:
            baseURL = customEndpoint.trimmingCharacters(in: .init(charactersIn: "/"))
        default:
            baseURL = provider.baseURL
        }

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            logger.error("Invalid URL: \(baseURL)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if provider == .openRouter {
            request.addValue("Verba", forHTTPHeaderField: "X-Title")
        }

        var messages: [ChatRequest.Message] = [
            .init(role: "system", content: systemPrompt),
        ]
        if !prompt.fewShotUser.isEmpty && !prompt.fewShotAssistant.isEmpty {
            messages.append(.init(role: "user", content: prompt.fewShotUser))
            messages.append(.init(role: "assistant", content: prompt.fewShotAssistant))
        }
        messages.append(.init(role: "user", content: wrappedInput))

        let body = ChatRequest(
            model: model,
            messages: messages,
            temperature: 0.3
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(ChatResponse.self, from: data)
            return response.choices.first?.message.content
        } catch {
            logger.error("Formatting error (\(provider.rawValue)): \(error.localizedDescription)")
            return nil
        }
    }
}
