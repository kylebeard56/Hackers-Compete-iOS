//
//  ScorecardScanVisionModel.swift
//  Hackers
//
//  User-selectable scorecard OCR tiers (Hackers-branded names). API ids must match provider docs.
//

import Foundation

/// Tiers offered in the Scan notes sheet. Raw value is persisted via `AppStorage`.
/// `CaseIterable` order is the menu order: Juniper (default), Azalea, Magnolia.
enum ScorecardScanVisionModel: String, CaseIterable, Identifiable {
    /// Fast, easy reads — OpenAI `gpt-4.1-mini`.
    case juniper = "juniper"
    /// Complex scorecards & small type — OpenAI `gpt-4.1`.
    case azalea = "azalea"
    /// Messy scans, glare, tough lighting — Anthropic `claude-sonnet-4-6`.
    case magnolia = "magnolia"

    var id: String { rawValue }

    static var defaultSelection: ScorecardScanVisionModel { .juniper }

    /// Resolves stored raw value, including legacy keys from earlier app versions.
    static func fromStoredRawValue(_ raw: String) -> ScorecardScanVisionModel {
        if let known = ScorecardScanVisionModel(rawValue: raw) {
            return known
        }
        switch raw {
        case "gpt5Nano", "teaOlive":
            return .juniper
        case "gpt53":
            return .azalea
        case "claudeSonnet46", "redbud":
            return .magnolia
        default:
            return .defaultSelection
        }
    }

    var displayName: String {
        switch self {
        case .juniper: return "Juniper"
        case .azalea: return "Azalea"
        case .magnolia: return "Magnolia"
        }
    }

    /// Tier hint shown under the name in the picker menu.
    var tierSubtitle: String {
        switch self {
        case .juniper:
            return "Fast, easy reads"
        case .azalea:
            return "Complex or small type"
        case .magnolia:
            return "Messy layout or low lighting"
        }
    }

    /// Provider and API model string for this scan.
    var config: AIModelConfig {
        switch self {
        case .juniper:
            return AIModelConfig(provider: .openAI, model: AIModelConfig.openAIMiniModelID)
        case .azalea:
            return AIModelConfig(provider: .openAI, model: AIModelConfig.openAIFullModelID)
        case .magnolia:
            return AIModelConfig(provider: .anthropic, model: AIModelConfig.anthropicSonnet46ModelID)
        }
    }
}
