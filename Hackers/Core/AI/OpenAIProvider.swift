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
    case requestTooLarge
    case rateLimitExceeded
    case overloaded
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

        let modelToUse = model ?? AIModelConfig.defaultForText.model
        let apiMessages = messages.map { mapToOpenAIMessage($0) }

        let body: [String: Any] = [
            "model": modelToUse,
            "messages": apiMessages,
            "max_completion_tokens": maxTokens//,
//            "temperature": 0.1
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
            switch http.statusCode {
            case 413: throw OpenAIProviderError.requestTooLarge
            case 429: throw OpenAIProviderError.rateLimitExceeded
            case 503: throw OpenAIProviderError.overloaded
            default: throw OpenAIProviderError.invalidStatusCode(code: http.statusCode)
            }
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

    // MARK: - Scorecard OCR with Tools (structured output)

    /// Extracts course data from a scorecard image using OpenAI function calling for structured output.
    func extractScorecardWithTools(
        imageBase64: String,
        model: String?,
        maxTokens: Int,
        scanContext: ScorecardScanContext = .init()
    ) async throws -> CourseScorecardDTO {
        guard apiKey.isPopulated else {
            addBreadcrumb(level: .error, message: "OPENAI_API_KEY missing")
            throw OpenAIProviderError.apiKeyMissing
        }

        guard let url = URL(string: baseURL) else {
            throw OpenAIProviderError.invalidURL
        }

        let modelToUse = model ?? AIModelConfig.defaultForVision.model

        let imageUrl = "data:image/jpeg;base64,\(imageBase64)"

        // Reasoning models (gpt-5*, o*) burn completion budget on hidden "thinking" tokens.
        // Without low effort, they can hit max_completion_tokens before emitting tool_calls.
        // Box Fox uses gpt-4o-mini (non-reasoning); see OpenAI reasoning guide + chat completions `reasoning_effort`.
        var body: [String: Any] = [
            "model": modelToUse,
            "max_completion_tokens": maxTokens,
            "messages": [
                [
                    "role": "system",
                    "content": CourseScorecardOCRPrompt.systemPrompt(scanContext: scanContext)
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": ["url": imageUrl]
                        ],
                        [
                            "type": "text",
                            "text": CourseScorecardOCRPrompt.userPrompt(scanContext: scanContext)
                        ]
                    ]
                ]
            ],
            "tools": [
                [
                    "type": "function",
                    "function": [
                        "name": "extract_scorecard",
                        "description": "Extract golf course data from a scorecard image",
                        "parameters": CourseScorecardSchema.openAIParametersSchema()
                    ]
                ]
            ],
            "tool_choice": ["type": "function", "function": ["name": "extract_scorecard"]]
        ]
        if Self.modelUsesReasoningEffort(modelToUse) {
            body["reasoning_effort"] = "low"
        }

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
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[OpenAI OCR] status \(http.statusCode): \(body)")
            addBreadcrumb(level: .error, message: "OpenAI status \(http.statusCode): \(body)")
            switch http.statusCode {
            case 413: throw OpenAIProviderError.requestTooLarge
            case 429: throw OpenAIProviderError.rateLimitExceeded
            case 503: throw OpenAIProviderError.overloaded
            default: throw OpenAIProviderError.invalidStatusCode(code: http.statusCode)
            }
        }

        let rawString = String(data: data, encoding: .utf8) ?? ""
        do {
            let toolResponse = try JSONDecoder().decode(OpenAIChatResponseWithTools.self, from: data)
            guard let toolCall = toolResponse.choices.first?.message.toolCalls?.first,
                  toolCall.function.name == "extract_scorecard" else {
                print("[OpenAI OCR] invalidResponse: no tool_calls or extract_scorecard. Raw response (truncated): \(String(rawString.prefix(2000)))")
                addBreadcrumb(level: .error, message: "OpenAI OCR: no tool_calls in response")
                throw OpenAIProviderError.invalidResponse
            }
            return toolCall.function.arguments.scorecard
        } catch {
            print("[OpenAI OCR] decode failed: \(error). Raw response (truncated): \(String(rawString.prefix(2000)))")
            addBreadcrumb(level: .error, message: "OpenAI OCR decode failed", error: error)
            throw OpenAIProviderError.invalidResponse
        }
    }

    /// Models that allocate hidden reasoning tokens before visible output (Chat Completions `reasoning_effort`).
    private static func modelUsesReasoningEffort(_ model: String) -> Bool {
        let id = model.lowercased()
        return id.contains("gpt-5") || id.contains("o3") || id.contains("o4")
            || id.hasPrefix("o1") || id == "o1" || id.hasPrefix("o1-")
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

private struct OpenAIChatResponseWithTools: Decodable {
    let choices: [OpenAIChoiceWithTools]
}

private struct OpenAIChoiceWithTools: Decodable {
    let message: OpenAIMessageWithTools
}

private struct OpenAIMessageWithTools: Decodable {
    let toolCalls: [OpenAIToolCallScorecard]?
    enum CodingKeys: String, CodingKey {
        case toolCalls = "tool_calls"
    }
}

private struct OpenAIToolCallScorecard: Decodable {
    let id: String
    let type: String
    let function: OpenAIFunctionScorecard
}

private struct OpenAIFunctionScorecard: Decodable {
    let name: String
    let arguments: CourseScorecardToolOutput

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        let argumentsString = try container.decode(String.self, forKey: .arguments)
        guard let data = argumentsString.data(using: .utf8) else {
            throw DecodingError.dataCorruptedError(forKey: .arguments, in: container, debugDescription: "Invalid UTF-8")
        }
        arguments = try JSONDecoder().decode(CourseScorecardToolOutput.self, from: data)
    }

    enum CodingKeys: String, CodingKey {
        case name, arguments
    }
}
