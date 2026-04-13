import Foundation

public enum AnthropicError: Error, Equatable {
    case missingAPIKey
    case httpError(Int)
}

public final class AnthropicClient: @unchecked Sendable {
    public static let shared = AnthropicClient()

    private let session: URLSession
    private let keychain: KeychainManager

    public init(session: URLSession = .shared, keychain: KeychainManager = .shared) {
        self.session = session
        self.keychain = keychain
    }

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-haiku-4-5"
    private static let maxTokens = 150
    private static let systemPrompt = """
    You are a concise study assistant. Respond in 2-3 sentences maximum. \
    For Explain mode: explain the concept simply for a college student. \
    For Define mode: give a single sentence dictionary-style definition. \
    For Math mode: show the answer and key steps only.
    """

    public func stream(text: String, mode: LookupMode) throws -> AsyncThrowingStream<String, Error> {
        guard let apiKey = keychain.retrieveAPIKey(), !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        let request = try Self.buildRequest(apiKey: apiKey, text: text, mode: mode)
        let session = self.session

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)

                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        throw AnthropicError.httpError(http.statusCode)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload.isEmpty { continue }
                        if payload == "[DONE]" { break }

                        guard let data = payload.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            continue
                        }

                        if obj["type"] as? String == "content_block_delta",
                           let delta = obj["delta"] as? [String: Any],
                           delta["type"] as? String == "text_delta",
                           let chunk = delta["text"] as? String {
                            continuation.yield(chunk)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // Exposed for tests; builds the full POST request.
    static func buildRequest(apiKey: String, text: String, mode: LookupMode) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let userContent = "[\(mode.rawValue) mode] \(text)"
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userContent]
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
}
