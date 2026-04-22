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
    case requestTooLarge
    case rateLimitExceeded
    case overloaded
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

        let modelToUse = model ?? AIModelConfig.defaultForText.model

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
            switch http.statusCode {
            case 413: throw AnthropicProviderError.requestTooLarge
            case 429: throw AnthropicProviderError.rateLimitExceeded
            case 503, 529: throw AnthropicProviderError.overloaded
            default: throw AnthropicProviderError.invalidStatusCode(code: http.statusCode)
            }
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

    // MARK: - Scorecard OCR with Tools (structured output)

    /// Extracts course data from a scorecard image using Anthropic tools for structured output.
    func extractScorecardWithTools(
        imageBase64: String,
        model: String?,
        maxTokens: Int,
        scanContext: ScorecardScanContext = .init()
    ) async throws -> CourseScorecardDTO {
        guard apiKey.isPopulated else {
            addBreadcrumb(level: .error, message: "ANTHROPIC_API_KEY missing")
            throw AnthropicProviderError.apiKeyMissing
        }

        guard let url = URL(string: baseURL) else {
            throw AnthropicProviderError.invalidURL
        }

        let modelToUse = model ?? AIModelConfig.defaultForVision.model

        let body: [String: Any] = [
            "model": modelToUse,
            "max_tokens": maxTokens,
            "system": CourseScorecardOCRPrompt.systemPrompt(scanContext: scanContext),
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": imageBase64
                            ]
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
                    "name": "extract_scorecard",
                    "description": "Extract golf course data from a scorecard image",
                    "input_schema": CourseScorecardSchema.anthropicInputSchema()
                ]
            ],
            "tool_choice": ["type": "tool", "name": "extract_scorecard"]
        ]

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
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[Anthropic OCR] status \(http.statusCode): \(body)")
            addBreadcrumb(level: .error, message: "Anthropic status \(http.statusCode): \(body)")
            switch http.statusCode {
            case 413: throw AnthropicProviderError.requestTooLarge
            case 429: throw AnthropicProviderError.rateLimitExceeded
            case 503, 529: throw AnthropicProviderError.overloaded
            default: throw AnthropicProviderError.invalidStatusCode(code: http.statusCode)
            }
        }

        let rawString = String(data: data, encoding: .utf8) ?? ""
        do {
            let toolResponse = try JSONDecoder().decode(AnthropicScorecardToolMessageResponse.self, from: data)
            guard let toolBlock = toolResponse.content.first(where: { $0.type == "tool_use" }),
                  let output = toolBlock.input else {
                print("[Anthropic OCR] invalidResponse: no tool_use block or input. Raw response (truncated): \(String(rawString.prefix(2000)))")
                addBreadcrumb(level: .error, message: "Anthropic OCR: no tool_use in response")
                throw AnthropicProviderError.invalidResponse
            }
            return output.scorecard
        } catch {
            print("[Anthropic OCR] decode failed: \(error). Raw response (truncated): \(String(rawString.prefix(2000)))")
            addBreadcrumb(level: .error, message: "Anthropic OCR decode failed", error: error)
            throw AnthropicProviderError.invalidResponse
        }
    }

    // MARK: - AskAI Course Lookup with Web Search + Tools

    /// Identifies a golf course from natural-language conversation, using Anthropic's server-side
    /// `web_search` tool to look up the official scorecard, then returns the structured DTO via
    /// the `extract_scorecard` tool. The model iteratively searches and extracts in a single call.
    func extractCourseFromConversation(
        messages: [LLMMessage],
        model: String?,
        scanContext: ScorecardScanContext = .init()
    ) async throws -> AskAICourseLookupDTO {
        guard apiKey.isPopulated else {
            addBreadcrumb(level: .error, message: "ANTHROPIC_API_KEY missing")
            throw AnthropicProviderError.apiKeyMissing
        }

        guard let url = URL(string: baseURL) else {
            throw AnthropicProviderError.invalidURL
        }

        let modelToUse = model ?? AIModelConfig.anthropicSonnet46ModelID

        var systemContent: String?
        var apiMessages: [[String: Any]] = []
        for message in messages {
            if message.role == "system" {
                systemContent = message.content.compactMap { item -> String? in
                    if case .text(let t) = item { return t }
                    return nil
                }.joined(separator: "\n")
            } else {
                apiMessages.append([
                    "role": message.role,
                    "content": mapToAnthropicContent(message.content)
                ])
            }
        }

        var body: [String: Any] = [
            "model": modelToUse,
            "max_tokens": 4_096,
            "temperature": 0,
            "messages": apiMessages,
            "tools": [
                [
                    "type": "web_search_20250305",
                    "name": "web_search",
                    // Each web_search result is appended to the input context. On Tier 1
                    // (30K input TPM), 5 searches can blow the budget. Cap at 2.
                    "max_uses": 2
                ],
                [
                    "name": "extract_course_lookup",
                    "description": "Return the resolved course identity, confidence, any public scorecard you found, and ordered Golf Course API backup search strings.",
                    "input_schema": CourseScorecardSchema.anthropicAskAIInputSchema()
                ]
            ]
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
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[Anthropic AskAI] status \(http.statusCode): \(body)")
            addBreadcrumb(level: .error, message: "Anthropic AskAI status \(http.statusCode): \(body)")
            switch http.statusCode {
            case 413: throw AnthropicProviderError.requestTooLarge
            case 429: throw AnthropicProviderError.rateLimitExceeded
            case 503, 529: throw AnthropicProviderError.overloaded
            default: throw AnthropicProviderError.invalidStatusCode(code: http.statusCode)
            }
        }

        let rawString = String(data: data, encoding: .utf8) ?? ""
        logAskAITrace(rawData: data)
        do {
            let toolResponse = try JSONDecoder().decode(AnthropicAskAIToolMessageResponse.self, from: data)
            guard let toolBlock = toolResponse.content.first(where: { $0.type == "tool_use" && $0.name == "extract_course_lookup" }),
                  let output = toolBlock.input else {
                print("[Anthropic AskAI] invalidResponse: no extract_course_lookup tool_use. Raw response (truncated): \(String(rawString.prefix(2000)))")
                addBreadcrumb(level: .error, message: "Anthropic AskAI: no extract_course_lookup tool_use in response")
                throw AnthropicProviderError.invalidResponse
            }
            logExtractedLookup(output.courseLookup)
            return output.courseLookup
        } catch {
            print("[Anthropic AskAI] decode failed: \(error). Raw response (truncated): \(String(rawString.prefix(2000)))")
            addBreadcrumb(level: .error, message: "Anthropic AskAI decode failed", error: error)
            throw AnthropicProviderError.invalidResponse
        }
    }

    /// Pretty-print every web_search call the model issued and the URLs each one returned,
    /// plus any free-text reasoning. Lets us see exactly which sources the model relied on.
    private func logAskAITrace(rawData: Data) {
        guard let trace = try? JSONDecoder().decode(AnthropicAskAITraceResponse.self, from: rawData) else {
            print("[Anthropic AskAI] trace: <unable to decode response shell>")
            return
        }
        for (index, block) in trace.content.enumerated() {
            switch block.type {
            case "server_tool_use":
                let query = block.input?.query ?? "<no query>"
                print("[Anthropic AskAI] step \(index): \(block.name ?? "tool") → query=\"\(query)\"")
            case "web_search_tool_result":
                let urls = (block.content ?? []).compactMap { $0.url }
                if urls.isEmpty {
                    print("[Anthropic AskAI] step \(index): web_search returned 0 results")
                } else {
                    print("[Anthropic AskAI] step \(index): web_search returned \(urls.count) result(s):")
                    for url in urls.prefix(8) {
                        print("    - \(url)")
                    }
                }
            case "text":
                if let text = block.text, !text.isEmpty {
                    print("[Anthropic AskAI] step \(index): model text → \(text.prefix(400))")
                }
            case "tool_use":
                print("[Anthropic AskAI] step \(index): tool_use → \(block.name ?? "<unnamed>")")
            default:
                print("[Anthropic AskAI] step \(index): \(block.type)")
            }
        }
    }

    private func logExtractedLookup(_ dto: AskAICourseLookupDTO) {
        let club = dto.clubName ?? dto.scorecard?.clubName ?? "?"
        let course = dto.courseName ?? dto.scorecard?.courseName ?? "?"
        let teeCount = dto.scorecard?.tees?.count ?? 0
        print("[Anthropic AskAI] extracted: club=\"\(club)\" course=\"\(course)\" confidence=\(dto.confidence?.rawValue ?? "?") tees=\(teeCount)")
        for tee in dto.scorecard?.tees ?? [] {
            let name = tee.name ?? "<unnamed>"
            let holes = tee.holes?.count ?? 0
            let yardage = (tee.holes ?? []).compactMap { $0.yardage }.reduce(0, +)
            let par = (tee.holes ?? []).compactMap { $0.par }.reduce(0, +)
            print("    tee \"\(name)\" — holes=\(holes), par=\(par), yards=\(yardage), rating=\(tee.courseRating ?? 0), slope=\(tee.slopeRating ?? 0)")
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

private struct AnthropicScorecardToolMessageResponse: Decodable {
    let content: [AnthropicScorecardToolContentBlock]
}

private struct AnthropicAskAIToolMessageResponse: Decodable {
    let content: [AnthropicAskAIToolContentBlock]
}

/// Loose decoder used only for verbose AskAI tracing. Tolerates any combination of
/// text / server_tool_use / web_search_tool_result / tool_use blocks.
private struct AnthropicAskAITraceResponse: Decodable {
    let content: [TraceBlock]

    struct TraceBlock: Decodable {
        let type: String
        let name: String?
        let text: String?
        let input: TraceInput?
        let content: [TraceWebResult]?
    }

    struct TraceInput: Decodable {
        let query: String?
    }

    struct TraceWebResult: Decodable {
        let url: String?
        let title: String?
    }
}

private struct AnthropicScorecardToolContentBlock: Decodable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: CourseScorecardToolOutput?

    private enum CodingKeys: String, CodingKey {
        case type, text, id, name, input
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)

        if type == "tool_use", name == "extract_scorecard" {
            input = try container.decodeIfPresent(CourseScorecardToolOutput.self, forKey: .input)
        } else {
            input = nil
        }
    }
}

private struct AnthropicAskAIToolContentBlock: Decodable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: AskAICourseLookupToolOutput?

    private enum CodingKeys: String, CodingKey {
        case type, text, id, name, input
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)

        if type == "tool_use", name == "extract_course_lookup" {
            input = try container.decodeIfPresent(AskAICourseLookupToolOutput.self, forKey: .input)
        } else {
            input = nil
        }
    }
}
