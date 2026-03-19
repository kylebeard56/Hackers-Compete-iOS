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
}

@MainActor
final class CourseScorecardOCRService: Loggable {
    static let shared = CourseScorecardOCRService()

    private let provider: LLMProviderProtocol?

    init(provider: LLMProviderProtocol? = nil) {
        self.provider = provider ?? LLMProviderRegistry.defaultVisionProvider
    }

    /// Extracts course data from a scorecard image using Vision API.
    /// Returns a Course with origin `.ocr`; caller should save to Firebase (Option C).
    func extractCourse(from image: UIImage) async throws -> Course {
        guard let provider else {
            addBreadcrumb(level: .error, message: "LLM provider not available; check AI config and API keys")
            throw CourseScorecardOCRError.apiKeyMissing
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            addBreadcrumb(level: .error, message: "Failed to compress JPEG data for scorecard scanning")
            throw CourseScorecardOCRError.invalidResponse
        }
        let base64 = jpegData.base64EncodedString()
        let config = AIModelConfig.defaultForVision
        let messages = buildOCRMessages(imageBase64: base64)
        let rawResponse: String
        do {
            printPretty(messages)
            rawResponse = try await provider.complete(messages: messages, model: config.model, maxTokens: 4096)
        } catch OpenAIProviderError.apiKeyMissing, AnthropicProviderError.apiKeyMissing {
            throw CourseScorecardOCRError.apiKeyMissing
        } catch {
            throw error
        }

        let dto = try parseDTO(from: rawResponse)
        return mapToCourse(dto)
    }

    private func buildOCRMessages(imageBase64: String) -> [LLMMessage] {
        let systemPrompt = """
        You are an expert at reading golf scorecards. Extract the course data from the image and return valid JSON only.
        Use this exact schema (camelCase):
        {
          "clubName": "string or null",
          "courseName": "string or null",
          "location": {
            "address": "string or null",
            "city": "string or null",
            "state": "string or null",
            "country": "string or null",
            "latitude": number or null,
            "longitude": number or null
          },
          "tees": [
            {
              "name": "string (e.g. Blue, White, Red)",
              "gender": "male" or "female",
              "courseRating": number,
              "slopeRating": number,
              "holes": [
                { "number": 1, "par": 4, "yardage": 380, "handicap": 5 }
              ]
            }
          ]
        }
        Return ONLY the JSON object, no markdown or explanation.
        """

        let userMessage = LLMMessage(
            role: "user",
            content: [
                .image(base64: imageBase64, mediaType: "image/jpeg"),
                .text("Extract the golf course data from this scorecard image.")
            ]
        )

        return [
            LLMMessage(role: "system", content: [.text(systemPrompt)]),
            userMessage
        ]
    }

    private func parseDTO(from content: String) throws -> CourseScorecardDTO {
        let jsonString = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw CourseScorecardOCRError.decodingFailed("Invalid UTF-8")
        }

        return try JSONDecoder().decode(CourseScorecardDTO.self, from: jsonData)
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

        let gender = (dto.gender?.lowercased() == "female") ? Gender.female.rawValue : Gender.male.rawValue
        let rating = dto.courseRating ?? 72.0
        let slope = dto.slopeRating ?? 113

        return Tee(
            name: dto.name ?? "Tee \(holes.count)",
            gender: gender,
            totalHoles: holes.count,
            holes: holes,
            ratingFull: rating,
            slopeFull: slope,
            ratingFront: nil,
            slopeFront: nil,
            ratingBack: nil,
            slopeBack: nil
        )
    }

    private func defaultTee() -> Tee {
        let holes = (1...18).map { n in
            Hole(number: n, par: n % 4 == 0 ? 5 : (n % 4 == 3 ? 3 : 4), yardage: 350, handicap: nil)
        }
        return Tee(
            name: "Default",
            gender: Gender.male.rawValue,
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
