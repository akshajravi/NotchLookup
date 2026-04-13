import Foundation
import Testing
@testable import NotchLookupCore

// MARK: - URLProtocol stub

// Intercepts every request made through a URLSession configured with this protocol
// class, and replays canned bytes/status. Keyed by request URL so each test can install
// its own response without leaking into sibling tests.
final class StubURLProtocol: URLProtocol {
    struct Response {
        let statusCode: Int
        let body: Data
    }

    // Actor-isolated storage: URLProtocol hops threads, and Swift 6 flags any shared
    // mutable dictionary. A plain lock keeps the surface tiny.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var responses: [URL: Response] = [:]

    static func stub(url: URL, statusCode: Int = 200, body: Data) {
        lock.lock(); defer { lock.unlock() }
        responses[url] = Response(statusCode: statusCode, body: body)
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        responses.removeAll()
    }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.lock.lock()
        let resp = Self.responses[url]
        Self.lock.unlock()

        guard let resp else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }

        let http = HTTPURLResponse(
            url: url,
            statusCode: resp.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: resp.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Test helpers

private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

private func sseEvent(type: String, delta: [String: Any]? = nil) -> String {
    var obj: [String: Any] = ["type": type]
    if let delta { obj["delta"] = delta }
    let data = try! JSONSerialization.data(withJSONObject: obj)
    return "data: " + String(data: data, encoding: .utf8)!
}

private func makeClientWithKey(_ key: String, session: URLSession) -> AnthropicClient {
    let km = KeychainManager.testInstance(account: "anthropic-test-\(UUID().uuidString)")
    km.saveAPIKey(key)
    return AnthropicClient(session: session, keychain: km)
}

private func collect(_ stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
    var chunks: [String] = []
    for try await chunk in stream { chunks.append(chunk) }
    return chunks
}

// MARK: - Tests

// Serialized: StubURLProtocol's canned-response table is static, and every test
// hits the same Anthropic endpoint URL, so parallel runs would trample each other.
@Suite("AnthropicClient", .serialized)
struct AnthropicClientTests {

    @Test("throws missingAPIKey when the Keychain has no key")
    func throwsWhenNoKey() {
        let km = KeychainManager.testInstance(account: "empty-\(UUID().uuidString)")
        let client = AnthropicClient(session: StubURLProtocol.session(), keychain: km)
        #expect(throws: AnthropicError.missingAPIKey) {
            _ = try client.stream(text: "hi", mode: .explain)
        }
    }

    @Test("throws missingAPIKey when the stored key is an empty string")
    func throwsWhenEmptyKey() {
        let km = KeychainManager.testInstance(account: "empty-str-\(UUID().uuidString)")
        km.saveAPIKey("")
        let client = AnthropicClient(session: StubURLProtocol.session(), keychain: km)
        #expect(throws: AnthropicError.missingAPIKey) {
            _ = try client.stream(text: "hi", mode: .explain)
        }
    }

    @Test("buildRequest sets headers, endpoint, and body correctly")
    func buildRequestShape() throws {
        let request = try AnthropicClient.buildRequest(apiKey: "sk-test", text: "photosynthesis", mode: .define)

        #expect(request.url == endpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json?["model"] as? String == "claude-haiku-4-5")
        #expect(json?["max_tokens"] as? Int == 150)
        #expect(json?["stream"] as? Bool == true)
        #expect((json?["system"] as? String)?.contains("concise study assistant") == true)

        let messages = json?["messages"] as? [[String: String]]
        #expect(messages?.first?["role"] == "user")
        #expect(messages?.first?["content"] == "[Define mode] photosynthesis")
    }

    @Test("streams text_delta chunks in order and finishes on [DONE]")
    func streamsTextDeltas() async throws {
        let session = StubURLProtocol.session()
        let events = [
            sseEvent(type: "message_start"),
            sseEvent(type: "content_block_delta", delta: ["type": "text_delta", "text": "Hello"]),
            sseEvent(type: "content_block_delta", delta: ["type": "text_delta", "text": ", "]),
            sseEvent(type: "content_block_delta", delta: ["type": "text_delta", "text": "world."]),
            sseEvent(type: "message_stop"),
            "data: [DONE]",
            "",
        ]
        let body = events.joined(separator: "\n\n").data(using: .utf8)!
        StubURLProtocol.stub(url: endpoint, statusCode: 200, body: body)
        defer { StubURLProtocol.reset() }

        let client = makeClientWithKey("sk-test", session: session)
        let chunks = try await collect(try client.stream(text: "hi", mode: .explain))
        #expect(chunks == ["Hello", ", ", "world."])
    }

    @Test("ignores non-text_delta events and malformed payloads")
    func ignoresNoise() async throws {
        let session = StubURLProtocol.session()
        let events = [
            "data: not-json-at-all",
            sseEvent(type: "ping"),
            sseEvent(type: "content_block_delta", delta: ["type": "input_json_delta", "partial_json": "{}"]),
            sseEvent(type: "content_block_delta", delta: ["type": "text_delta", "text": "OK"]),
            "data: [DONE]",
            "",
        ]
        let body = events.joined(separator: "\n\n").data(using: .utf8)!
        StubURLProtocol.stub(url: endpoint, statusCode: 200, body: body)
        defer { StubURLProtocol.reset() }

        let client = makeClientWithKey("sk-test", session: session)
        let chunks = try await collect(try client.stream(text: "hi", mode: .math))
        #expect(chunks == ["OK"])
    }

    @Test("throws httpError for non-2xx responses")
    func throwsOnHTTPError() async throws {
        let session = StubURLProtocol.session()
        StubURLProtocol.stub(url: endpoint, statusCode: 401, body: Data("unauthorized".utf8))
        defer { StubURLProtocol.reset() }

        let client = makeClientWithKey("sk-test", session: session)
        await #expect(throws: AnthropicError.httpError(401)) {
            _ = try await collect(try client.stream(text: "hi", mode: .explain))
        }
    }

    @Test("stops cleanly when consumer stops iterating")
    func earlyTermination() async throws {
        let session = StubURLProtocol.session()
        let events = [
            sseEvent(type: "content_block_delta", delta: ["type": "text_delta", "text": "one"]),
            sseEvent(type: "content_block_delta", delta: ["type": "text_delta", "text": "two"]),
            sseEvent(type: "content_block_delta", delta: ["type": "text_delta", "text": "three"]),
            "data: [DONE]",
            "",
        ]
        let body = events.joined(separator: "\n\n").data(using: .utf8)!
        StubURLProtocol.stub(url: endpoint, statusCode: 200, body: body)
        defer { StubURLProtocol.reset() }

        let client = makeClientWithKey("sk-test", session: session)
        let stream = try client.stream(text: "hi", mode: .explain)

        var first: String?
        for try await chunk in stream {
            first = chunk
            break  // triggers onTermination → task.cancel()
        }
        #expect(first == "one")
    }
}
