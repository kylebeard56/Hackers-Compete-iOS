//
//  DashboardRoundHistoryView.swift
//  Hackers
//
//  Round history tab content for Dashboard.
//

import SwiftUI

struct DashboardRoundHistoryView: View {
    @ObservedObject var viewModel: DashboardViewModel

    let palette: DesignPalette
    let sortedRounds: [Round]
    let onRoundTap: (Round) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Round history")
                .fontStyle(kFontName, size: 24, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .alignLeading()

            SearchBar(
                placeholder: "Search rounds...",
                initialValue: viewModel.roundsSearchText,
                theme: .glass,
                onDebounce: { text in
                    viewModel.roundsSearchText = text
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredRounds(from: sortedRounds), id: \.self) { round in
                        Button {
                            Haptics.fire(.light)
                            onRoundTap(round)
                        } label: {
                            DashboardRoundTile(
                                round: round,
                                palette: palette,
                                currentPlayerID: viewModel.currentPlayerID
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    //.padding(.top, 8)
                }
                .padding(.bottom, 140)
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppSession.forPreview())
        .environmentObject(RoundSession())
}
