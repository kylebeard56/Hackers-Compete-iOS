//
//  RoundSession+Tips.swift
//  Hackers
//
//  Created by Kyle Beard on 7/4/24.
//

import Foundation
import SwiftUI

extension RoundSession {
    
    func showNextTipIfAvailable() {
        activeTip = tips
            .sorted(by: { $0.priority < $1.priority })
            .first(where: \.isReady)
    }
    
    func onTipClose() {
        print(#function)
        
        withAnimation {
            if let i = tips.firstIndex(where: { $0.data.id == activeTip?.data.id }) {
                tips[i].canBeShown = false
                self.activeTip = nil
                // TODO: We need the user to go through the entire tutorial and then set a boolean
            } else {
                print("[TIPS] error: cannot close tip")
            }
        }
    }

    func onTipNext() {
        withAnimation {
            if let i = tips.firstIndex(where: { $0.data.id == activeTip?.data.id }) {
                tips[i].canBeShown = false
                showNextTipIfAvailable()
            } else {
                print("[TIPS] error: cannot go to next tip")
            }
        }
    }
}
