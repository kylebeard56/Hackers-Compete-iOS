//
//  CourseScorecardSchema.swift
//  Hackers
//
//  JSON schema for scorecard OCR tool output (OpenAI/Anthropic).
//

import Foundation

/// Wrapper for tool output; providers return { "scorecard": CourseScorecardDTO }.
struct CourseScorecardToolOutput: Decodable {
    let scorecard: CourseScorecardDTO
}

enum CourseScorecardOCRPrompt {
    static func systemPrompt(includeJSONSchema: Bool = false) -> String {
        var prompt = """
        You are an expert at reading golf scorecards and extracting structured course data from a single scorecard image.
        You understand that scorecards are all different by design, so use your golf intelligence to extract sensible
        data that connects, such as par and handicap values by hole and tee boxes offering differing yardage.

        Extraction rules:
        - Extract every distinct tee row shown on the card. Each tee color or tee name must become its own tee object.
        - Preserve tee names exactly as printed, including possible blended or combination tees such as "Gold/White", "White/Red", "Combo", or "Blended".
        - Prioritize data accuracy and preservation for each discrete tee. Each tee should have a differing yardage, but handicap and par are likely same.
        - Do not collapse multiple tee rows into one default tee.
        - Align values by column. Hole 1 values must come from the hole 1 column for that tee, hole 2 from hole 2, and so on.
        - Reuse shared par or handicap rows across tees only when the card clearly shows one shared row for all tees.
        - Never guess missing values or repeat a placeholder number across holes. If a value is missing, obscured, or absent, return null.
        - If course and slope ratings are shown for full, front, or back, extract each visible value and leave missing ones null.
        - If the scorecard labels tees by men, women, ladies, or similar, map that to male or female. If gender is not stated, use unknown.
        - Prefer exact visible text for club name, course name, and location. Leave any missing text null.
        - User notes are hints, not ground truth. If a user note conflicts with the image, trust the image.
        """

        if includeJSONSchema {
            prompt += "\n\n\(jsonSchemaDescription)\nReturn ONLY the JSON object, no markdown or explanation."
        }

        return prompt
    }

    static func userPrompt(userNotes: String? = nil) -> String {
        var prompt = "Extract the golf course data from this scorecard image."

        if let userNotes = normalized(userNotes) {
            prompt += "\nUser notes: \(userNotes)"
        }

        return prompt
    }

    private static func normalized(_ userNotes: String?) -> String? {
        guard let userNotes else { return nil }
        let trimmed = userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static let jsonSchemaDescription = """
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
          "name": "string or null",
          "gender": "male" or "female" or "unknown" or null,
          "courseRating": number or null,
          "slopeRating": integer or null,
          "frontCourseRating": number or null,
          "frontSlopeRating": integer or null,
          "backCourseRating": number or null,
          "backSlopeRating": integer or null,
          "holes": [
            { "number": 1, "par": 4, "yardage": 380, "handicap": 5 }
          ]
        }
      ]
    }
    """
}

enum CourseScorecardSchema {
    /// Schema for the scorecard object (location + tees with holes).
    static var scorecardObjectSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "clubName": ["type": "string", "description": "Club or facility name"],
                "courseName": ["type": "string", "description": "Course name"],
                "location": [
                    "type": "object",
                    "description": "Location details",
                    "properties": [
                        "address": ["type": "string"],
                        "city": ["type": "string"],
                        "state": ["type": "string"],
                        "country": ["type": "string"],
                        "latitude": ["type": "number"],
                        "longitude": ["type": "number"]
                    ]
                ],
                "tees": [
                    "type": "array",
                    "description": "Return one object per distinct tee row shown on the scorecard, including blended or combo tees. Do not merge multiple tee rows into one object.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Exact tee name as printed on the card, including slash-separated blended tees"],
                            "gender": ["type": "string", "enum": ["male", "female", "unknown"]],
                            "courseRating": ["type": "number", "description": "18-hole or full-round course rating when shown"],
                            "slopeRating": ["type": "integer", "description": "18-hole or full-round slope rating when shown"],
                            "frontCourseRating": ["type": "number", "description": "Front-nine course rating when shown"],
                            "frontSlopeRating": ["type": "integer", "description": "Front-nine slope rating when shown"],
                            "backCourseRating": ["type": "number", "description": "Back-nine course rating when shown"],
                            "backSlopeRating": ["type": "integer", "description": "Back-nine slope rating when shown"],
                            "holes": [
                                "type": "array",
                                "description": "One hole entry per visible hole column for this tee row. If par or handicap is shared across all tees, you may copy those shared values into each tee's holes.",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "number": ["type": "integer", "description": "Hole number"],
                                        "par": ["type": "integer", "description": "Par for this hole"],
                                        "yardage": ["type": "integer", "description": "Yardage for this tee on this hole"],
                                        "handicap": ["type": "integer", "description": "Stroke index or handicap for this hole"]
                                    ]
                                ]
                            ]
                        ],
                        "required": ["holes"]
                    ]
                ]
            ],
            "required": []
        ]
    }

    /// Anthropic tool input_schema: { "scorecard": { ... } }
    static func anthropicInputSchema() -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "scorecard": scorecardObjectSchema
            ],
            "required": ["scorecard"]
        ]
    }

    /// OpenAI function parameters schema (same structure).
    static func openAIParametersSchema() -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "scorecard": scorecardObjectSchema
            ],
            "required": ["scorecard"]
        ]
    }
}
