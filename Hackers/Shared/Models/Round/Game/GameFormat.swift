//
//  GameFormat.swift
//  Hackers
//
//  Created by Kyle Beard on 9/2/25.
//

import Foundation

struct GameFormat: Hashable, Codable {
    var type: GameFormatType = .strokePlay
    var configuration: GameConfiguration = .init()
    
//    init(
//        type: GameFormatType = .strokePlay,
//        configuration: GameConfiguration = .init()
//    ) {
//        self.type = type
//        self.configuration = configuration
//    }
    
//    enum CodingKeys: String, CodingKey {
//        case type, configuration
//    }
}

extension GameFormat {
    static var strokePlay = GameFormat(type: .strokePlay, configuration: GameConfiguration.strokePlay)
    static var matchPlay = GameFormat(type: .matchPlay, configuration: GameConfiguration.matchPlay)
}

enum GameFormatType: String, CaseIterable, Codable {
    case strokePlay = "stroke_play"
    case matchPlay = "match_play"
    
    var displayName: String {
        switch self {
        case .strokePlay:       return "Stroke Play"
        case .matchPlay:        return "Match Play"
        }
    }
}


