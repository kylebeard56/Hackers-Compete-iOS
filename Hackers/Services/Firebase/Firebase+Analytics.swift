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
    
    /// Games
    case cardFlipped = "card_flipped"
    
    /// Cards of Chaos
    case chaosRulesTapped = "chaos_rules_tapped"
    case playChaosTapped = "play_chaos_tapped"
    case revealCardsTapped = "reveal_cards_tapped"
    case discardChaosTapped = "discard_chaos_tapped"
    case chaosArrangementChanged = "chaos_arrangement_changed"
    case chaosDifficultyChanged = "chaos_difficulty_changed"
    case chaosRedrawsChanged = "chaos_redraws_changed"
    case chaosRedrawsMixed = "chaos_redraws_mixed"
    case chaosRedrawsMixIncremented = "chaos_redraw_mix_incremented"
    case chaosRedrawsMixDecremented = "chaos_redraw_mix_decremented"
    case chaosRedrawsCleared = "chaos_redraws_cleared"
    
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
    case exitToHome = "exit_to_home_tapped"
    
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
