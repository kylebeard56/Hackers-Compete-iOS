//
//  LLMProviderRegistry.swift
//  Hackers
//
//  Factory for injectable LLM providers. Use for OCR, game template generation, etc.
//

import Foundation

enum LLMProviderRegistry {
    static func provider(for config: AIModelConfig) -> LLMProviderProtocol? {
        switch config.provider {
        case .openAI:
            return OpenAIProvider()
        case .anthropic:
            return AnthropicProvider()
        }
    }

    /// Shared default for vision tasks (OCR). Inject into CourseScorecardOCRService.
    static var defaultVisionProvider: LLMProviderProtocol? {
        provider(for: AIModelConfig.defaultForVision)
    }

    /// Shared default for text-only tasks. For future GameTemplateGenerator.
    static var defaultTextProvider: LLMProviderProtocol? {
        provider(for: AIModelConfig.defaultForText)
    }
}
