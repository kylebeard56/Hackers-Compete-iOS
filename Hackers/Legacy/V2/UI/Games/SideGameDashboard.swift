//
//  SideGameDashboard.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/24.
//

import SwiftUI

let kGameRaceConditionDelay: CGFloat = 0.1

fileprivate struct GameTag: Identifiable {
    var id = UUID()
    var label: String
    var caption: String
    var games: [SideGame]
    
    init(
        id: UUID = UUID(),
        label: String = "",
        caption: String = "",
        games: [SideGame] = []
    ) {
        self.id = id
        self.label = label
        self.caption = caption
        self.games = games
    }
}

struct SideGameDashboard: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    @State private var searchText = ""
    @FocusState var searchFocus: Bool
    
    @State private var selectedTag: String = "All games"
    @State private var selectedGame: SideGame = .none

    private var gameTags: [GameTag] {
        [
            GameTag(
                label: "All games",
                games: SideGame.allGames
            ),
            GameTag(
                label: "Groups of \(roundSession.players.count)",
                games: SideGame.allGames.filter({ $0.players.contains(roundSession.players.count) })
            ),
            GameTag(
                label: "Individual",
                games: SideGame.individualGames
            ),
            GameTag(
                label: "Team",
                games: SideGame.teamGames
            ),
            GameTag(
                label: "Made by Hackers",
                games: SideGame.madeByHackers
            ),
            GameTag(
                label: "Competitive",
                games: SideGame.competitiveGames
            ),
            GameTag(
                label: "Easy going",
                games: SideGame.relaxedGames
            ),
            GameTag(
                label: "Betting",
                games: SideGame.bettingGames
            ),
            GameTag(
                label: "For amateurs",
                games: SideGame.amateurGames
            )
        ]
    }
    
    var onSelection: ((SideGame) -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("Games")
                    .font(.dmSans, size: 32, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                
                Text("Fun scoring formats and playful challenges")
                    .font(.dmSans, size: 15, weight: .medium)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundColor(Color.systemGray)
                    .alignLeading()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            searchBar
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            
            if searchText.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Spacer(minLength: 0).frame(width: 10)
                        ForEach(gameTags, id: \.id) { tag in
                            chip(for: tag)
                        }
                        Spacer(minLength: 0).frame(width: 10)
                    }
                }
                .padding(.bottom, 10)
            }
            
            LazyVStack(spacing: 0) {
                let pc = roundSession.players.count
                
                if searchText.isEmpty {
                    /// Chips are filtering games
                    if let tag = gameTags.first(where: { $0.label == selectedTag }) {
                        let filterGames = SideGame.allCases
                            .filter({ tag.games.contains($0) })
                            .filter({ !$0.underConstruction }) // 2.2.0 to show website CTA
                            .sorted(by: { $0.name < $1.name })
                            .sorted(by: { $0.players.contains(pc) && !$1.players.contains(pc) })
                            //.sorted(by: { !$0.underConstruction && $1.underConstruction })
                            .sorted(by: { $0.priority && !$1.priority })
                        
                        ForEach(filterGames, id: \.name) { game in
                            gameTile(for: game)
                        }
                    }
                } else {
                    /// User is searching games
                    let searchGames = SideGame.allCases
                        .filter({ $0.name.lowercased().contains(searchText.lowercased()) })
                        .filter({ !$0.underConstruction }) // 2.2.0 to show website CTA
                        .sorted(by: { $0.name < $1.name })
                        .sorted(by: { $0.players.contains(pc) && !$1.players.contains(pc) })
                        //.sorted(by: { !$0.underConstruction && $1.underConstruction })
                        .sorted(by: { $0.priority && !$1.priority })
                    
                    if searchGames.isEmpty {
                        Text("No games found")
                            .font(.dmSans, size: 15, weight: .medium)
                            .foregroundColor(Color.systemGray3)
                            .alignCenter()
                    } else {
                        ForEach(searchGames, id: \.name) { game in
                            gameTile(for: game)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            WebsiteGameBanner()
                .padding(.top, 10)
                .padding(.horizontal, 20)
            
        }
        .onChange(of: searchFocus, perform: { focus in
            sendOnFocusChange(focus)
            if focus { Haptics.fire(.light) }
        })
        .onChange(of: searchText, perform: { text in
            /// Deselect game if user searches and query doesn't return selected game
            let g = SideGame.allCases.filter({ $0.name.lowercased().contains(selectedGame.name.lowercased()) })
            if !text.isEmpty && g.isEmpty {
                selectedGame = .none
            }
        })
    }
    
    @ViewBuilder private func gameTile(for game: SideGame) -> some View {
        SideGameTile(
            game: game,
            isSelected: selectedGame == game,
            canPlay: game.players.contains(roundSession.players.filter({ $0.isPlaying }).count),
            //isAlreadySampled: roundSession.isGameSampled(game),
            showTag: true,
            showImage: selectedTag == "All games"
        )
        .onTap {
            let untoggle = selectedGame == game
            selectedGame = untoggle ? .none : game
            sendOnSelection(selectedGame)
        }
        .id(game.name)
        .padding(.horizontal, 20)
        .padding(.top, 10) // Used here for the scroll proxy
    }
    
    // MARK: - Search Bar
    
    @ViewBuilder private var searchBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                Icon(name: "magnifyingglass", size: 20, maxSize: 20, weight: .regular)
                    .foregroundStyle(Color.systemGray3)
                
                TextField("Search games", text: $searchText)
                    .font(.dmSans, size: 17, weight: .regular)
                    .foregroundStyle(Color.systemBlack)
                    .focused($searchFocus)
                
                Spacer(minLength: 0)
                
                if searchFocus && !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        selectedGame = .none
                        Haptics.fire(.light)
                    }) {
                        Icon(name: "multiply.circle.fill", size: 13, weight: .solid)
                            .foregroundStyle(Color.systemGray3)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(colorScheme.superlightGray)
            .cornerRadius(10)
            
            if searchFocus {
                Button(action: {
                    searchText = ""
                    UIApplication.shared.endEditing()
                    Haptics.fire(.light)
                }) {
                    Text("Cancel")
                        .font(.dmSans, size: 15, weight: .medium)
                        .foregroundStyle(Color.systemBlack)
                        .padding(.leading, 10)
                }
            }
        }
    }
    
    // MARK: - Chips
    
    @ViewBuilder private func chip(for tag: GameTag) -> some View {
        let isSet: Bool = tag.label == selectedTag
        Button(action: {
            withAnimation {
                selectedTag = tag.label
            }
            Haptics.fire(.light)
        }) {
            ChipButton(
                style: .solid,
                text: tag.label,
                foregroundColor: isSet ? Color.white : Color.systemBlack,
                backgroundColor: isSet ? Color.systemHackersPurple : colorScheme.superlightGray
            )
        }

    }
}

extension SideGameDashboard {
    func sendOnSelection(_ object: SideGame) {
        if let action = onSelection {
            action(object)
        }
    }
    
    func onSelection(perform action: @escaping (SideGame) -> Void) -> Self {
        var a = self
        a.onSelection = action
        return a
    }
    
    func sendOnFocusChange(_ value: Bool) {
        if let action = onFocusChange {
            action(value)
        }
    }
    
    func onFocusChange(perform action: @escaping (Bool) -> Void) -> Self {
        var a = self
        a.onFocusChange = action
        return a
    }
}

struct SideGameDashboard_Previews: PreviewProvider {
    static var round: RoundSession {
        let r = RoundSession()
        r.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
        return r
    }
    
    static var previews: some View {
        ScrollView {
            SideGameDashboard()
        }
        .padding(.vertical, 20)
        .environmentObject(round)
        .holisticPreview()
    }
}
