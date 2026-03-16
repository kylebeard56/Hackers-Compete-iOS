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

    static var defaultForVision: AIModelConfig {
        let providerRaw = Bundle.main.object(forInfoDictionaryKey: "AI_PROVIDER") as? String ?? "openAI"
        let provider = AIProvider(rawValue: providerRaw) ?? .openAI
        let model = Bundle.main.object(forInfoDictionaryKey: "AI_MODEL_VISION") as? String
            ?? (provider == .anthropic ? "claude-3-5-sonnet-20241022" : "gpt-4o")
        return AIModelConfig(provider: provider, model: model)
    }

    static var defaultForText: AIModelConfig {
        let providerRaw = Bundle.main.object(forInfoDictionaryKey: "AI_PROVIDER") as? String ?? "openAI"
        let provider = AIProvider(rawValue: providerRaw) ?? .openAI
        let model = Bundle.main.object(forInfoDictionaryKey: "AI_MODEL_TEXT") as? String
            ?? (provider == .anthropic ? "claude-3-5-sonnet-20241022" : "gpt-4o")
        return AIModelConfig(provider: provider, model: model)
    }
}
