//
//  RoundExpirationView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/7/23.
//

import SwiftUI

struct RoundExpirationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSessionV2
    
    var body: some View {
        Group {
            if let date = appSession.session?.createdAt.iso.dateFromISO8601 {
                InfoCard(
                    title: "This round expires \(date.addingTimeInterval(86400).relativeTimeAgo).",
                    subtitle: "Afterwards, your round will be archived and party codes will be recycled and available for other groups to set and use."
                )
            }
        }
        .environmentObject(appSession)
    }
}

struct RoundExpirationView_Previews: PreviewProvider {
    static var appSession = AppSessionV2()
    static var previews: some View {
        RoundExpirationView()
            .environmentObject(appSession)
            .onAppear() {
                appSession.session = Session()
            }
            .holisticPreview()
    }
}
