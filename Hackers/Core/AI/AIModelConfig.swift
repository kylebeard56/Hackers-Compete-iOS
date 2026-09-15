//
//  AIModelConfig.swift
//  Hackers
//
//  Model configuration for injectable LLM providers (OpenAI, Anthropic).
//

import Foundation

enum AIProvider: String {
    case openAI
    case anthropic
}

struct AIModelConfig {
    let provider: AIProvider
    let model: String

    // Stable gateway selections. Actual provider model IDs are owned by Cloud Functions.

    /// Default Luna selection for text and Juniper OCR.
    static let openAIMiniModelID = "luna"
    /// Detailed OCR selection (Azalea tier).
    static let openAIFullModelID = "detailed"
    /// Sonnet selection (Magnolia tier).
    static let anthropicSonnet46ModelID = "sonnet"

    static var defaultForVision: AIModelConfig {
        AIModelConfig(provider: .openAI, model: openAIMiniModelID)
    }

    static var defaultForText: AIModelConfig {
        AIModelConfig(provider: .openAI, model: openAIMiniModelID)
    }
}

enum AskAITextModel: String, CaseIterable, Identifiable {
    case luna = "luna"
    case claudeSonnet46 = "claude-sonnet-4-6"

    var id: String { rawValue }

    static var defaultSelection: AskAITextModel { .luna }

    static func fromStoredRawValue(_ raw: String) -> AskAITextModel {
        AskAITextModel(rawValue: raw) ?? .defaultSelection
    }

    var displayName: String { self == .luna ? "Luna" : "Sonnet" }

    var config: AIModelConfig {
        switch self {
        case .luna:
            return AIModelConfig(provider: .openAI, model: AIModelConfig.openAIMiniModelID)
        case .claudeSonnet46:
            return AIModelConfig(provider: .anthropic, model: AIModelConfig.anthropicSonnet46ModelID)
        }
    }
}
