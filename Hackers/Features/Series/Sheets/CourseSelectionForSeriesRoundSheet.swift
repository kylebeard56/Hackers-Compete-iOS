//
//  CourseSelectionForSeriesRoundSheet.swift
//  Hackers
//

import SwiftUI

struct CourseSelectionForSeriesRoundSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var roundSession: RoundSession

    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound
    let reviewSavedCourse: Bool

    var onRoundCreated: (String) -> Void

    @StateObject private var courseViewModel: CourseSelectionViewModel
    @State private var teeIdentityWarning: String?
    @State private var reviewCourse: CourseSegment?

    init(viewModel: SeriesViewModel, seriesRound: SeriesRound, reviewSavedCourse: Bool = true, courseViewModel: CourseSelectionViewModel? = nil, onRoundCreated: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.seriesRound = seriesRound
        self.reviewSavedCourse = reviewSavedCourse
        self.onRoundCreated = onRoundCreated
        let vm = courseViewModel ?? CourseSelectionViewModel()
        vm.isSetSeriesRoundCourseMode = true
        if let selection = seriesRound.resolvedCourse(using: viewModel.series), !selection.courseID.isEmpty {
            vm.modifyingCourse = nil
            vm.modifyingTee = nil
        }
        _courseViewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        CourseSelectionView(
            viewModel: courseViewModel,
            presentationType: .sheet,
            onCreation: nil,
            onModification: nil
        )
        .environmentObject(appSession)
        .environmentObject(locationService)
        .environmentObject(roundSession)
        .task {
            courseViewModel.onSetSeriesRoundCourse = { segment in
                viewModel.roundSetupCourses[seriesRound.id] = segment
                reviewCourse = segment
            }
        }
        .sheet(isPresented: Binding(get: { reviewCourse != nil }, set: { if !$0 { reviewCourse = nil } })) {
            if let course = reviewCourse {
                SeriesRoundHandicapReviewView(viewModel: viewModel, seriesRound: seriesRound,
                                             course: course, onRoundCreated: onRoundCreated)
            }
        }
        .task {
            await prefillFromDefaultCourse()
        }
        .alert(
            "Saved tee changed",
            isPresented: Binding(
                get: { teeIdentityWarning != nil },
                set: { if !$0 { teeIdentityWarning = nil } }
            )
        ) {
            Button("Review Tee", role: .cancel) {
                teeIdentityWarning = nil
            }
        } message: {
            if let warning = teeIdentityWarning {
                Text(warning)
            }
        }
    }

    private func prefillFromDefaultCourse() async {
        if reviewSavedCourse, let remembered = viewModel.roundSetupCourses[seriesRound.id] {
            reviewCourse = remembered
            return
        }
        let currentRound = viewModel.rounds.first { $0.id == seriesRound.id } ?? seriesRound
        guard let selection = currentRound.resolvedCourse(using: viewModel.series),
              !selection.courseID.isEmpty else { return }
        guard let validation = await SeriesRoundCoursePickerSheet.prefillSelection(selection, model: courseViewModel) else { return }
        if validation.status == .teeUnavailable {
            teeIdentityWarning = validation.message
        } else if reviewSavedCourse, let segment = validation.courseSegment {
            viewModel.roundSetupCourses[seriesRound.id] = segment
            reviewCourse = segment
        }
    }
}

/// Compact confirmation and inline repair, shared by saved and newly selected courses.
struct SeriesRoundHandicapReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound
    let course: CourseSegment
    var onRoundCreated: (String) -> Void

    @State private var showHandicapSettings = false
    @State private var expandedMembers: [String: Bool] = [:]
    @State private var errorMessage: String?
    @FocusState private var focusedMemberID: String?

    private var round: SeriesRound {
        viewModel.rounds.first { $0.id == seriesRound.id } ?? seriesRound
    }
    private var scoringRound: SeriesRound {
        var candidate = round
        if let basis = viewModel.roundSetupScoreBases[round.id] {
            candidate.roundConfig.scoreBasisOverride = basis
        }
        return candidate
    }
    private var useNetScoring: Binding<Bool> {
        Binding {
            SeriesRoundCreationMapping.primaryGameFormat(series: viewModel.series,
                seriesRound: scoringRound).configuration.basis == .net
        } set: { viewModel.roundSetupScoreBases[round.id] = $0 ? .net : .gross }
    }
    private var readiness: SeriesRoundHandicapReadiness {
        viewModel.handicapReadiness(for: scoringRound, course: course)
    }
    private var isBusy: Bool { viewModel.isSavingRoundHandicaps || viewModel.creatingRoundID != nil }
    private var canEdit: Bool { viewModel.isCommissioner && round.status == .planned && round.roundID == nil }
    private var isEditing: Bool {
        readiness.players.contains { expandedMembers[$0.id] ?? !$0.isReady }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(readiness.title)
                            .font(.title3.bold())
                            .accessibilityIdentifier("series.handicap.review.title")
                        Text("\(course.courseInfo.name) · \(course.holeSegment.holeCount) Holes")
                        Text(readiness.summary)
                            .foregroundStyle(readiness.isReady ? Color.green : Color.primary)
                            .accessibilityIdentifier("series.handicap.review.readiness")
                    }
                    .padding(.vertical, 4)
                    Button("Edit Handicaps") {
                        for player in readiness.players { expandedMembers[player.id] = true }
                    }
                    .accessibilityIdentifier("series.handicap.review.edit")
                    .disabled(!canEdit || isBusy)
                }
                ForEach(readiness.players) { player in
                    playerSection(player)
                }
                Section("Round Scoring") {
                    Toggle("Use net scoring", isOn: useNetScoring)
                        .accessibilityIdentifier("series.handicap.review.net")
                    if scoringRound.roundConfig.handicapNormalizationMode == .matchup {
                        Text("Round allowances shown. Strokes received are allocated relative to the lowest handicap in each matchup.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if viewModel.isCommissioner {
                        Button("Handicap Settings") { showHandicapSettings = true }
                            .accessibilityIdentifier("series.handicap.review.settings")
                    }
                }
                .disabled(!canEdit || isBusy)
                if isEditing {
                    Section {
                        Button("Save Entries") { Task { await save(startRound: false) } }
                            .accessibilityIdentifier("series.handicap.review.save")
                            .disabled(!canEdit || isBusy)
                    } footer: {
                        Text("Entries apply to this round only.")
                    }
                }
            }
            .listSectionSpacing(12)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if let error = errorMessage ?? viewModel.handicapSetupErrorMessage ?? viewModel.roundCreationErrorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                            .accessibilityIdentifier("series.handicap.review.error")
                    }
                    Button { Task { await save(startRound: true) } } label: {
                        HStack {
                            if isBusy { ProgressView() }
                            Text("Start Round").frame(maxWidth: .infinity)
                        }
                        .frame(minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentGreen)
                    .accessibilityIdentifier("series.handicap.review.start")
                    .disabled(!canEdit || isBusy || !readiness.isReady)
                }
                .padding()
                .background(.regularMaterial)
            }
            .tint(.accentGreen)
            .navigationTitle("Round Handicaps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { focusedMemberID = nil; dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedMemberID = nil }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("series.handicap.review.keyboardDone")
                }
            }
            .sheet(isPresented: $showHandicapSettings) {
                SeriesHandicapSettingsView(viewModel: viewModel)
            }
        }
    }

    private func playerSection(_ player: SeriesRoundHandicapReadiness.Player) -> some View {
        let member = player.member
        let draft = viewModel.handicapDraft(for: member, round: round, course: course)
        let resolution = player.resolution
        let expanded = Binding(
            get: { expandedMembers[player.id] ?? !player.isReady },
            set: { expandedMembers[player.id] = $0 }
        )
        return Section {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: player.isReady ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(player.isReady ? Color.accentGreen : .orange)
                        Text(player.isReady ? "\(member.name.fullName) · Ready" : member.name.fullName)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.headline)
                    if !player.isReady {
                        Text("Needs attention").font(.caption.bold()).foregroundStyle(.orange)
                    }
                    Text(player.summary)
                        .foregroundStyle(player.isReady ? Color.primary : .red)
                        .accessibilityIdentifier("series.handicap.\(member.id).summary")
                    if let tee = resolution.tee {
                        Text("\(tee.name) Tees · \(player.source)").font(.caption).foregroundStyle(.secondary)
                    }
                    if let maximum = player.maximumSummary { Text(maximum).font(.caption) }
                    if let allocation = player.allocationSummary {
                        Text(allocation).font(.caption)
                    }
                }
                Spacer(minLength: 4)
                Button(expanded.wrappedValue ? "Done" : "Edit") {
                    focusedMemberID = nil
                    expanded.wrappedValue.toggle()
                }
                .accessibilityLabel("\(expanded.wrappedValue ? "Done editing" : "Edit") \(member.name.fullName)")
                .accessibilityIdentifier("series.handicap.\(member.id).edit")
                .frame(minWidth: 44, minHeight: 44)
            }
            if expanded.wrappedValue {
                Picker("Entry method", selection: draftBinding(member, \.method)) {
                    if viewModel.memberHandicaps[member.id]?.effectiveIndex != nil {
                        Text("Series handicap").tag(SeriesRoundHandicapDraft.Method.series)
                    }
                    Text("Handicap Index").tag(SeriesRoundHandicapDraft.Method.personalIndex)
                    Text("Strokes Received").tag(SeriesRoundHandicapDraft.Method.strokes)
                }
                .accessibilityIdentifier("series.handicap.\(member.id).method")
                if draft.method != .series {
                    TextField(draft.method == .personalIndex ? "18-hole Handicap Index" : "Strokes for \(course.holeSegment.holeCount) holes",
                              text: draftBinding(member, \.text))
                        .keyboardType(draft.method == .personalIndex ? .numbersAndPunctuation : .numberPad)
                        .focused($focusedMemberID, equals: member.id)
                        .accessibilityLabel("\(member.name.fullName) \(draft.method.rawValue)")
                        .accessibilityIdentifier("series.handicap.\(member.id).value")
                    Picker("Player tees", selection: draftBinding(member, \.teeBoxID)) {
                        if !course.courseInfo.tees.contains(where: { $0.id == draft.teeBoxID }) {
                            Text("Select tee").tag(draft.teeBoxID)
                        }
                        ForEach(course.courseInfo.tees, id: \.id) { tee in
                            Text("\(tee.name) · \(tee.gender)").tag(tee.id)
                        }
                    }
                    .accessibilityIdentifier("series.handicap.\(member.id).tee")
                }
                DisclosureGroup("Handicap Details") {
                    Text("Source: \(player.source)")
                    if let tee = resolution.tee {
                        Text("\(tee.name) · \(course.holeSegment.title)")
                        Text("Rating \(tee.prettyRating(for: course.holeSegment) ?? "—") · Slope \(tee.slope(for: course.holeSegment).map(String.init) ?? "—") · Par \(resolution.par)")
                    }
                    if resolution.entryFormat == .courseHandicap, let index = resolution.handicapIndex {
                        Text("Original Index: \(ManualPersonalHandicap.display(index))")
                        if let calculationIndex = resolution.calculation.calculationIndex {
                            Text("Calculation Index for this segment: \(ManualPersonalHandicap.display(calculationIndex))")
                        }
                    }
                }
                .font(.footnote)
                .accessibilityIdentifier("series.handicap.\(member.id).details")
            }
        }
        .disabled(!canEdit || isBusy)
    }

    private func draftBinding<Value>(_ member: SeriesMember, _ keyPath: WritableKeyPath<SeriesRoundHandicapDraft, Value>) -> Binding<Value> {
        Binding {
            viewModel.handicapDraft(for: member, round: round, course: course)[keyPath: keyPath]
        } set: { value in
            var draft = viewModel.handicapDraft(for: member, round: round, course: course)
            draft[keyPath: keyPath] = value
            expandedMembers[member.id] = true // Keep the field open while a valid number is being typed.
            viewModel.setHandicapDraft(draft, memberID: member.id, roundID: round.id)
        }
    }

    private func save(startRound: Bool) async {
        focusedMemberID = nil
        errorMessage = nil
        guard canEdit, !isBusy else { return }
        if startRound, !readiness.isReady { return }
        let members = viewModel.handicapSetupMembers(for: round)
        guard var candidate = try? SeriesRoundHandicapSetup.applying(
            drafts: Dictionary(uniqueKeysWithValues: members.map { ($0.id, viewModel.handicapDraft(for: $0, round: round, course: course)) }), to: scoringRound
        ) else {
            errorMessage = "Enter a valid 18-hole Index (−10 to 54) or a whole number of strokes. Your entries are still here."
            return
        }
        let tee = course.defaultTee.flatMap { course.tee(from: $0) }
        candidate.courseOverride = SeriesCourseSelection(
            courseID: course.courseInfo.seriesCourseSelectionID,
            cachedName: course.courseInfo.name, defaultTeeBoxID: course.defaultTee ?? "",
            defaultTeeName: tee?.name, defaultTeeGender: tee?.gender, holeSegment: course.holeSegment
        )
        if startRound {
            let issues = SeriesRoundHandicapSetup.issues(series: viewModel.series, round: candidate,
                members: members, handicaps: viewModel.memberHandicaps, course: course)
            guard issues.isEmpty else {
                errorMessage = issues.map(\.message).joined(separator: "\n")
                return
            }
        }
        guard await viewModel.saveRoundHandicapSetup(candidate) else { return }
        if startRound, let roundID = await viewModel.createLiveRound(from: candidate, courseSegment: course) {
            onRoundCreated(roundID)
        }
    }
}
