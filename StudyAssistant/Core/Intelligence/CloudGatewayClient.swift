import Foundation

// MARK: - Request / response types

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    let model: String
    let messages: [Message]
    let stream: Bool
    let max_tokens: Int
    let temperature: Double
}

private struct ChatDelta: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
        let finish_reason: String?
    }
    let choices: [Choice]
}

// MARK: - Client

/// Streams chat completions from an OpenAI-compatible gateway (LiteLLM / any OpenAI proxy).
/// All networking is off-MainActor; results are delivered via `AsyncThrowingStream`.
actor CloudGatewayClient {

    // MARK: - Config snapshot (read once per call so changes take effect next request)

    private var baseURL: String
    private var apiKey: String
    private var model: String

    init(baseURL: String, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey  = apiKey
        self.model   = model
    }

    // MARK: - Update config

    func update(baseURL: String, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey  = apiKey
        self.model   = model
    }

    // MARK: - Streaming chat

    /// Returns an `AsyncThrowingStream` that yields incremental text chunks (SSE delta).
    nonisolated func chatStream(
        messages: [(role: String, content: String)],
        maxTokens: Int = 1024
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                do {
                    // Capture current config atomically
                    let (url, key, mdl) = await (self.baseURL, self.apiKey, self.model)
                    guard !url.isEmpty, !key.isEmpty else {
                        cont.finish(throwing: CloudError.notConfigured)
                        return
                    }
                    guard let endpoint = URL(string: "\(url)/v1/chat/completions") else {
                        cont.finish(throwing: CloudError.badURL)
                        return
                    }

                    let body = ChatRequest(
                        model: mdl,
                        messages: messages.map { .init(role: $0.role, content: $0.content) },
                        stream: true,
                        max_tokens: maxTokens,
                        temperature: 0.7
                    )

                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.setValue("application/json",    forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(key)",       forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONEncoder().encode(body)
                    request.timeoutInterval = 120

                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        cont.finish(throwing: CloudError.badResponse)
                        return
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        cont.finish(throwing: CloudError.httpError(http.statusCode))
                        return
                    }

                    // Parse Server-Sent Events line by line
                    for try await line in asyncBytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let delta = try? JSONDecoder().decode(ChatDelta.self, from: data),
                              let text = delta.choices.first?.delta.content,
                              !text.isEmpty
                        else { continue }
                        cont.yield(text)
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Non-streaming (for structured tasks)

    nonisolated func chat(
        messages: [(role: String, content: String)],
        maxTokens: Int = 1024
    ) async throws -> String {
        var result = ""
        for try await chunk in chatStream(messages: messages, maxTokens: maxTokens) {
            result += chunk
        }
        return result
    }

    // MARK: - Ping / test

    nonisolated func testConnection() async -> Bool {
        do {
            let reply = try await chat(
                messages: [("user", "Reply with only the word OK.")],
                maxTokens: 5
            )
            return reply.lowercased().contains("ok")
        } catch {
            return false
        }
    }
}

// MARK: - Errors

enum CloudError: LocalizedError {
    case notConfigured
    case badURL
    case badResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:  return "Cloud gateway not configured. Set URL and API key in Settings."
        case .badURL:         return "Invalid gateway URL. Check Settings."
        case .badResponse:    return "Unexpected response from gateway."
        case .httpError(let code): return "Gateway error \(code). Check your API key."
        }
    }
}
