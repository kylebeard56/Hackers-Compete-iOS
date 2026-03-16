//
//  OpenAIProvider.swift
//  Hackers
//
//  OpenAI Chat Completions API implementation of LLMProviderProtocol.
//

import Foundation

enum OpenAIProviderError: Error {
    case apiKeyMissing
    case invalidURL
    case invalidResponse
    case invalidStatusCode(code: Int)
}

final class OpenAIProvider: LLMProviderProtocol, Loggable {
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
    }

    func complete(messages: [LLMMessage], model: String?, maxTokens: Int) async throws -> String {
        guard apiKey.isPopulated else {
            addBreadcrumb(level: .error, message: "OPENAI_API_KEY missing")
            throw OpenAIProviderError.apiKeyMissing
        }

        guard let url = URL(string: baseURL) else {
            throw OpenAIProviderError.invalidURL
        }

        let modelToUse = model ?? AIModelConfig.defaultForVision.model
        let apiMessages = messages.map { mapToOpenAIMessage($0) }

        let body: [String: Any] = [
            "model": modelToUse,
            "messages": apiMessages,
            "max_tokens": maxTokens,
            "temperature": 0.1
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIProviderError.invalidResponse
        }
        guard http.statusCode == 200 else {
            addBreadcrumb(level: .error, message: "OpenAI status \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw OpenAIProviderError.invalidStatusCode(code: http.statusCode)
        }

        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw OpenAIProviderError.invalidResponse
        }
        return content
    }

    private func mapToOpenAIMessage(_ message: LLMMessage) -> [String: Any] {
        let content: [[String: Any]] = message.content.compactMap { item in
            switch item {
            case .text(let text):
                return ["type": "text", "text": text]
            case .image(let base64, let mediaType):
                let url = "data:\(mediaType);base64,\(base64)"
                return [
                    "type": "image_url",
                    "image_url": ["url": url]
                ]
            }
        }
        return ["role": message.role, "content": content]
    }
}

private struct OpenAIChatResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
    }
    struct Message: Decodable {
        let content: String?
    }
}
