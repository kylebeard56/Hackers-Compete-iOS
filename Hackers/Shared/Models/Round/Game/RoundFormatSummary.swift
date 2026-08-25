//
//  RoundFormatSummary.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Foundation

/// Lightweight display-only model on the round root.
/// Always derived from the active GameTemplate -- never independently mutated.
/// Used by round list views, share cards, and other contexts that don't need the full template.
struct RoundFormatSummary: Codable, Hashable {
    var templateID: String
    var name: String
    var icon: String
    var category: TemplateCategory

    init(
        templateID: String = "",
        name: String = "Stroke Play",
        icon: String = "f450",
        category: TemplateCategory = .stroke
    ) {
        self.templateID = templateID
        self.name = name
        self.icon = icon
        self.category = category
    }

    enum CodingKeys: String, CodingKey {
        case templateID = "template_id"
        case name, icon, category
    }
}

extension RoundFormatSummary {
    /// Derive a summary from a GameTemplate.
    init(from template: GameTemplate) {
        self.templateID = template.id
        self.name = template.name
        self.icon = template.icon
        self.category = template.category
    }
}
