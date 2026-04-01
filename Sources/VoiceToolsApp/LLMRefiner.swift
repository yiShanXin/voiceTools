import Foundation

struct LLMSettings {
    var baseURL: String
    var apiKey: String
    var model: String

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

final class LLMRefiner {
    private struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let temperature: Double
        let messages: [Message]
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }

            let message: Message
        }

        let choices: [Choice]
    }

    private let systemPrompt = """
你是一个极度保守的语音转录纠错器。
只允许修复“明显错误”，例如：
1) 中文谐音误识别
2) 英文技术术语被误识别成中文音译（如 配森->Python, 杰森->JSON）

严格规则：
- 不得改写、润色、总结、扩写或删减任何看起来正确的内容。
- 保留原句结构、标点、大小写、空格和顺序。
- 如果输入看起来已正确，必须原样返回。
- 输出只能是修正后的纯文本，不要解释。
"""

    func refine(_ text: String, settings: LLMSettings, completion: @escaping (String) -> Void) {
        guard settings.isConfigured else {
            completion(text)
            return
        }

        guard let url = resolveChatCompletionURL(base: settings.baseURL) else {
            completion(text)
            return
        }

        let body = RequestBody(
            model: settings.model,
            temperature: 0,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: text)
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 18
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(text)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let data,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data),
                  let content = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty else {
                completion(text)
                return
            }

            completion(content)
        }.resume()
    }

    func testConnection(settings: LLMSettings, completion: @escaping (Result<String, Error>) -> Void) {
        guard settings.isConfigured else {
            completion(.failure(NSError(domain: "VoiceHub", code: 1002, userInfo: [NSLocalizedDescriptionKey: "请先完整填写 API Base URL、API Key、Model"])))
            return
        }

        refine("配森脚本读取杰森文件", settings: settings) { output in
            completion(.success(output))
        }
    }

    private func resolveChatCompletionURL(base: String) -> URL? {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }

        if url.path.hasSuffix("/chat/completions") {
            return url
        }

        var baseWithSlash = trimmed
        if !baseWithSlash.hasSuffix("/") {
            baseWithSlash += "/"
        }
        return URL(string: "chat/completions", relativeTo: URL(string: baseWithSlash))?.absoluteURL
    }
}
