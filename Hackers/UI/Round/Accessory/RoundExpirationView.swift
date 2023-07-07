//
//  RoundExpirationView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/7/23.
//

import SwiftUI

struct RoundExpirationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    
    var body: some View {
        VStack(spacing: 10) {
            if let date = appSession.session?.createdAt.iso.dateFromISO8601 {
                Text("This round expires \(date.addingTimeInterval(86400).relativeTimeAgo).")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                
                Text("Afterwards, your round will be archived and party codes will be recycled and available for other groups to set and use.")
                    .font(.dmSans(size: 15, weight: .regular))
                    .foregroundColor(Color.systemGray)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
            }
        }
        .environmentObject(appSession)
        .padding(20)
        .alignTop()
    }
}

struct RoundExpirationView_Previews: PreviewProvider {
    static var appSession = AppSession()
    static var previews: some View {
        RoundExpirationView()
            .environmentObject(appSession)
            .onAppear() {
                appSession.session = Session()
            }
            .holisticPreview()
    }
}
