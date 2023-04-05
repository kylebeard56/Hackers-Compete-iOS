//
//  Firebase+Analytics.swift
//  Hackers
//
//  Created by Kyle Beard on 3/13/23.
//

import FirebaseAnalytics
import Foundation

enum FirebaseEvent: String {
    /// Sharing
    case shareCodeCreated = "share_code_created"
    case shareCodeRedeemed = "share_code_redeemed"
    case shareCodeEdited = "share_code_edited"
    case shareCodeRemoved = "share_code_removed"
    
    /// Starting round
    case newRoundStarted = "new_round_started"
    case continueRoundStarted = "continue_round_started"
    case existingRoundedEndedForNewRound = "existing_round_ended_for_new_round"
    case existingRoundedEndedForJoinRound = "existing_round_ended_for_join_round"
    
    /// Guided tour
    case guidedTourSkipped = "guided_tour_skipped"
    case guidedTourFinished = "guided_tour_finished"
    
    /// Game home
    case howToPlayTapped = "how_to_play_tapped"
    case quickDrawTapped = "quick_draw_tapped"
    case revealCardsTapped = "reveal_cards_tapped"
    case modifyGameModeTapped = "modify_game_mode_tapped"
    case discardCardsTapped = "discard_cards_tapped"
    
    /// Game mode
    case teamRedrawsModified = "team_redraws_modified"
    case playerRedrawsModified = "player_redraws_modified"
    case teamDifficultyModified = "team_difficulty_modified"
    case playerDifficultyModified = "player_difficulty_modified"
    
    /// Card reveal
    case teamCardRedrawn = "team_card_redrawn"
    case playerCardRedrawn = "player_card_redrawn"
    
    /// Scoring
    case addScoreTapped = "add_score_tapped"
    case playerScoreEdited = "player_score_edited"
    case playerScoreSwiped = "player_score_swiped"
    case holeScoreEdited = "hole_score_edited"
    case holeScoreSwiped = "hole_score_swiped"
    case scoreSummaryTapped = "score_summary_tapped"
    case playerSummaryExpanded = "player_summary_expanded"
    
    /// Menu
    case menuTapped = "menu_tapped"
    case shareWithFriendsTapped = "share_with_friends_tapped"
    case endRoundTapped = "end_round_tapped"
    
    /// App
    case roundCompleteShown = "round_complete_shown"
}

extension FirebaseEvent {
    func log() {
        print("FirebaseEvent logging \(self.rawValue)")
        if adminMode { return }
        Analytics.logEvent(self.rawValue, parameters: nil)
    }
}
