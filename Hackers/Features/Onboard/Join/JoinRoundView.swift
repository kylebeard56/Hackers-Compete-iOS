//
//  JoinRoundView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/28/25.
//

import SwiftUI

struct JoinRoundView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject var viewModel: JoinRoundViewModel
    
    @State private var showPlayerSelector = false
    
    var courseSegment: CourseSegment? { viewModel.round?.configuration.courses.first }
    var holes: Int { courseSegment?.holeRange.count ?? 0 }
    var courseName: String { courseSegment?.courseInfo.name ?? "Unknown" }
    
//    var hostName: String { viewModel.participants.first(where: \.isHost)?.name.givenName ?? "player" }
    
    var body: some View {
        VStack(spacing: 16) {
            NavButton(icon: "f053", onTap: { dismiss() })
                .alignLeading()
            
            VStack(spacing: 8) {
                Text("Join \(viewModel.hostName.possessive) round?")
                    .fontStyle(.poppins, size: 24, weight: .semibold)
                    .foregroundStyle(Color.systemBlack)
                    .alignLeading()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                Text("Select or confirm your player for this round:")
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(Color.hackersGray)
                    .alignLeading()
            }

            playerSelectionDropdown
            
            //            Text("Playing \(holes) hole\(holes.pluralized) at \(courseName).")
            //                .fontStyle(.poppins, size: 15, weight: .medium)
            //                .foregroundStyle(Color.hackersGray)
            //                .alignLeading()
            
            Spacer(minLength: 0)
            
            PrimaryButton(
                appearance: .fill,
                title: "Join this round",
                labelColor: .white,
                buttonColor: .black,
                iconSize: 24,
                isDisabled: .constant(viewModel.claimedParticipant == nil),
                isLoading: .false,
                onTap: {
                    print("todo: update this round with participant and then go")
                }
            )
        }
        .padding(16)
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showPlayerSelector) {
            ClaimPlayerView(viewModel: viewModel)
        }
    }
    
    private var playerSelectionDropdown: some View {
        Button(action: {
            Haptics.fire(.light)
            showPlayerSelector = true
        }) {
            HStack {
                if let participant = viewModel.claimedParticipant {
                    Text(participant.name.fullName)
                        .fontStyle(.poppins, size: 15, weight: .regular)
                        .foregroundStyle(Color.systemBlack)
                } else {
                    Text("Select your player")
                        .fontStyle(.poppins, size: 15, weight: .regular)
                        .foregroundStyle(Color.hackersGray)
                }

                Spacer()
                
                Icon(name: "f078", size: 12, weight: .solid)
                    .foregroundStyle(Color.hackersGray3)
            }
            .padding(16)
            .border(Color.hackersGray5, width: 1.5, cornerRadius: 10)
        }
    }
}

#Preview {
    JoinRoundView(viewModel: JoinRoundViewModel())
}
