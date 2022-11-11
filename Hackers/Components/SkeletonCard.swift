//
//  SkeletonCard.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import SkeletonUI
import SwiftUI

struct SkeletonCard: View {
    @Environment(\.colorScheme) var colorScheme
    
    let animation: AnimationType = .pulse()
    var appearance: AppearanceType {
        .solid(color: colorScheme == .light ? .systemGray4 : .systemGray4, background: .systemGray6)
    }
    
    var body: some View {
        VStack(spacing: kPadding) {
            Circle()
                .skeleton(with: true)
                .shape(type: .circle)
                .appearance(type: appearance)
                .animation(type: animation)
                .frame(height: 70)
            
            Rectangle()
                .skeleton(with: true)
                .shape(type: .rounded(.radius(4, style: .continuous)))
                .appearance(type: appearance)
                .animation(type: animation)
                .frame(height: 30)
                .alignLeading()
            
            Rectangle()
                .skeleton(with: true)
                .shape(type: .rounded(.radius(4, style: .continuous)))
                .appearance(type: appearance)
                .animation(type: animation)
                .frame(height: 17)
                .alignLeading()
                .padding(.top, 8)
                .padding(.bottom, -8)
            
            Rectangle()
                .skeleton(with: true)
                .shape(type: .rounded(.radius(4, style: .continuous)))
                .appearance(type: appearance)
                .animation(type: animation)
                .frame(width: 200, height: 17)
                .alignCenter()
        }
        .padding(kPadding)
        .background(Color.systemMarquee)
        .border(Color.systemGray4, width: 2, cornerRadius: 12)
        .cornerRadius(12)
    }
}

struct SkeletonCard_Previews: PreviewProvider {
    static var previews: some View {
        SkeletonCard()
            .padding(kPadding)
            .alignMiddle()
            .background(Color.systemViewBackground)
    }
}
