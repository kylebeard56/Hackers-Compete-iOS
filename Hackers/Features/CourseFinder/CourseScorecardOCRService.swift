//
//  CourseScorecardOCRService.swift
//  Hackers
//
//  Vision API client for OCR scorecard scanning. Uses injectable LLM provider (OpenAI/Anthropic).
//

import Foundation
import UIKit

enum CourseScorecardOCRError: Error {
    case apiKeyMissing
    case invalidResponse
    case decodingFailed(String)
    case requestTooLarge
    case rateLimitExceeded
    case overloaded
}

@MainActor
final class CourseScorecardOCRService: Loggable {
    static let shared = CourseScorecardOCRService()

    /// When set (e.g. unit tests), used instead of resolving a provider from `vision.config`.
    private let injectedProvider: LLMProviderProtocol?

    init(provider: LLMProviderProtocol? = nil) {
        self.injectedProvider = provider
    }

    /// Extracts course data from a scorecard image using Vision API.
    /// Prefers structured output via tools (OpenAI/Anthropic); falls back to text + JSON parsing.
    /// Returns a Course with origin `.ocr`; caller should save to Firebase (Option C).
    func extractCourse(
        from image: UIImage,
        userNotes: String? = nil,
        vision: ScorecardScanVisionModel = .defaultSelection
    ) async throws -> Course {
        let config = vision.config
        guard let provider = injectedProvider ?? LLMProviderRegistry.provider(for: config) else {
            addBreadcrumb(level: .error, message: "LLM provider not available; check AI config and API keys")
            throw CourseScorecardOCRError.apiKeyMissing
        }

        guard let base64 = image.base64 else {
            addBreadcrumb(level: .error, message: "Failed to compress JPEG data for scorecard scanning")
            throw CourseScorecardOCRError.invalidResponse
        }

        /// Reasoning models (e.g. gpt-5-nano) use tokens for thinking; need headroom for tool output.
        let maxTokens = 16384

        let dto: CourseScorecardDTO
        do {
            if let anthropic = provider as? AnthropicProvider {
                dto = try await anthropic.extractScorecardWithTools(
                    imageBase64: base64,
                    model: config.model,
                    maxTokens: maxTokens,
                    userNotes: userNotes
                )
            } else if let openai = provider as? OpenAIProvider {
                dto = try await openai.extractScorecardWithTools(
                    imageBase64: base64,
                    model: config.model,
                    maxTokens: maxTokens,
                    userNotes: userNotes
                )
            } else {
                let messages = buildOCRMessages(imageBase64: base64, userNotes: userNotes)
                let rawResponse = try await provider.complete(messages: messages, model: config.model, maxTokens: maxTokens)
                dto = try parseDTO(from: rawResponse)
            }
        } catch OpenAIProviderError.apiKeyMissing, AnthropicProviderError.apiKeyMissing {
            throw CourseScorecardOCRError.apiKeyMissing
        } catch OpenAIProviderError.requestTooLarge, AnthropicProviderError.requestTooLarge {
            throw CourseScorecardOCRError.requestTooLarge
        } catch OpenAIProviderError.rateLimitExceeded, AnthropicProviderError.rateLimitExceeded {
            throw CourseScorecardOCRError.rateLimitExceeded
        } catch OpenAIProviderError.overloaded, AnthropicProviderError.overloaded {
            throw CourseScorecardOCRError.overloaded
        } catch {
            throw error
        }

        return mapToCourse(dto)
    }

    private func buildOCRMessages(imageBase64: String, userNotes: String?) -> [LLMMessage] {
        let userMessage = LLMMessage(
            role: "user",
            content: [
                .image(base64: imageBase64, mediaType: "image/jpeg"),
                .text(CourseScorecardOCRPrompt.userPrompt(userNotes: userNotes))
            ]
        )

        return [
            LLMMessage(role: "system", content: [.text(CourseScorecardOCRPrompt.systemPrompt(includeJSONSchema: true))]),
            userMessage
        ]
    }

    private func parseDTO(from content: String) throws -> CourseScorecardDTO {
        do {
            return try CourseScorecardLLMDecoding.decode(from: content)
        } catch {
            let truncated = String(content.prefix(500))
            throw CourseScorecardOCRError.decodingFailed("\(error.localizedDescription). Raw (truncated): \(truncated)")
        }
    }

    private func mapToCourse(_ dto: CourseScorecardDTO) -> Course {
        let clubName = dto.clubName ?? dto.courseName ?? ""
        let courseName = dto.courseName ?? dto.clubName ?? clubName

        let location: CourseLocation?
        if let loc = dto.location, (loc.latitude != nil || loc.longitude != nil) {
            let lat = loc.latitude ?? 0
            let lon = loc.longitude ?? 0
            location = CourseLocation(
                address: loc.address,
                city: loc.city,
                state: loc.state,
                country: loc.country,
                latitude: lat,
                longitude: lon
            )
        } else {
            location = nil
        }

        let tees: [Tee] = (dto.tees ?? []).compactMap { mapTee($0) }

        return Course(
            golfCourseApiID: nil,
            origin: .ocr,
            clubName: clubName,
            courseName: courseName,
            location: location,
            locationGeohash: location?.geohash,
            tees: tees.isEmpty ? [defaultTee()] : tees
        )
    }

    private func mapTee(_ dto: CourseScorecardTeeDTO) -> Tee? {
        let holesDTO = dto.holes ?? []
        guard !holesDTO.isEmpty else { return nil }

        let holes: [Hole] = holesDTO.enumerated().map { index, h in
            Hole(
                number: h.number ?? (index + 1),
                par: h.par ?? 4,
                yardage: h.yardage ?? 0,
                handicap: h.handicap
            )
        }

        let gender = mapGender(dto.gender)
        let rating = dto.courseRating ?? dto.frontCourseRating ?? dto.backCourseRating ?? 72.0
        let slope = dto.slopeRating ?? dto.frontSlopeRating ?? dto.backSlopeRating ?? 113

        return Tee(
            name: dto.name ?? "Tee \(holes.count)",
            gender: gender,
            totalHoles: holes.count,
            holes: holes,
            ratingFull: rating,
            slopeFull: slope,
            ratingFront: dto.frontCourseRating,
            slopeFront: dto.frontSlopeRating,
            ratingBack: dto.backCourseRating,
            slopeBack: dto.backSlopeRating
        )
    }

    private func mapGender(_ value: String?) -> String {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "male", "men", "man", "mens":
            return Gender.male.rawValue
        case "female", "women", "woman", "womens", "ladies", "lady":
            return Gender.female.rawValue
        default:
            return Gender.unknown.rawValue
        }
    }

    private func defaultTee() -> Tee {
        let holes = (1...18).map { n in
            Hole(number: n, par: n % 4 == 0 ? 5 : (n % 4 == 3 ? 3 : 4), yardage: 350, handicap: nil)
        }
        return Tee(
            name: "Default",
            gender: Gender.unknown.rawValue,
            totalHoles: 18,
            holes: holes,
            ratingFull: 72.0,
            slopeFull: 113,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )
    }
}
