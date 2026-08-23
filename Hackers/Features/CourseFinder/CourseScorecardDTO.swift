//
//  CourseScorecardDTO.swift
//  Hackers
//
//  DTO for OCR scorecard JSON from Vision API (OpenAI/Anthropic).
//

import Foundation

struct CourseScorecardDTO: Decodable {
    let clubName: String?
    let courseName: String?
    let location: CourseScorecardLocationDTO?
    let tees: [CourseScorecardTeeDTO]?
}

enum AskAICourseLookupConfidence: String, Decodable {
    case high
    case medium
    case low
}

struct AskAICourseLookupDTO: Decodable {
    let clubName: String?
    let courseName: String?
    let location: CourseScorecardLocationDTO?
    let confidence: AskAICourseLookupConfidence?
    let officialWebsiteURL: String?
    let apiSearchStrings: [String]?
    let scorecard: CourseScorecardDTO?

    var hasRealScorecard: Bool {
        (scorecard?.tees ?? []).contains { ($0.holes ?? []).isEmpty == false }
    }

    var mergedScorecard: CourseScorecardDTO {
        CourseScorecardDTO(
            clubName: clubName ?? scorecard?.clubName,
            courseName: courseName ?? scorecard?.courseName,
            location: location ?? scorecard?.location,
            tees: scorecard?.tees
        )
    }
}

struct CourseScorecardLocationDTO: Decodable {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
}

struct CourseScorecardTeeDTO: Decodable {
    let name: String?
    let gender: String?
    let holes: [CourseScorecardHoleDTO]?
    let courseRating: Double?
    let slopeRating: Int?
    let frontCourseRating: Double?
    let frontSlopeRating: Int?
    let backCourseRating: Double?
    let backSlopeRating: Int?
}

struct CourseScorecardHoleDTO: Decodable {
    let number: Int?
    let par: Int?
    let yardage: Int?
    let handicap: Int?
}

/// Wrapper for Ask AI lookup tool output; providers return { "courseLookup": AskAICourseLookupDTO }.
struct AskAICourseLookupToolOutput: Decodable {
    let courseLookup: AskAICourseLookupDTO
}

// MARK: - Decode from LLM plain-text responses (non-tool fallback)

enum CourseScorecardLLMDecodingError: Error {
    case invalidUTF8
    case noJSONObject
}

enum AskAICourseLookupLLMDecodingError: Error {
    case invalidUTF8
    case noJSONObject
}

/// Parses LLM output into `CourseScorecardDTO` using `JSONDecoder` and known envelope shapes.
enum CourseScorecardLLMDecoding {
    /// `{ "scorecard": { ... } }` — same shape as tool output when the model echoes it in text.
    private struct ScorecardKeyEnvelope: Decodable {
        let scorecard: CourseScorecardDTO
    }

    static func decode(from content: String) throws -> CourseScorecardDTO {
        let data = try jsonUTF8Data(from: content)
        return try decodeDTO(from: data)
    }

    private static func decodeDTO(from data: Data) throws -> CourseScorecardDTO {
        let decoder = JSONDecoder()

        if let dto = try? decoder.decode(CourseScorecardDTO.self, from: data) {
            return dto
        }

        let snakeDecoder = JSONDecoder()
        snakeDecoder.keyDecodingStrategy = .convertFromSnakeCase
        if let dto = try? snakeDecoder.decode(CourseScorecardDTO.self, from: data) {
            return dto
        }

        if let envelope = try? decoder.decode(ScorecardKeyEnvelope.self, from: data) {
            return envelope.scorecard
        }
        if let envelope = try? snakeDecoder.decode(ScorecardKeyEnvelope.self, from: data) {
            return envelope.scorecard
        }

        return try decoder.decode(CourseScorecardDTO.self, from: data)
    }

    private static func jsonUTF8Data(from content: String) throws -> Data {
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
            throw CourseScorecardLLMDecodingError.invalidUTF8
        }

        if (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        guard let sliced = extractFirstJSONObjectSubstring(from: text),
              let slicedData = sliced.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: slicedData)) != nil else {
            throw CourseScorecardLLMDecodingError.noJSONObject
        }
        return slicedData
    }

    /// Used only when the string is not valid JSON as-is (e.g. leading prose before `{`).
    private static func extractFirstJSONObjectSubstring(from string: String) -> String? {
        guard let start = string.firstIndex(of: "{") else { return nil }
        var depth = 0
        var i = start
        while i < string.endIndex {
            let c = string[i]
            if c == "{" {
                depth += 1
            } else if c == "}" {
                depth -= 1
                if depth == 0 {
                    return String(string[start...i])
                }
            }
            i = string.index(after: i)
        }
        return nil
    }
}

enum AskAICourseLookupLLMDecoding {
    private struct CourseLookupKeyEnvelope: Decodable {
        let courseLookup: AskAICourseLookupDTO
    }

    static func decode(from content: String) throws -> AskAICourseLookupDTO {
        let data = try jsonUTF8Data(from: content)
        return try decodeDTO(from: data)
    }

    private static func decodeDTO(from data: Data) throws -> AskAICourseLookupDTO {
        let decoder = JSONDecoder()
        let snakeDecoder = JSONDecoder()
        snakeDecoder.keyDecodingStrategy = .convertFromSnakeCase

        if let envelope = try? decoder.decode(CourseLookupKeyEnvelope.self, from: data) {
            return envelope.courseLookup
        }
        if let envelope = try? snakeDecoder.decode(CourseLookupKeyEnvelope.self, from: data) {
            return envelope.courseLookup
        }
        if let dto = try? decoder.decode(AskAICourseLookupDTO.self, from: data) {
            return dto
        }
        if let dto = try? snakeDecoder.decode(AskAICourseLookupDTO.self, from: data) {
            return dto
        }

        return try decoder.decode(AskAICourseLookupDTO.self, from: data)
    }

    private static func jsonUTF8Data(from content: String) throws -> Data {
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
            throw AskAICourseLookupLLMDecodingError.invalidUTF8
        }

        if (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        guard let sliced = extractFirstJSONObjectSubstring(from: text),
              let slicedData = sliced.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: slicedData)) != nil else {
            throw AskAICourseLookupLLMDecodingError.noJSONObject
        }
        return slicedData
    }

    private static func extractFirstJSONObjectSubstring(from string: String) -> String? {
        guard let start = string.firstIndex(of: "{") else { return nil }
        var depth = 0
        var i = start
        while i < string.endIndex {
            let c = string[i]
            if c == "{" {
                depth += 1
            } else if c == "}" {
                depth -= 1
                if depth == 0 {
                    return String(string[start...i])
                }
            }
            i = string.index(after: i)
        }
        return nil
    }
}
