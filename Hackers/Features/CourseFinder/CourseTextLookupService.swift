//
//  CourseTextLookupService.swift
//  Hackers
//
//  Natural-language course lookup using the app's text LLM provider.
//

import Foundation

enum CourseTextLookupError: Error {
    case apiKeyMissing
    case invalidResponse
    case decodingFailed(String)
    case requestTooLarge
    case rateLimitExceeded
    case overloaded
}

struct AskAICourseLookupContext: Equatable {
    var isLocationAssistEnabled: Bool
    var approximateLocation: ScorecardScanApproximateLocation?

    init(
        isLocationAssistEnabled: Bool = false,
        approximateLocation: ScorecardScanApproximateLocation? = nil
    ) {
        self.isLocationAssistEnabled = isLocationAssistEnabled
        self.approximateLocation = approximateLocation
    }
}

struct AskAICourseCandidate {
    let course: Course
    let requiresReview: Bool
    let isCanonicalMatch: Bool
}

struct AskAICourseChatMessage: Identifiable {
    enum Role: String {
        case user
        case assistant
    }

    let id: String
    let role: Role
    let text: String
    let candidate: AskAICourseCandidate?

    init(
        id: String = HackersID.string(),
        role: Role,
        text: String,
        candidate: AskAICourseCandidate? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.candidate = candidate
    }

    var isUser: Bool {
        role == .user
    }
}

struct AskAICourseLookupResult {
    let assistantMessage: String
    let candidate: AskAICourseCandidate?
}

private struct CourseTextLookupIntentDTO: Decodable {
    let clubName: String?
    let courseName: String?
    let searchText: String?
    let city: String?
    let state: String?
    let country: String?
    let confidence: String?
    let needsMoreDetail: Bool?
}

private enum CourseTextLookupPrompt {
    static func systemPrompt(context: AskAICourseLookupContext = .init()) -> String {
        var prompt = """
        You help identify golf courses from natural-language conversation.
        Your job is to extract the most likely course identity clues from the conversation so the app can search a golf course API.

        Extraction rules:
        - Use only clues the user actually provided or that are directly implied by the conversation.
        - Focus on course identification clues such as club name, course name, city, state, country, resort or trail name, or a concise search phrase.
        - Prefer precise names when they are supported, but do not invent names, tee data, yardage, phone numbers, websites, or coordinates.
        - If the user is vague or ambiguous, set needsMoreDetail to true.
        - searchText should be a concise, useful search phrase for a golf course API, not a sentence.
        - clubName and courseName may both be null if the conversation does not support them.
        - Return ONLY JSON.
        """

        if context.isLocationAssistEnabled, context.approximateLocation != nil {
            prompt += """

            Location-assist rule:
            - Approximate user location may be provided only to help a later course-matching step break ties between otherwise plausible text-supported candidates.
            - Never use approximate location alone to identify the course.
            - Never infer address, coordinates, website, or phone from approximate location.
            """
        }

        prompt += """

        Use this exact schema (camelCase):
        {
          "clubName": "string or null",
          "courseName": "string or null",
          "searchText": "string or null",
          "city": "string or null",
          "state": "string or null",
          "country": "string or null",
          "confidence": "low" or "medium" or "high" or null,
          "needsMoreDetail": true or false or null
        }
        """

        return prompt
    }

    static func finalInstruction(context: AskAICourseLookupContext = .init()) -> String {
        var instruction = "Based on the full conversation above, extract the best-supported course lookup clues as JSON."

        if context.isLocationAssistEnabled,
           let approximateLocation = context.approximateLocation {
            instruction += "\nApproximate location for later tie-break only: \(approximateLocation.promptDescription)"
        }

        return instruction
    }
}

@MainActor
final class CourseTextLookupService: Loggable {
    static let shared = CourseTextLookupService()

    private let injectedProvider: LLMProviderProtocol?
    private let enrichmentService: CourseScorecardEnrichmentService

    init(
        provider: LLMProviderProtocol? = nil,
        enrichmentService: CourseScorecardEnrichmentService? = nil
    ) {
        self.injectedProvider = provider
        self.enrichmentService = enrichmentService ?? .shared
    }

    func resolveCourse(
        from transcript: [AskAICourseChatMessage],
        context: AskAICourseLookupContext = .init()
    ) async throws -> AskAICourseLookupResult {
        guard let provider = injectedProvider ?? LLMProviderRegistry.defaultTextProvider else {
            addBreadcrumb(level: .error, message: "LLM provider not available for Ask AI course lookup")
            throw CourseTextLookupError.apiKeyMissing
        }

        let messages = buildMessages(from: transcript, context: context)
        let maxTokens = 2_000

        let intent: CourseTextLookupIntentDTO
        do {
            let response = try await provider.complete(
                messages: messages,
                model: nil,
                maxTokens: maxTokens
            )
            intent = try parseIntent(from: response)
        } catch OpenAIProviderError.apiKeyMissing, AnthropicProviderError.apiKeyMissing {
            throw CourseTextLookupError.apiKeyMissing
        } catch OpenAIProviderError.requestTooLarge, AnthropicProviderError.requestTooLarge {
            throw CourseTextLookupError.requestTooLarge
        } catch OpenAIProviderError.rateLimitExceeded, AnthropicProviderError.rateLimitExceeded {
            throw CourseTextLookupError.rateLimitExceeded
        } catch OpenAIProviderError.overloaded, AnthropicProviderError.overloaded {
            throw CourseTextLookupError.overloaded
        } catch {
            throw error
        }

        let draft = mapToDraftCourse(intent)
        let scanContext = ScorecardScanContext(
            isLocationAssistEnabled: context.isLocationAssistEnabled,
            approximateLocation: context.approximateLocation
        )

        if let canonicalCourse = await enrichmentService.resolveCanonicalCourse(
            for: draft,
            scanContext: scanContext
        ) {
            return AskAICourseLookupResult(
                assistantMessage: confirmedCourseMessage(for: canonicalCourse),
                candidate: AskAICourseCandidate(
                    course: canonicalCourse,
                    requiresReview: false,
                    isCanonicalMatch: true
                )
            )
        }

        if draft.courseName.isPopulated || draft.clubName.isPopulated {
            return AskAICourseLookupResult(
                assistantMessage: draftCourseMessage(
                    for: draft,
                    needsMoreDetail: intent.needsMoreDetail == true
                ),
                candidate: AskAICourseCandidate(
                    course: draft,
                    requiresReview: true,
                    isCanonicalMatch: false
                )
            )
        }

        return AskAICourseLookupResult(
            assistantMessage: "I need a bit more detail to pin it down. Try the course name, club name, city/state, resort or trail, or another identifying clue.",
            candidate: nil
        )
    }

    private func buildMessages(
        from transcript: [AskAICourseChatMessage],
        context: AskAICourseLookupContext
    ) -> [LLMMessage] {
        var messages: [LLMMessage] = [
            LLMMessage(
                role: "system",
                content: [.text(CourseTextLookupPrompt.systemPrompt(context: context))]
            )
        ]

        messages += transcript.map { message in
            LLMMessage(
                role: message.role.rawValue,
                content: [.text(message.text)]
            )
        }

        messages.append(
            LLMMessage(
                role: "user",
                content: [.text(CourseTextLookupPrompt.finalInstruction(context: context))]
            )
        )

        return messages
    }

    private func parseIntent(from content: String) throws -> CourseTextLookupIntentDTO {
        do {
            return try decodeIntent(from: content)
        } catch {
            let truncated = String(content.prefix(500))
            throw CourseTextLookupError.decodingFailed("\(error.localizedDescription). Raw (truncated): \(truncated)")
        }
    }

    private func decodeIntent(from content: String) throws -> CourseTextLookupIntentDTO {
        let data = try jsonUTF8Data(from: content)
        let decoder = JSONDecoder()

        if let dto = try? decoder.decode(CourseTextLookupIntentDTO.self, from: data) {
            return dto
        }

        let snakeDecoder = JSONDecoder()
        snakeDecoder.keyDecodingStrategy = .convertFromSnakeCase
        if let dto = try? snakeDecoder.decode(CourseTextLookupIntentDTO.self, from: data) {
            return dto
        }

        return try decoder.decode(CourseTextLookupIntentDTO.self, from: data)
    }

    private func jsonUTF8Data(from content: String) throws -> Data {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if let match = text.firstMatch(of: /```(?:json|JSON)?\s*\n?([\s\S]*?)```/) {
            text = String(match.1).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```JSON", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        text = text
            .replacingOccurrences(of: ",]", with: "]")
            .replacingOccurrences(of: ",}", with: "}")

        guard let data = text.data(using: .utf8) else {
            throw CourseTextLookupError.invalidResponse
        }

        if (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        guard let sliced = extractFirstJSONObjectSubstring(from: text),
              let slicedData = sliced.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: slicedData)) != nil else {
            throw CourseTextLookupError.invalidResponse
        }

        return slicedData
    }

    private func extractFirstJSONObjectSubstring(from string: String) -> String? {
        guard let start = string.firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = start

        while index < string.endIndex {
            let character = string[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(string[start...index])
                }
            }
            index = string.index(after: index)
        }

        return nil
    }

    private func mapToDraftCourse(_ intent: CourseTextLookupIntentDTO) -> Course {
        let trimmedClub = normalized(intent.clubName)
        let trimmedCourse = normalized(intent.courseName)
        let searchText = normalized(intent.searchText)

        let resolvedCourseName = trimmedCourse ?? trimmedClub ?? searchText ?? ""
        let resolvedClubName = trimmedClub ?? trimmedCourse ?? searchText ?? ""

        return Course(
            golfCourseApiID: nil,
            origin: .manual,
            clubName: resolvedClubName,
            courseName: resolvedCourseName,
            location: nil,
            venueDetails: nil,
            locationGeohash: nil,
            tees: []
        )
    }

    private func confirmedCourseMessage(for course: Course) -> String {
        let name = course.prettyCourseName.isPopulated ? course.prettyCourseName : course.prettyClubName
        let tee = preferredSummaryTee(for: course)
        var parts = ["I think I found the course you're looking for: \(name)."]

        if let location = course.location,
           let city = location.city,
           let state = location.state,
           city.isPopulated,
           state.isPopulated {
            parts.append("\(city), \(state).")
        }

        if let tee {
            let segment = course.defaultSegment
            parts.append("\(tee.totalHoles) holes, par \(tee.par(for: segment)), \(tee.yardage(for: segment)) yards from the \(tee.name) tees.")
        } else if course.defaultSegment.holeCount > 0 {
            parts.append("\(course.defaultSegment.holeCount) holes.")
        }

        return parts.joined(separator: " ")
    }

    private func draftCourseMessage(
        for course: Course,
        needsMoreDetail: Bool
    ) -> String {
        let name = course.prettyCourseName.isPopulated ? course.prettyCourseName : course.prettyClubName
        if name.isPopulated {
            if needsMoreDetail {
                return "I have a possible course draft for \(name), but I’m not confident enough to lock it in yet. Review it and tweak anything that looks off, or keep chatting with a bit more detail."
            }
            return "I put together a draft for \(name). Review it before continuing, or keep chatting if you want me to refine the match."
        }

        return "I found a few hints, but not enough to build a reliable course yet. Try adding the course name, city/state, resort or trail, or another identifying detail."
    }

    private func preferredSummaryTee(for course: Course) -> Tee? {
        if let male = course.tees.male.first {
            return male
        }
        if let other = course.tees.other.first {
            return other
        }
        return course.tees.first
    }

    private func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isPopulated else {
            return nil
        }
        return value
    }
}
