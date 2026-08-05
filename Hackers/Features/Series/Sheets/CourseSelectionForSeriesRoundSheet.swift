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

    var onRoundCreated: (String) -> Void

    @StateObject private var courseViewModel: CourseSelectionViewModel
    @State private var teeIdentityWarning: String?

    init(viewModel: SeriesViewModel, seriesRound: SeriesRound, onRoundCreated: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.seriesRound = seriesRound
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
                Task {
                    if let roundID = await viewModel.createLiveRound(from: seriesRound, courseSegment: segment) {
                        await MainActor.run {
                            onRoundCreated(roundID)
                        }
                    }
                }
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
        guard let selection = seriesRound.resolvedCourse(using: viewModel.series),
              !selection.courseID.isEmpty else { return }
        let course: Course?
        if let apiID = Int(selection.courseID) {
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
                    }
                }
            }
        }
    }
}
