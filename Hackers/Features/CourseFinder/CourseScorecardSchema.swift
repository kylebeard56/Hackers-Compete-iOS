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
                    "description": "Tee sets (Blue, White, Red, etc.)",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Tee name (e.g. Blue, White, Red)"],
                            "gender": ["type": "string", "enum": ["male", "female"]],
                            "courseRating": ["type": "number"],
                            "slopeRating": ["type": "integer"],
                            "holes": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "number": ["type": "integer"],
                                        "par": ["type": "integer"],
                                        "yardage": ["type": "integer"],
                                        "handicap": ["type": "integer"]
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
