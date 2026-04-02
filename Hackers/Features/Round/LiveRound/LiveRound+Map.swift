//
//  LiveRound+Map.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import MapKit
import SwiftUI

// MARK: - Map Content

extension LiveRound {
    var mapContent: some View {
        // Ideas: Have users enter their stock yardage per club. Then you have Bushnell-like map where you can tap
        // and drag waypoints and along the straight line, you can see distance, suggested club with power so you
        // can decide whether you're driver-wedge, 5i-8i, 6i-6i etc to balance what's best and strategize the hole.
        // The user has to be the one to know where the are on the map.
        VStack(spacing: 16) {
            navPadding
            
            Map(
                position: $mapCameraPosition,
                interactionModes: .all
            )
            .mapStyle(.imagery(elevation: .realistic))
            .cornerRadius(radius: 12)
            .padding(12)
            .glassCardEffect(cornerRadius: 24, forceMaterial: true)
            //.frame(height: UIScreen.main.bounds.height * 0.6)
            .padding(.horizontal, 16)
            
            Text("Hole distance, shot planning, and cart locations soon")
                .fontStyle(kFontName, size: 15, weight: .medium)
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
                .alignCenter()
                .glassCardEffect(cornerRadius: 24, forceMaterial: true)
                .padding(.horizontal, 16)
                
            
            //Spacer(minLength: 0)
            
            Padding(.vertical, 120)
        }
    }
}
