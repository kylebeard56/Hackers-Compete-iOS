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
    }

    private func prefillFromDefaultCourse() async {
        guard let selection = seriesRound.resolvedCourse(using: viewModel.series),
              !selection.courseID.isEmpty else { return }
        let course: Course?
        if let apiID = Int(selection.courseID) {
            do {
                let apiCourse = try await GolfCourseAPI.shared.getCourse(by: apiID)
                course = Course(from: apiCourse)
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
                }
            }
        }
    }
}
