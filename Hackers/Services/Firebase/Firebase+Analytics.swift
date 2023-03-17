//
//  Firebase+Analytics.swift
//  Hackers
//
//  Created by Kyle Beard on 3/13/23.
//

import FirebaseAnalytics
import Foundation

enum FirebaseEvent: String {
    case shareCodeCreated = "share_code_created"
    case shareCodeRedeemed = "share_code_redeemed"
    case shareCodeEdited = "share_code_edited"
    case shareCodeRemoved = "share_code_removed"
    case shareCodeCopied = "share_code_copied"
    case newRoundStarted = "new_round_started"
    case continueRoundStarted = "continue_round_started"
    case howToPlayTapped = "how_to_play_tapped"
    case designGameModeTapped = "design_game_mode_tapped"
    case gameRedrawsModified = "game_redraws_modified"
    case gameDifficultyModified = "game_difficulty_modified"
    case modifyGameModeTapped = "modify_game_mode_tapped"
    case revealCardsTapped = "reveal_cards_tapped"
    case teamCardRedrawn = "team_card_redrawn"
    case playerCardRedrawn = "player_card_redrawn"
    case discardCardsTapped = "discard_cards_tapped"
    case addScoreTapped = "add_score_tapped"
    case playerScoreEdited = "player_score_edited"
    case playerScoreSwiped = "player_score_swiped"
    case holeScoreEdited = "hole_score_edited"
    case holeScoreSwiped = "hole_score_swiped"
    case scoreSummaryTapped = "score_summary_tapped"
    case playerSummaryExpanded = "player_summary_expanded"
    case endRoundTapped = "end_round_tapped"
}

extension FirebaseService {
    
    func log(_ event: FirebaseEvent) {
        Analytics.logEvent(event.rawValue, parameters: nil)
    }
}
