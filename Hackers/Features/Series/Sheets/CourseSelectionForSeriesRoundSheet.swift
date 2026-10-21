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

    init(viewModel: SeriesViewModel, seriesRound: SeriesRound, reviewSavedCourse: Bool = true, onRoundCreated: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.seriesRound = seriesRound
        self.reviewSavedCourse = reviewSavedCourse
        self.onRoundCreated = onRoundCreated
        let vm = CourseSelectionViewModel()
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
        let course: Course?
        if let apiID = GolfCourseID(selection.courseID) {
            do {
                course = try await GolfCourseRepository.shared.course(by: apiID)
            } catch {
                course = nil
            }
        } else {
            switch await FirebaseService.shared.getCourseByID(selection.courseID) {
            case .success(let c): course = c
            case .failure: course = nil
            }
        }
        if let course {
            await MainActor.run {
                courseViewModel.select(course: course, source: .seriesRoundDefault)
                courseViewModel.holeSegment = selection.holeSegment
                if !selection.defaultTeeBoxID.isEmpty,
                   let tee = course.tees.first(where: { $0.id == selection.defaultTeeBoxID }) {
                    courseViewModel.selectedTee = tee
                    let savedIdentity = [
                        selection.defaultTeeName,
                        selection.defaultTeeGender
                    ]
                    .compactMap { $0 }
                    .joined(separator: " / ")
                    let refreshedIdentity = "\(tee.name) / \(tee.gender)"
                    if savedIdentity.isPopulated,
                       savedIdentity.caseInsensitiveCompare(refreshedIdentity) != .orderedSame {
                        teeIdentityWarning = "The saved tee ID now resolves to \(refreshedIdentity), previously \(savedIdentity). Review the tee before starting this round."
                    } else if reviewSavedCourse {
                        let segment = courseViewModel.buildCourseSegment()
                        viewModel.roundSetupCourses[seriesRound.id] = segment
                        reviewCourse = segment
                    }
                }
            }
        }
    }
}

/// Review is shared by the saved-course and course-selection start paths.
struct SeriesRoundHandicapReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SeriesViewModel
    let seriesRound: SeriesRound
    let course: CourseSegment
    var onRoundCreated: (String) -> Void

    @State private var showHandicapSettings = false
    @State private var useNetScoring = false
    @State private var errorMessage: String?
    @FocusState private var focusedMemberID: String?

    private var round: SeriesRound {
        viewModel.rounds.first { $0.id == seriesRound.id } ?? seriesRound
    }
    private var members: [SeriesMember] { viewModel.handicapSetupMembers(for: round) }
    private var isBusy: Bool { viewModel.isSavingRoundHandicaps || viewModel.creatingRoundID != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Review Missing Handicaps")
                        .font(.title3.bold())
                        .accessibilityIdentifier("series.handicap.review.title")
                    Text("Enter an 18-hole personal Handicap Index or strokes for this round. These entries never change personal profiles or permanent series handicaps.")
                    Text("\(course.courseInfo.name) · \(course.holeSegment.title)")
                    Toggle("Use net scoring", isOn: $useNetScoring)
                        .accessibilityIdentifier("series.handicap.review.net")
                    Text("Personal Indexes and manual strokes work with series handicaps Off.")
                        .font(.footnote)
                    if viewModel.isCommissioner {
                        Button("Handicap Settings") { showHandicapSettings = true }
                            .accessibilityIdentifier("series.handicap.review.settings")
                    }
                }
                ForEach(members, id: \.id) { member in
                    playerSection(member)
                }
                Section {
                    if let error = errorMessage ?? viewModel.handicapSetupErrorMessage ?? viewModel.roundCreationErrorMessage {
                        Text(error).foregroundStyle(.red)
                            .accessibilityIdentifier("series.handicap.review.error")
                    }
                    Button("Save Entries") { Task { await save(startRound: false) } }
                        .accessibilityIdentifier("series.handicap.review.save")
                    Button("Start Round") { Task { await save(startRound: true) } }
                        .accessibilityIdentifier("series.handicap.review.start")
                    if isBusy { ProgressView("Saving round setup…") }
                }
                .disabled(isBusy || !viewModel.isCommissioner)
            }
            .navigationTitle("Round Handicaps")
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
            .onAppear {
                useNetScoring = SeriesRoundCreationMapping.primaryGameFormat(
                    series: viewModel.series, seriesRound: round
                ).configuration.basis == .net
            }
            .sheet(isPresented: $showHandicapSettings) {
                SeriesHandicapSettingsView(viewModel: viewModel)
            }
        }
    }

    private func playerSection(_ member: SeriesMember) -> some View {
        let draft = viewModel.handicapDraft(for: member, round: round, course: course)
        let resolution = preview(for: member, draft: draft)
        return Section {
            Text(member.isOffline ? "Offline / guest" : "Registered player").font(.caption)
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
            let seriesIndex = round.roundConfig.handicapEntryFormat == .courseHandicap
                ? viewModel.memberHandicaps[member.id]?.effectiveIndex : nil
            let displayedIndex = draft.method == .personalIndex
                ? draft.input?.value : (seriesIndex ?? viewModel.personalIndexesByMemberID[member.id])
            Text("Handicap Index: \(displayedIndex.map(ManualPersonalHandicap.display) ?? "Not set")")
                .accessibilityIdentifier("series.handicap.\(member.id).index")
            if let strokes = resolution.effectiveStrokes, resolution.validationIssue == nil {
                let courseHandicap = resolution.entryFormat == .courseHandicap ? (resolution.calculation.courseHandicap ?? strokes) : strokes
                Text("Course HCP \(courseHandicap) · Strokes Received \(strokes)")
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("series.handicap.\(member.id).calculated")
            } else {
                Text(resolution.validationIssue?.message ?? "Handicap unresolved")
                    .font(.footnote).foregroundStyle(.red)
                    .accessibilityIdentifier("series.handicap.\(member.id).missing")
            }
            if let maximum = resolution.calculation.maximumIndex,
               let entered = resolution.handicapIndex, entered > Double(maximum) {
                Text("Series Index maximum \(maximum) applied before tee conversion.")
                    .font(.caption)
            }
            if let tee = resolution.tee {
                Text("\(tee.name) · \(course.holeSegment.title) · Rating \(tee.prettyRating(for: course.holeSegment) ?? "—") · Slope \(tee.slope(for: course.holeSegment).map(String.init) ?? "—") · Par \(tee.par(for: course.holeSegment))")
                    .font(.caption)
            }
        } header: {
            Text(member.name.fullName)
        }
        .disabled(!viewModel.isCommissioner || isBusy)
    }

    private func draftBinding<Value>(_ member: SeriesMember, _ keyPath: WritableKeyPath<SeriesRoundHandicapDraft, Value>) -> Binding<Value> {
        Binding {
            viewModel.handicapDraft(for: member, round: round, course: course)[keyPath: keyPath]
        } set: { value in
            var draft = viewModel.handicapDraft(for: member, round: round, course: course)
            draft[keyPath: keyPath] = value
            viewModel.setHandicapDraft(draft, memberID: member.id, roundID: round.id)
        }
    }

    private func preview(for member: SeriesMember, draft: SeriesRoundHandicapDraft) -> SeriesCourseHandicapResolution {
        var candidate = round
        // Empty/invalid edits remain visibly unresolved, even if an older saved value exists.
        candidate.handicapInputs[member.id] = draft.input
        var handicaps = viewModel.memberHandicaps
        if draft.method != .series, draft.input == nil { handicaps[member.id] = nil }
        return SeriesRoundHandicapSetup.resolution(series: viewModel.series, round: candidate,
                                                    member: member, handicaps: handicaps, course: course)
    }

    private func save(startRound: Bool) async {
        focusedMemberID = nil
        errorMessage = nil
        guard var candidate = try? SeriesRoundHandicapSetup.applying(
            drafts: Dictionary(uniqueKeysWithValues: members.map { ($0.id, viewModel.handicapDraft(for: $0, round: round, course: course)) }), to: round
        ) else {
            errorMessage = "Enter a valid 18-hole Index (−10 to 54) or a whole number of strokes. Your entries are still here."
            return
        }
        candidate.roundConfig.scoreBasisOverride = useNetScoring ? .net : .gross
        let tee = course.defaultTee.flatMap { course.tee(from: $0) }
        candidate.courseOverride = SeriesCourseSelection(
            courseID: course.courseInfo.golfCourseApiID.map(String.init) ?? course.courseInfo.id,
            cachedName: course.courseInfo.name, defaultTeeBoxID: course.defaultTee ?? "",
            defaultTeeName: tee?.name, defaultTeeGender: tee?.gender, holeSegment: course.holeSegment
        )
        if startRound {
            let issues = SeriesRoundHandicapSetup.issues(series: viewModel.series, round: candidate,
                members: members, handicaps: viewModel.memberHandicaps, course: course)
            guard issues.isEmpty else {
                errorMessage = "Review the players above before starting:\n" + issues.map(\.message).joined(separator: "\n")
                return
            }
        }
        guard await viewModel.saveRoundHandicapSetup(candidate) else { return }
        if startRound, let roundID = await viewModel.createLiveRound(from: candidate, courseSegment: course) {
            onRoundCreated(roundID)
        }
    }
}
