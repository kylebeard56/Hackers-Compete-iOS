//
//  CourseSelectionView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/2/25.
//

import AlertToast
import CoreLocation
import SwiftUI

struct CourseSelectionView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    
    @StateObject var viewModel: CourseSelectionViewModel
    var onCreation: CallbackValue<String>? = nil
    var onModification: CallbackValue<CourseSegment>? = nil
    
    @State private var searchText: String = ""
    @State private var didSearchNearby = false
    @State private var showScorecardScan = false
    
    private let kGreenville = CLLocation(latitude: 34.851, longitude: -82.394)
    
    var body: some View {
        NavigationStack {
            StickyScrollView(
                header: { header },
                content: { content },
                footer: { footer },
                onScroll: { _ in }
            )
            .navigationDestination(isPresented: $viewModel.showConfirmation) {
                CourseSelectionConfirmation(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showCourseEdit) {
                CourseEditView(
                    course: viewModel.selectedCourse,
                    mode: .edit,
                    onSave: { course, originalOrigin in
                        Task {
                            await viewModel.saveCourseAndContinue(course: course, originalOrigin: originalOrigin)
                        }
                    }
                )
            }
            .sheet(isPresented: $showScorecardScan) {
                ScorecardScanView { course in
                    showScorecardScan = false
                    viewModel.select(course: course)
                }
            }
        }
        .task {
            if let existingCourse = viewModel.modifyingCourse, viewModel.isModifying {
                viewModel.select(course: existingCourse)
            }
            await viewModel.loadRecents()
        }
        .toast(isPresenting: $viewModel.isSearchingNearby) {
            .loader()
        }
        .toast(isPresenting: $viewModel.showCourseFetchError) {
            .errorBanner("Couldn't load course", "Please try again or search for the course.")
        }
        .onChange(of: viewModel.showCourseFetchError) { _, new in
            if new {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    viewModel.showCourseFetchError = false
                }
            }
        }
        .onReceive(viewModel.$roundCreationID, perform: { value in
            if value.isPopulated {
                onCreation?(value)
                //appSession.activeRoundID = value
                //dismiss()
            }
        })
        .onReceive(viewModel.$modifiedSegment, perform: { value in
            if let value {
                onModification?(value)
                dismiss()
            }
        })
        .onReceive(viewModel.$globalDismiss, perform: { value in
            if value {
                dismiss()
            }
        })
        .onReceive(viewModel.$selectedChip, perform: { value in
            if let location = locationService.location,
               locationService.authorizationStatus.isAuthorized,
               viewModel.nearbyCourses.isEmpty,
               value == .nearby {
                Task {
                    await viewModel.loadNearby(using: location)
                }
            }
            // TODO: What is this dead code doing here?
//            guard !didSearchNearby else { return }
//            Task {
//                await viewModel.loadNearby(using: kGreenville)
//            }
        })
        .onReceive(HackersNotification.locationAuthorizationChanged.publisher(), perform: { data in
            if let status = data.object as? CLAuthorizationStatus,
               let location = locationService.location,
               status.isAuthorized {
//               viewModel.nearbyCourses.isEmpty {
                Task {
                    await viewModel.loadNearby(using: location)
                }
            }
        })
//        .sheet(isPresented: $viewModel.showConfirmation) {
//            CourseSelectionConfirmation(viewModel: viewModel)
//        }
    }
    
    private var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Pick your course")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(Color.foregroundPrimary)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                NavButton(icon: "f00d", onTap: { dismiss() })
            }
            
            SearchBar(
                placeholder: "Search by course name",
                onDebounce: { text in
                    print("onDebounce \(text)")
                    searchText = text
                    await viewModel.searchCourses(for: text, using: kGreenville)
                }
            )
            
            if searchText.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(CourseSelectionChip.allCases, id: \.self) { chip in
                            let match = chip == viewModel.selectedChip
                            Button(action: {
                                Haptics.fire(.light)
                                viewModel.selectedChip = chip
                            }) {
                                Chip(
                                    text: chip.rawValue,
                                    foreground: match ? .white : .foregroundPrimary,
                                    background: match ? .accentGreen : .neutral6
                                )
                            }
                        }
                        
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, viewModel.isModifying ? 16 : 0)
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            if searchText.isPopulated {
                if viewModel.isSearching {
                    skeletonView
                } else if viewModel.searchedCourses.isPopulated {
                    let count = viewModel.searchedCourses.count
                    Text("\(count) course\(count.pluralized) found")
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                    list(for: viewModel.searchedCourses)
                } else {
                    VStack(spacing: 16) {
                        Text("No courses found")
                            .fontStyle(kFontName, size: 15, weight: .medium)
                            .foregroundStyle(Color.neutral)
                            .alignCenter()

                        HStack(spacing: 12) {
                            Button {
                                Haptics.fire(.light)
                                showScorecardScan = true
                            } label: {
                                Label("Scan scorecard", systemImage: "camera.viewfinder")
                                    .fontStyle(kFontName, size: 14, weight: .semibold)
                                    .foregroundStyle(Color.foregroundPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.neutral6)
                                    .cornerRadius(radius: 10)
                            }
                            Button {
                                Haptics.fire(.light)
                                viewModel.select(course: Course(origin: .manual))
                            } label: {
                                Label("Add manually", systemImage: "square.and.pencil")
                                    .fontStyle(kFontName, size: 14, weight: .semibold)
                                    .foregroundStyle(Color.foregroundPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.neutral6)
                                    .cornerRadius(radius: 10)
                            }
                        }
                    }
                }
            } else {
                suggestiveStateView
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var footer: some View {
        if let course = viewModel.modifyingCourse, viewModel.isModifying {
            VStack(spacing: 16) {
                Line()

                Text("Currently playing:")
                    .fontStyle(kFontName, size: 15, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
                    .padding(.horizontal, 16)
                
                PrimaryButton(
                    appearance: .fill,
                    title: course.prettyCourseName,
                    callToActionIcon: "f178",
                    iconWeight: .solid,
                    labelColor: .backgroundPrimary,
                    buttonColor: .foregroundPrimary,
                    fillWidth: true,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: {
                        viewModel.select(course: course)
                    }
                )
                .padding(.horizontal, 16)
            }
        } else {
            EmptyView()
        }
    }
    
    // MARK: - Chips
    
    @ViewBuilder
    private var suggestiveStateView: some View {
        VStack(spacing: 16) {
            if viewModel.selectedChip == .recent {
                recentCourses
            }
            
            if viewModel.selectedChip == .nearby {
                nearbyCourses
            }
            
//            if viewModel.selectedChip == .favorite {
//                Spacer()
//                Text("Favorite courses coming soon")
//                    .fontStyle(kFontName, size: 15, weight: .medium)
//                    .foregroundStyle(Color.neutral)
//                    .alignCenter()
//                Spacer()
//            }
        }
    }
    
    // MARK: - Recent
    
    @ViewBuilder
    private var recentCourses: some View {
        if viewModel.isLoadingRecents {
            skeletonView
        } else if viewModel.recentCourseEntries.isPopulated {
            list(for: viewModel.recentCourseEntries)
        } else {
            recentCoursesEmptyState
        }
    }
    
    private var recentCoursesEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("ClubhouseIsometric")
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width * 0.45)
            
            Text("No recent courses")
                .fontStyle(kFontName, size: 20, weight: .semibold)
                .foregroundStyle(Color.foregroundPrimary)
                .alignCenter()
            
            Text("We'll show courses you've played here. Start a round to build your history.")
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.center)
                .alignCenter()
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Nearby
    
    @ViewBuilder
    private var nearbyCourses: some View {
        if locationService.authorizationStatus.isAuthorized {
            if viewModel.isLoadingNearby {
                skeletonView
            } else if viewModel.nearbyPlacemarks.isPopulated {
                list(for: viewModel.nearbyPlacemarks)
            } else {
                Spacer()
                Text("No nearby courses found")
                    .fontStyle(kFontName, size: 15, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .alignCenter()
                Spacer()
            }
        } else {
            Spacer()
            LocationRequestView()
            Spacer()
        }
    }
    
    // MARK: - Lists & Rows
    
    private func list(for entries: [CourseHistoryEntry]) -> some View {
        ForEach(entries, id: \.compositeKey) { entry in
            row(for: entry)
        }
    }
    
    private func list(for courses: [Course]) -> some View {
        ForEach(courses, id: \.id) { course in
            row(for: course)
        }
    }
    
    private func list(for courses: [GolfCoursePlacemark]) -> some View {
        //ScrollView(showsIndicators: false) {
            ForEach(courses, id: \.id) { course in
                row(for: course)
            }
        //}
    }
    
    private func row(for entry: CourseHistoryEntry) -> some View {
        Button(action: {
            Task { await viewModel.selectFromRecent(entry: entry) }
        }) {
            VStack {
                HStack(spacing: 16) {
                    Icon(name: "f3c5", size: 15, weight: .solid)
                        .foregroundStyle(Color.neutral4)
                    
                    VStack(spacing: 2) {
                        Text(entry.name)
                            .fontStyle(kFontName, size: 17, weight: .medium)
                            .foregroundStyle(Color.foregroundPrimary)
                            .multilineTextAlignment(.leading)
                            .alignLeading()

                        Text(subtitle(for: entry))
                            .fontStyle(kFontName, size: 14, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .alignLeading()
                    }
                }
                
                Line()
            }
        }
    }
    
    private func subtitle(for entry: CourseHistoryEntry) -> String {
        let date = Date(timeIntervalSince1970: entry.lastPlayedAt.unix)
        return "\(entry.roundsPlayed) round\(entry.roundsPlayed.pluralized) · \(date.relativeTimeAgo)"
    }
    
    private func row(for course: Course) -> some View {
        Button(action: {
            Haptics.fire(.light)
            viewModel.select(course: course)
        }) {
            VStack {
                HStack(spacing: 16) {
                    Icon(name: "f3c5", size: 15, weight: .solid)
                        .foregroundStyle(Color.neutral4)
                    
                    VStack(spacing: 2) {
                        Text(course.prettyCourseName)
                            .fontStyle(kFontName, size: 17, weight: .medium)
                            .foregroundStyle(Color.foregroundPrimary)
                            .multilineTextAlignment(.leading)
                            .alignLeading()

                        HStack(spacing: 8) {
                            ForEach(Array(rowComponents(from: course).enumerated()), id: \.offset) { index, part in
                                if index > 0 {
                                    Dot()
                                }
                                Text(part)
                                    .fontStyle(kFontName, size: 14, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                            }
                            
                            Spacer()
                        }
                    }
                }
                
                Line()
            }
        }
    }
    
    private func rowComponents(from course: Course) -> [String] {
        var parts: [String] = []
        
        if course.prettyClubName != course.prettyCourseName {
            parts.append(course.prettyClubName)
        }
        
        if let location = course.location {
            if let city = location.city, let state = location.state {
                parts.append("\(city), \(state)")
            }
            
            if let distance = location.formattedDistance(to: locationService.location) {
                parts.append(distance)
            }
        }
        
        return parts
    }
    
    private func row(for course: GolfCoursePlacemark) -> some View {
        Button(action: {
            Haptics.fire(.light)
            viewModel.fetchFromNearby(using: course.normalizedName, and: locationService.location)
        }) {
            VStack {
                HStack(spacing: 16) {
                    Icon(name: "f3c5", size: 15, weight: .solid)
                        .foregroundStyle(Color.neutral4)
                    
                    VStack {
                        Text("\(course.name)")
                            .fontStyle(kFontName, size: 17, weight: .medium)
                            .foregroundStyle(Color.foregroundPrimary)
                            .multilineTextAlignment(.leading)
                            .alignLeading()
                        
                        Text(course.formattedDistance)
                            .fontStyle(kFontName, size: 14, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .alignLeading()
                    }
                }
                
                Line()
            }
        }
    }
    
    // MARK: - Skeleton
    
    private var skeletonView: some View {
        ScrollView(showsIndicators: false) {
            ForEach(0...5, id: \.self) { _ in
                SkeletonRow()
                Line()
            }
        }
    }
}

#Preview {
    CourseSelectionView(viewModel: .init())
        .environmentObject(AppSession())
        .environmentObject(LocationService())
}
