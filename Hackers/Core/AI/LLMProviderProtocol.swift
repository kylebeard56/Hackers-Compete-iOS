//
//  LLMProviderProtocol.swift
//  Hackers
//
//  Generic protocol for injectable LLM providers (OpenAI, Anthropic).
//

import Foundation

enum LLMMessageContent {
    case text(String)
    case image(base64: String, mediaType: String)
}

struct LLMMessage {
    let role: String
    let content: [LLMMessageContent]
}

protocol LLMProviderProtocol {
    /// Generic completion. Supports text-only or image+text (vision).
    /// - Parameters:
    ///   - messages: Array of role + content (text and/or image)
    ///   - model: Optional override; provider uses config default if nil
    ///   - maxTokens: Maximum tokens to generate
    /// - Returns: Raw response text (caller parses JSON or uses as needed)
    func complete(messages: [LLMMessage], model: String?, maxTokens: Int) async throws -> String
}
