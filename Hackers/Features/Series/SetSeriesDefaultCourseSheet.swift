//
//  SetSeriesDefaultCourseSheet.swift
//  Hackers
//

import SwiftUI

struct SetSeriesDefaultCourseSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var roundSession: RoundSession

    @ObservedObject var viewModel: SeriesViewModel

    var onSaved: () -> Void

    @StateObject private var courseViewModel: CourseSelectionViewModel = {
        let vm = CourseSelectionViewModel()
        vm.isSetSeriesDefaultCourseMode = true
        return vm
    }()

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

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
            courseViewModel.onSetSeriesDefaultCourse = { courseID, cachedName, teeID, holeSegment in
                Task {
                    await viewModel.updateDefaultCourse(
                        courseID: courseID,
                        cachedName: cachedName,
                        defaultTeeID: teeID,
                        holeSegment: holeSegment
                    )
                    await MainActor.run {
                        onSaved()
                        dismiss()
                    }
                }
            }
        }
    }
}
