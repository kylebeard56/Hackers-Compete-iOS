//
//  AnthropicProvider.swift
//  Hackers
//
//  Anthropic Messages API implementation of LLMProviderProtocol.
//

import Foundation

enum AnthropicProviderError: Error {
    case apiKeyMissing
    case invalidURL
    case invalidResponse
    case invalidStatusCode(code: Int)
}

final class AnthropicProvider: LLMProviderProtocol, Loggable {
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"

    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String ?? ""
    }

    func complete(messages: [LLMMessage], model: String?, maxTokens: Int) async throws -> String {
        guard apiKey.isPopulated else {
            addBreadcrumb(level: .error, message: "ANTHROPIC_API_KEY missing")
            throw AnthropicProviderError.apiKeyMissing
        }

        guard let url = URL(string: baseURL) else {
            throw AnthropicProviderError.invalidURL
        }

        let modelToUse = model ?? AIModelConfig.defaultForVision.model

        var systemContent: String?
        var apiMessages: [[String: Any]] = []

        for message in messages {
            if message.role == "system" {
                systemContent = message.content.compactMap { item -> String? in
                    if case .text(let t) = item { return t }
                    return nil
                }.joined(separator: "\n")
            } else {
                let content = mapToAnthropicContent(message.content)
                apiMessages.append(["role": message.role, "content": content])
            }
        }

        var body: [String: Any] = [
            "model": modelToUse,
            "max_tokens": maxTokens,
            "messages": apiMessages
        ]
        if let system = systemContent {
            body["system"] = system
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicProviderError.invalidResponse
        }
        guard http.statusCode == 200 else {
            addBreadcrumb(level: .error, message: "Anthropic status \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw AnthropicProviderError.invalidStatusCode(code: http.statusCode)
        }

        let msgResponse = try JSONDecoder().decode(AnthropicMessageResponse.self, from: data)
        guard let textBlock = msgResponse.content.first(where: { $0.type == "text" }) else {
            throw AnthropicProviderError.invalidResponse
        }
        return textBlock.text
    }

    private func mapToAnthropicContent(_ content: [LLMMessageContent]) -> [[String: Any]] {
        content.compactMap { item -> [String: Any]? in
            switch item {
            case .text(let text):
                return ["type": "text", "text": text]
            case .image(let base64, let mediaType):
                return [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": mediaType,
                        "data": base64
                    ]
                ]
            }
        }
    }
}

private struct AnthropicMessageResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let type: String
        let text: String
    }
}
