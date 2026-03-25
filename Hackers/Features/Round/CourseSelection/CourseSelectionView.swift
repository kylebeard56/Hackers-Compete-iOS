//
//  CourseSelectionView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/2/25.
//

import AlertToast
import CoreLocation
import SwiftUI
import UIKit

enum CourseSelectionPresentationType {
    case fullscreen
    case sheet
}

struct CourseSelectionView: View, Loggable {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    
    @StateObject var viewModel: CourseSelectionViewModel
    var presentationType: CourseSelectionPresentationType = .fullscreen
    var onCreation: CallbackValue<String>? = nil
    var onModification: CallbackValue<CourseSegment>? = nil
    
    @State private var searchText: String = ""
    @State private var didSearchNearby = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showScorecardScanNotes = false
    @State private var pendingScorecardImage: UIImage?
    @State private var pendingScorecardScanSource: ScorecardScanSource?
    @State private var scorecardScanNotes = ""
    @State private var didTrackCourseSelectionView = false
    @AppStorage("scorecard_scan_vision_model") private var scorecardVisionModelRaw: String = ScorecardScanVisionModel.defaultSelection.rawValue

    private let kGreenville = CLLocation(latitude: 34.851, longitude: -82.394)
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                StickyScrollView(
                    header: { header },
                    content: { content },
                    footer: { footer },
                    onScroll: { _ in }
                )
                .navigationDestination(isPresented: $viewModel.showConfirmation) {
                    CourseSelectionConfirmation(viewModel: viewModel)
                }
                .fullScreenCover(isPresented: $showCamera) {
                    ScorecardImagePicker(
                        sourceType: .camera,
                        onImageSelected: { image in
                            showCamera = false
                            prepareScorecardScan(with: image, source: .camera)
                        },
                        onCancel: { showCamera = false }
                    )
                    .edgesIgnoringSafeArea(.vertical)
                }
                .sheet(isPresented: $showPhotoPicker) {
                    ScorecardPhotoPicker { image in
                        showPhotoPicker = false
                        prepareScorecardScan(with: image, source: .photoLibrary)
                    }
                }
                .sheet(isPresented: $showScorecardScanNotes) {
                    ScorecardScanNotesSheet(
                        notes: $scorecardScanNotes,
                        selectedVision: Binding(
                            get: { ScorecardScanVisionModel.fromStoredRawValue(scorecardVisionModelRaw) },
                            set: { scorecardVisionModelRaw = $0.rawValue }
                        ),
                        onCancel: {
                            pendingScorecardImage = nil
                            pendingScorecardScanSource = nil
                            scorecardScanNotes = ""
                            showScorecardScanNotes = false
                        },
                        onScan: {
                            startScorecardScan()
                        }
                    )
                    .presentationDetents([.height(400)])
                    .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $viewModel.showCourseEdit) {
                    CourseEditView(
                        course: viewModel.selectedCourse,
                        mode: .edit,
                        shouldTrackRoundSetup: viewModel.shouldTrackRoundSetup,
                        onSave: { course, _, wasEdited in
                            Task {
                                await viewModel.saveCourseIfEdited(course: course, wasEdited: wasEdited)
                                viewModel.showCourseEdit = false
                                viewModel.showConfirmation = true
                            }
                        }
                    )
                    .presentationDragIndicator(.visible)
                }

                fabButton
            }
        }
        .task {
            let migrated = ScorecardScanVisionModel.fromStoredRawValue(scorecardVisionModelRaw)
            if migrated.rawValue != scorecardVisionModelRaw {
                scorecardVisionModelRaw = migrated.rawValue
            }
            if let existingCourse = viewModel.modifyingCourse, viewModel.isModifying {
                viewModel.select(course: existingCourse, source: .existingRoundChange, trackEvent: false)
            }
            await viewModel.loadRecents()
            guard !didTrackCourseSelectionView, viewModel.shouldTrackRoundSetup else { return }
            didTrackCourseSelectionView = true
            addEvent(
                "round_setup.course_selection_viewed",
                eventProps: [
                    "is_existing_round_change": viewModel.isModifying
                ]
            )
        }
        .toast(isPresenting: $viewModel.isSearchingNearby) {
            .loader()
        }
        .toast(isPresenting: $viewModel.showCourseFetchError) {
            .errorBanner("Couldn't load course", "Please try again or search for the course.")
        }
        .toast(isPresenting: Binding(
            get: { viewModel.scorecardScanError != nil },
            set: { if !$0 { viewModel.scorecardScanError = nil } }
        )) {
            .errorBanner("Scan failed", viewModel.scorecardScanError ?? "Please try again.")
        }
        .onChange(of: viewModel.showCourseFetchError) { _, new in
            if new {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    viewModel.showCourseFetchError = false
                }
            }
        }
        .onChange(of: viewModel.scorecardScanError) { _, new in
            if new != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    viewModel.scorecardScanError = nil
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
    
    private var fabButton: some View {
        Menu {
            Menu {
                Button {
                    Haptics.fire(.light)
                    showCamera = true
                } label: {
                    Label("Take photo", systemImage: "camera")
                }
                Button {
                    Haptics.fire(.light)
                    showPhotoPicker = true
                } label: {
                    Label("Pick photo", systemImage: "photo.on.rectangle.angled")
                }
            } label: {
                Label("Scan scorecard", systemImage: "camera.viewfinder")
            }
            Button {
                Haptics.fire(.light)
                viewModel.select(course: Course(origin: .manual), source: .manual)
            } label: {
                Label("Add manually", systemImage: "square.and.pencil")
            }
        } label: {
            ZStack {
                Capsule()
                    .fill(Color.accentGreen)
                    .frame(width: viewModel.isScanningScorecard ? 140 : 56, height: 56)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                if viewModel.isScanningScorecard {
                    HStack(spacing: 8) {
                        Text("Scanning...")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(.white)
                        ProgressView()
                            .tint(.white)
                    }
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isScanningScorecard)
        }
        .disabled(viewModel.isScanningScorecard)
        .padding(24)
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
        .padding(.top, headerTopPadding)
    }

    private var headerTopPadding: CGFloat {
        switch presentationType {
        case .sheet:
            return 16
        case .fullscreen:
            return viewModel.isModifying ? 16 : 0
        }
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
                            Menu {
                                Button {
                                    Haptics.fire(.light)
                                    showCamera = true
                                } label: {
                                    Label("Take photo", systemImage: "camera")
                                }
                                Button {
                                    Haptics.fire(.light)
                                    showPhotoPicker = true
                                } label: {
                                    Label("Pick photo", systemImage: "photo.on.rectangle.angled")
                                }
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
                                viewModel.select(course: Course(origin: .manual), source: .manual)
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
                        viewModel.select(course: course, source: .existingRoundChange)
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
            viewModel.select(course: course, source: .search)
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

    private func prepareScorecardScan(with image: UIImage, source: ScorecardScanSource) {
        pendingScorecardImage = image
        scorecardScanNotes = ""
        pendingScorecardScanSource = source
        DispatchQueue.main.async {
            showScorecardScanNotes = true
        }
    }

    private func startScorecardScan() {
        guard let image = pendingScorecardImage,
              let scanSource = pendingScorecardScanSource else { return }

        let notes = scorecardScanNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let vision = ScorecardScanVisionModel.fromStoredRawValue(scorecardVisionModelRaw)
        showScorecardScanNotes = false

        Task {
            await viewModel.scanScorecard(
                image: image,
                userNotes: notes.isEmpty ? nil : notes,
                vision: vision,
                scanSource: scanSource
            )

            pendingScorecardImage = nil
            pendingScorecardScanSource = nil
            scorecardScanNotes = ""
        }
    }
}

private struct ScorecardScanNotesSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var notes: String
    @Binding var selectedVision: ScorecardScanVisionModel
    var onCancel: Callback? = nil
    var onScan: Callback? = nil

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private let kCharacterCount = 500
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scan notes")
                .fontStyle(kFontName, size: 22, weight: .semibold)
                .foregroundStyle(Color.foregroundPrimary)

            Text("Add optional hints that would help during scanning.")
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.leading)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.neutral6)

                if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Start typing...")
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                }

                TextEditor(text: $notes)
                    .scrollContentBackground(.hidden)
                    .fontStyle(kFontName, size: 15, weight: .regular)
                    .foregroundStyle(Color.foregroundPrimary)
                    .padding(10)
                    .frame(minHeight: 110)
                    .background(Color.clear)
            }
            .frame(height: 120)
            
            HStack(spacing: 12) {
                Text("\(notes.count) / \(kCharacterCount)")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(notes.count > kCharacterCount ? Color.systemError : Color.neutral)
                
                Spacer(minLength: 0)
                
                Menu {
                    ForEach(ScorecardScanVisionModel.allCases.reversed()) { model in
                        Button {
                            Haptics.fire(.light)
                            selectedVision = model
                        } label: {
                            Text(model.displayName)
                            Text(model.tierSubtitle)
                        }
                    }
                    Text("Select AI model:")
                } label: {
                    Chip(
                        text: "Model: " + selectedVision.displayName,
                        icon: "f078",
                        iconWeight: .solid,
                        size: .xSmall,
                        style: .fill,
                        foreground: Color.neutral,
                        background: Color.neutral6
                    )
                }
                .buttonStyle(.plain)
                .onTapGesture {
                    Haptics.fire(.light)
                }
            }
            
            Spacer(minLength: 0)

            HStack(spacing: 12) {
                PrimaryButton(
                    appearance: .fill,
                    title: "Cancel",
                    labelColor: .foregroundPrimary,
                    buttonColor: .neutral6,
                    fillWidth: false,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { onCancel?() }
                )

                PrimaryButton(
                    appearance: .fill,
                    title: notes.isEmpty ? "Skip and scan" : "Scan scorecard",
                    labelColor: .backgroundPrimary,
                    buttonColor: .foregroundPrimary,
                    fillWidth: true,
                    isDisabled: .constant(notes.count > kCharacterCount),
                    isLoading: .false,
                    onTap: { onScan?() }
                )
            }
        }
        .padding(20)
        .background(Color.backgroundPrimary)
    }
}

#Preview {
    CourseSelectionView(viewModel: .init())
        .environmentObject(AppSession())
        .environmentObject(LocationService())
}

#Preview("Scan notes") {
    CourseSelectionView(viewModel: .init())
        .environmentObject(AppSession())
        .environmentObject(LocationService())
        .sheet(isPresented: .true) {
            ScorecardScanNotesSheet(
                notes: .blank,
                selectedVision: .constant(.defaultSelection)
            )
            .presentationDetents([.height(400)])
            .presentationDragIndicator(.visible)
        }
}
