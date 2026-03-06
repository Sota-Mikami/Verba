import Foundation

class OpenRouterService {

    struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]

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

    private let systemPrompt = """
    音声文字起こしテキストをLLMへの入力として整形してください。
    - フィラー(えーと、あの、um、uh等)を除去
    - 適切な句読点・改行を追加
    - 誤認識と思われる箇所を文脈から補正
    - 話の構造が明確になるよう段落分け
    - 元の意味・意図・語調は変えない
    - 余計な要約や追加はしない
    - 整形後のテキストのみを返す（説明不要）
    """

    func format(text: String, apiKey: String, model: String) async -> String? {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Verba", forHTTPHeaderField: "X-Title")

        let body = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: text),
            ]
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(ChatResponse.self, from: data)
            return response.choices.first?.message.content
        } catch {
            print("OpenRouter error: \(error)")
            return nil
        }
    }
}
