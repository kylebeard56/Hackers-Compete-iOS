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

    // MARK: - API model ids (keep in sync with OpenAI / Anthropic docs)

    /// Default OpenAI model for text completions and vision fallbacks (Juniper tier).
    static let openAIMiniModelID = "gpt-4.1-mini"
    /// OpenAI full model for complex scorecards (Azalea tier).
    static let openAIFullModelID = "gpt-4.1"
    /// Anthropic model for tough scans (Magnolia tier).
    static let anthropicSonnet46ModelID = "claude-sonnet-4-6"

    static var defaultForVision: AIModelConfig {
        AIModelConfig(provider: .openAI, model: openAIMiniModelID)
    }

    static var defaultForText: AIModelConfig {
        AIModelConfig(provider: .openAI, model: openAIMiniModelID)
    }
}
