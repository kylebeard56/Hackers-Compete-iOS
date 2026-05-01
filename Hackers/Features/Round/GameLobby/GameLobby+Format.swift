//
//  GameLobby+Format.swift
//  Hackers
//
//  Created by Kyle Beard on 12/4/25.
//

import SwiftUI

extension GameLobby {
    private var isVegasFormat: Bool { snapshot.isVegasFormat }

    @ViewBuilder
    var gameFormatSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 14) {
                Text("Game Format".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentGreen.opacity(colorScheme.translucent))
                            .frame(width: 120, height: 120)
                        Icon(name: snapshot.activeTemplate.icon, size: 48, weight: .regular)
                            .foregroundStyle(Color.accentGreen)
                            .padding(24)
                    }
                    .frame(width: 120, height: 120)
                    .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)

                    Text(snapshot.activeTemplate.name.uppercased())
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)

                    Text(snapshot.activeTemplate.description)
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .multilineTextAlignment(.center)
                }

                competitionScopeBlock

                if snapshot.isSharedScoreSource {
                    scoreEntryScopeBlock
                }

                if shouldShowSharedScoreAllowanceBlock {
                    sharedScoreAllowanceBlock
                }

                if snapshot.configuration.resolvedCompetitionScope == .matchup && !isVegasFormat {
                    matchupScoringBlock
                }

                if isVegasFormat {
                    vegasConfigurationBlock
                } else if snapshot.requiresTeams && !snapshot.isSharedScoreSource {
                    teamScoringBuilderBlock
                } else if snapshot.requiresTeams && snapshot.isSharedScoreSource {
                    Text("Best 1 round totals count toward the team score.")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                        .padding(.top, 2)
                }

                if snapshot.isSharedScoreSource {
                    surpriseScoringBlock
                }

                Button {
                    Haptics.fire(.light)
                    showFormatSelectionView = true
                } label: {
                    Text("Change format")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                        .whiteGlassCardShadow(color: palette.shadowColor)
                }
                .padding(.top, 16)
            }
            .padding(16)
            .glassCardEffect(forceMaterial: true, tint: palette.cardColor)
        }
    }

    private var surpriseScoringBlock: some View {
        configBuilderRow(
            title: "Surprise scoring",
            subtitle: "Scores kept secret until the end"
        ) {
            Toggle("", isOn: $secretScoringEnabled)
                .labelsHidden()
                .tint(.accentGreen)
                .onChange(of: secretScoringEnabled) {
                    Task { await roundSession.setSecretScoring(secretScoringEnabled) }
                }
        }
    }

    private var competitionScopeBlock: some View {
        configBuilderRow(
            title: "Competition",
            subtitle: "Choose a full-field leaderboard or head-to-head matchups."
        ) {
            if isVegasFormat {
                formatChipLabel("Field")
            } else {
                Menu {
                    Button {
                        Haptics.fire(.light)
                        if playerTab == .matchups {
                            playerTab = .roster
                        }
                        Task { await roundSession.setCompetitionScope(.field) }
                    } label: {
                        HStack {
                            Text("Field")
                            if snapshot.configuration.resolvedCompetitionScope == .field {
                                Icon(name: "f00c", size: 12, weight: .solid)
                            }
                        }
                    }

                    Button {
                        Haptics.fire(.light)
                        Task { await roundSession.setCompetitionScope(.matchup) }
                    } label: {
                        HStack {
                            Text("Matchup")
                            if snapshot.configuration.resolvedCompetitionScope == .matchup {
                                Icon(name: "f00c", size: 12, weight: .solid)
                            }
                        }
                    }
                } label: {
                    formatChipLabel(competitionScopeTitle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scoreEntryScopeBlock: some View {
        configBuilderRow(
            title: "Score entry",
            subtitle: scoreEntryScopeSubtitle
        ) {
            if isVegasFormat {
                formatChipLabel("Individual")
            } else {
                Menu {
                    ForEach(RoundScoreOwnerScope.allCases, id: \.self) { scope in
                        Button {
                            Haptics.fire(.light)
                            Task { await roundSession.setScoreOwnerScope(scope) }
                        } label: {
                            HStack {
                                Text(scoreOwnerScopeTitle(for: scope))
                                if snapshot.configuration.scoreOwnerScope == scope {
                                    Icon(name: "f00c", size: 12, weight: .solid)
                                }
                            }
                        }
                    }
                } label: {
                    formatChipLabel(scoreEntryScopeTitle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shouldShowSharedScoreAllowanceBlock: Bool {
        guard handicapsEnabled, snapshot.isSharedScoreSource else { return false }
        return snapshot.configuration.scoreOwnerScope == .partnership || snapshot.requiresTeams
    }

    private var sharedScoreAllowanceBlock: some View {
        configBuilderRow(
            title: "Pair handicap",
            subtitle: "Apply ranked handicap percentages to each shared score."
        ) {
            HStack(spacing: 8) {
                TextField("35,15", text: $sharedScoreAllowanceText)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(Color.charcoal)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                    .whiteGlassCardShadow(color: palette.shadowColor)
                    .submitLabel(.done)
                    .onSubmit { saveSharedScoreAllowance() }

                Button {
                    Haptics.fire(.light)
                    saveSharedScoreAllowance()
                } label: {
                    Icon(name: "f00c", size: 13, weight: .solid)
                        .foregroundStyle(palette.foregroundColor)
                        .frame(width: 34, height: 34)
                        .glassCardEffect(shape: .circle, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                        .whiteGlassCardShadow(color: palette.shadowColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var vegasConfigurationBlock: some View {
        VStack(spacing: 10) {
            configBuilderRow(
                title: "Oversized teams",
                subtitle: "Choose how Vegas resolves teams with more than two players."
            ) {
                Menu {
                    ForEach(RoundVegasMode.allCases, id: \.self) { mode in
                        Button {
                            Haptics.fire(.light)
                            Task { await roundSession.setVegasMode(mode) }
                        } label: {
                            HStack {
                                Text(vegasModeTitle(for: mode))
                                if snapshot.configuration.resolvedVegasMode == mode {
                                    Icon(name: "f00c", size: 12, weight: .solid)
                                }
                            }
                        }
                    }
                } label: {
                    formatChipLabel(vegasModeTitle(for: snapshot.configuration.resolvedVegasMode))
                }
                .buttonStyle(.plain)
            }

            if snapshot.configuration.resolvedVegasMode == .selectedPair {
                configBuilderRow(
                    title: "Pick two scores",
                    subtitle: "Choose which two player scores form the Vegas number."
                ) {
                    Menu {
                        ForEach(RoundVegasSelectionRule.allCases, id: \.self) { rule in
                            Button {
                                Haptics.fire(.light)
                                Task { await roundSession.setVegasSelectionRule(rule) }
                            } label: {
                                HStack {
                                    Text(vegasSelectionRuleTitle(for: rule))
                                    if snapshot.configuration.resolvedVegasSelectionRule == rule {
                                        Icon(name: "f00c", size: 12, weight: .solid)
                                    }
                                }
                            }
                        }
                    } label: {
                        formatChipLabel(vegasSelectionRuleTitle(for: snapshot.configuration.resolvedVegasSelectionRule))
                    }
                    .buttonStyle(.plain)
                }

                configBuilderRow(
                    title: "Pick by",
                    subtitle: "Select two scores on each hole or based on full-round totals."
                ) {
                    Menu {
                        ForEach(AggregationScope.allCases, id: \.self) { scope in
                            Button {
                                Haptics.fire(.light)
                                Task { await roundSession.setVegasSelectionScope(scope) }
                            } label: {
                                HStack {
                                    Text(scope == .perRound ? "Per round" : "Per hole")
                                    if snapshot.configuration.resolvedVegasSelectionScope == scope {
                                        Icon(name: "f00c", size: 12, weight: .solid)
                                    }
                                }
                            }
                        }
                    } label: {
                        formatChipLabel(snapshot.configuration.resolvedVegasSelectionScope == .perRound ? "Per round" : "Per hole")
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(vegasConfigurationSummaryText)
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
                .alignLeading()
                .padding(.top, 2)
        }
    }

    private var matchupScoringBlock: some View {
        VStack(spacing: 10) {
            configBuilderRow(
                title: "Matchup scoring",
                subtitle: "Compare one winner for the full round or award points hole-by-hole."
            ) {
                Menu {
                    ForEach(RoundMatchupScoringStyle.allCases, id: \.self) { style in
                        Button {
                            Haptics.fire(.light)
                            Task { await roundSession.setMatchupScoringStyle(style) }
                        } label: {
                            HStack {
                                Text(matchupScoringStyleTitle(for: style))
                                if snapshot.configuration.matchupScoringStyle == style {
                                    Icon(name: "f00c", size: 12, weight: .solid)
                                }
                            }
                        }
                    }
                } label: {
                    formatChipLabel(matchupScoringStyleTitle)
                }
                .buttonStyle(.plain)
            }

            if snapshot.configuration.matchupScoringStyle == .holeByHolePoints {
                configBuilderRow(
                    title: "Hole value",
                    subtitle: "Points awarded when one side wins the hole."
                ) {
                    Menu {
                        ForEach([0.5, 1, 2, 3], id: \.self) { value in
                            Button {
                                Haptics.fire(.light)
                                Task { await roundSession.setHoleWinPoints(value) }
                            } label: {
                                HStack {
                                    Text(scorePointLabel(value))
                                    if snapshot.configuration.resolvedHoleWinPoints == value {
                                        Icon(name: "f00c", size: 12, weight: .solid)
                                    }
                                }
                            }
                        }
                    } label: {
                        formatChipLabel(scorePointLabel(snapshot.configuration.resolvedHoleWinPoints))
                    }
                    .buttonStyle(.plain)
                }

                configBuilderRow(
                    title: "Winner bonus",
                    subtitle: "Extra points awarded only when there is a unique match winner."
                ) {
                    Menu {
                        ForEach([0.0, 1, 2, 3, 4], id: \.self) { value in
                            Button {
                                Haptics.fire(.light)
                                Task { await roundSession.setMatchWinnerBonusPoints(value) }
                            } label: {
                                HStack {
                                    Text(scorePointLabel(value))
                                    if snapshot.configuration.resolvedMatchWinnerBonusPoints == value {
                                        Icon(name: "f00c", size: 12, weight: .solid)
                                    }
                                }
                            }
                        }
                    } label: {
                        formatChipLabel(scorePointLabel(snapshot.configuration.resolvedMatchWinnerBonusPoints))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var teamScoringBuilderBlock: some View {
        VStack(spacing: 10) {
            configBuilderRow(
                title: "Count scores",
                subtitle: "Choose which scores count and how they're computed for leaderboard."
            ) {
                if snapshot.configuration.teamScoring.mode == .all {
                    Menu {
                        countScoresButtons
                    } label: {
                        formatChipLabel(teamScoringModeTitle, minWidth: 68)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 8) {
                            Menu {
                                countScoresButtons
                            } label: {
                                formatChipLabel(teamScoringModeTitle, minWidth: 110)
                            }
                            .buttonStyle(.plain)

                            Text("per")
                                .fontStyle(kFontName, size: 15, weight: .regular)
                                .foregroundStyle(Color.neutral)

                            Menu {
                                ForEach(AggregationScope.allCases, id: \.self) { scope in
                                    Button {
                                        Haptics.fire(.light)
                                        Task { await roundSession.setTeamScoringScope(scope) }
                                    } label: {
                                        HStack {
                                            Text(scope == .perRound ? "Round" : "Hole")
                                            if snapshot.configuration.teamScoring.scope == scope {
                                                Icon(name: "f00c", size: 12, weight: .solid)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                formatChipLabel(teamScoringScopeTitle, minWidth: 76)
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 8) {
                            Text("from")
                                .fontStyle(kFontName, size: 15, weight: .regular)
                                .foregroundStyle(Color.neutral)

                            Menu {
                                Button {
                                    Haptics.fire(.light)
                                    Task { await roundSession.setSelectionDomain(nil) }
                                } label: {
                                    HStack {
                                        Text("Auto")
                                        if snapshot.configuration.selectionDomain == nil {
                                            Icon(name: "f00c", size: 12, weight: .solid)
                                        }
                                    }
                                }
                                ForEach(ScoringSelectionDomain.allCases, id: \.self) { domain in
                                    Button {
                                        Haptics.fire(.light)
                                        Task { await roundSession.setSelectionDomain(domain) }
                                    } label: {
                                        HStack {
                                            Text(selectionDomainTitle(for: domain))
                                            if snapshot.configuration.selectionDomain == domain {
                                                Icon(name: "f00c", size: 12, weight: .solid)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                formatChipLabel(selectionDomainShortTitle, minWidth: 104)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(minWidth: 136, alignment: .trailing)
                }
            }

            if let summary = teamScoringSummaryText {
                Text(summary)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private var countScoresButtons: some View {
        Button {
            Haptics.fire(.light)
            Task { await roundSession.setTeamScoringMode(.all) }
        } label: {
            HStack {
                Text("All scores")
                if snapshot.configuration.teamScoring.mode == .all {
                    Icon(name: "f00c", size: 12, weight: .solid)
                }
            }
        }

        Divider()

        ForEach(1...4, id: \.self) { count in
            Button {
                Haptics.fire(.light)
                Task {
                    await roundSession.setTeamScoringMode(.bestN)
                    await roundSession.setTeamScoringCount(count)
                }
            } label: {
                HStack {
                    Text("Best \(count)")
                    if snapshot.configuration.teamScoring.mode == .bestN,
                       snapshot.configuration.teamScoring.count == count {
                        Icon(name: "f00c", size: 12, weight: .solid)
                    }
                }
            }
        }

        Divider()

        ForEach(1...4, id: \.self) { count in
            Button {
                Haptics.fire(.light)
                Task {
                    await roundSession.setTeamScoringMode(.worstN)
                    await roundSession.setTeamScoringCount(count)
                }
            } label: {
                HStack {
                    Text("Worst \(count)")
                    if snapshot.configuration.teamScoring.mode == .worstN,
                       snapshot.configuration.teamScoring.count == count {
                        Icon(name: "f00c", size: 12, weight: .solid)
                    }
                }
            }
        }
    }

    private func configBuilderRow<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                Text(subtitle)
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
            }

            Spacer(minLength: 0)

            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.borderColor, lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.neutral6.opacity(0.3)))
        )
    }

    private func formatChipLabel(_ title: String, minWidth: CGFloat? = nil) -> some View {
        Text(title)
            .fontStyle(kFontName, size: 14, weight: .semibold)
            .foregroundStyle(Color.charcoal)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(minWidth: minWidth)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
            .whiteGlassCardShadow(color: palette.shadowColor)
    }

    private var competitionScopeTitle: String {
        snapshot.configuration.resolvedCompetitionScope == .matchup ? "Matchup" : "Field"
    }

    private var scoreEntryScopeTitle: String {
        scoreOwnerScopeTitle(for: snapshot.configuration.scoreOwnerScope)
    }

    private var scoreEntryScopeSubtitle: String {
        snapshot.isSharedScoreSource && snapshot.requiresTeams
            ? "Choose whether one shared score is entered by team, partnership, or tee group."
            : "Choose whether scores are entered by player, partnership, or the whole tee group."
    }

    private func scoreOwnerScopeTitle(for scope: RoundScoreOwnerScope) -> String {
        switch scope {
        case .individual:
            return snapshot.isSharedScoreSource && snapshot.requiresTeams ? "Team" : "Individual"
        case .partnership:
            return "Partnership"
        case .teeGroup:
            return "Tee group"
        }
    }

    private var matchupScoringStyleTitle: String {
        matchupScoringStyleTitle(for: snapshot.configuration.matchupScoringStyle)
    }

    private func matchupScoringStyleTitle(for style: RoundMatchupScoringStyle) -> String {
        switch style {
        case .aggregateRoundTotal:
            return "Round winner"
        case .holeByHolePoints:
            return "Hole points"
        }
    }

    private func scorePointLabel(_ value: Double) -> String {
        value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
    }

    private var teamScoringModeTitle: String {
        let scoring = snapshot.configuration.teamScoring
        switch scoring.mode {
        case .all:
            return "All"
        case .bestN:
            return "Best \(scoring.count)"
        case .worstN:
            return "Worst \(scoring.count)"
        }
    }

    private var teamScoringScopeTitle: String {
        snapshot.configuration.teamScoring.scope == .perRound ? "Round" : "Hole"
    }

    private var teamScoringSummaryText: String? {
        let scoring = snapshot.configuration.teamScoring
        guard scoring.mode != .all else {
            return "Every player score contributes to the team result."
        }

        let qualifier = scoring.mode == .worstN ? "Worst" : "Best"
        let scope = scoring.scope == .perRound ? "round totals" : "scores on each hole"
        return "\(qualifier) \(scoring.count) \(scope) from \(resolvedSelectionDomainSummary) count toward the score."
    }

    private var selectionDomainChipTitle: String {
        guard let domain = snapshot.configuration.selectionDomain else { return "From auto" }
        switch domain {
        case .participant:
            return "From each player"
        case .team:
            return "From each team"
        case .partnership:
            return "From each pair"
        case .teeGroup:
            return "From each tee group"
        }
    }

    private var selectionDomainShortTitle: String {
        guard let domain = snapshot.configuration.selectionDomain else { return "Auto" }
        return selectionDomainTitle(for: domain)
    }

    private var resolvedSelectionDomainSummary: String {
        switch resolvedSelectionDomain {
        case .participant:
            return "each player"
        case .team:
            return "each team"
        case .partnership:
            return "each pair"
        case .teeGroup:
            return "each tee group"
        }
    }

    private var resolvedSelectionDomain: ScoringSelectionDomain {
        ScoringEngine.resolvedSelectionDomain(
            explicit: snapshot.configuration.selectionDomain,
            matchups: snapshot.roundSegment?.matchups ?? [],
            scoringGroups: snapshot.scoringGroups,
            scoreOwnerScope: snapshot.configuration.scoreOwnerScope,
            teamScoring: snapshot.configuration.teamScoring,
            template: snapshot.resolvedActiveTemplate,
            teams: snapshot.teams
        )
    }

    private func selectionDomainTitle(for domain: ScoringSelectionDomain) -> String {
        switch domain {
        case .participant:
            return "Player"
        case .team:
            return "Team"
        case .partnership:
            return "Pair"
        case .teeGroup:
            return "Tee group"
        }
    }

    private func vegasModeTitle(for mode: RoundVegasMode) -> String {
        switch mode {
        case .exactPair:
            return "Require twosomes"
        case .partnershipAggregate:
            return "Use partnerships"
        case .selectedPair:
            return "Pick two scores"
        }
    }

    private func vegasSelectionRuleTitle(for rule: RoundVegasSelectionRule) -> String {
        switch rule {
        case .best2:
            return "Best 2"
        case .worst2:
            return "Worst 2"
        case .bestAndWorst:
            return "Best + Worst"
        }
    }

    private var vegasConfigurationSummaryText: String {
        switch snapshot.configuration.resolvedVegasMode {
        case .exactPair:
            return "Every team must be exactly two players. Larger teams need to be split up before the round can start."
        case .partnershipAggregate:
            return "Saved partnerships inside each team each produce a Vegas number, and those pair totals are summed for the team."
        case .selectedPair:
            let rule = vegasSelectionRuleTitle(for: snapshot.configuration.resolvedVegasSelectionRule)
            let scope = snapshot.configuration.resolvedVegasSelectionScope == .perRound ? "per round" : "per hole"
            return "\(rule) scores are chosen \(scope), then ordered low-to-high to form the team's Vegas number."
        }
    }

    private func saveSharedScoreAllowance() {
        let percentages = Self.allowancePercentages(from: sharedScoreAllowanceText)
        let config = percentages.isPopulated
            ? HandicapConfiguration(percentage: 1.0, isTeamCombined: true, positionPercentages: percentages)
            : nil
        Task { await roundSession.setSharedScoreHandicapConfig(config) }
    }
}
