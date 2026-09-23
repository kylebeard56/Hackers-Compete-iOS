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
    private enum LocationAssistFlow {
        case scorecardScan
        case askAI
    }

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    
    @StateObject var viewModel: CourseSelectionViewModel
    var presentationType: CourseSelectionPresentationType = .fullscreen
    var onCreation: CallbackValue<String>? = nil
    var onModification: CallbackValue<CourseSegment>? = nil
    var onRemoveModification: Callback? = nil
    
    @State private var searchText: String = ""
    @State private var didSearchNearby = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showScorecardScanNotes = false
    @State private var showSimpleRoundSetup = false
    @State private var showAskAI = false
    @State private var showAskAIDraftEditor = false
    @State private var pendingScorecardImage: UIImage?
    @State private var pendingScorecardScanSource: ScorecardScanSource?
    @State private var scorecardScanNotes = ""
    @State private var didTrackCourseSelectionView = false
    @State private var locationSettingsAlertFlow: LocationAssistFlow?
    @State private var showRemoveCourseAlert = false
    @AppStorage("scorecard_scan_vision_model") private var scorecardVisionModelRaw: String = ScorecardScanVisionModel.defaultSelection.rawValue
    @AppStorage("scorecard_scan_location_assist_enabled") private var scorecardLocationAssistEnabled: Bool = true
    @AppStorage("course_ask_ai_location_assist_enabled") private var askAILocationAssistEnabled: Bool = true
    @AppStorage("course_ask_ai_text_model") private var askAITextModelRaw: String = AskAITextModel.defaultSelection.rawValue


    private var courseSelectionPalette: DesignPalette {
        DesignPalette(theme: .primary, scheme: colorScheme)
    }

    private var askAITextModel: AskAITextModel {
        AskAITextModel.fromStoredRawValue(askAITextModelRaw)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                StickyScrollView(
                    header: { header },
                    content: { content },
                    footer: { footer },
                    onScroll: { _ in }
                )

                if presentationType == .sheet {
                    VStack {
                        HStack {
                            Spacer(minLength: 0)
                            NavButton(icon: "f00d", onTap: { dismiss() })
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        // Pass touches through to the course list; without this the spacer fills the
                        // ZStack and swallows all taps (sheet presentation, e.g. series default course).
                        Spacer(minLength: 0)
                            .allowsHitTesting(false)
                    }
                }

                if !viewModel.isModifying {
                    fabButton
                        .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
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
                    isLocationAssistEnabled: locationAssistBinding(for: .scorecardScan),
                    selectedVision: Binding(
                        get: { ScorecardScanVisionModel.fromStoredRawValue(scorecardVisionModelRaw) },
                        set: { scorecardVisionModelRaw = $0.rawValue }
                    ),
                    approximateLocation: locationService.location.map(ScorecardScanApproximateLocation.init),
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
                .presentationDetents([.height(460)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSimpleRoundSetup) {
                SimpleRoundSetupSheet(
                    initialValue: viewModel.simpleRoundSetup ?? .init(),
                    onCancel: { showSimpleRoundSetup = false },
                    onContinue: { setup in
                        showSimpleRoundSetup = false
                        viewModel.configureSimpleRound(setup)
                    }
                )
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAskAI, onDismiss: {
                viewModel.cancelAskAIRequest()
            }) {
                AskAICourseSheet(
                    messages: viewModel.askAIMessages,
                    isSending: viewModel.isSendingAskAIMessage,
                    isLocationAssistEnabled: locationAssistBinding(for: .askAI),
                    approximateLocation: locationService.location.map(ScorecardScanApproximateLocation.init),
                    examplePrompts: askAIExamplePrompts,
                    onCancel: {
                        showAskAI = false
                    },
                    onSend: { prompt in
                        await viewModel.sendAskAIMessage(prompt, context: currentAskAILookupContext)
                    },
                    onUseCandidate: { candidate in
                        Task {
                            if await viewModel.loadAskAICandidate(candidate) { showAskAI = false }
                        }
                    },
                    errorMessage: viewModel.askAIError,
                    onRetry: { Task { await viewModel.retryAskAIMessage(context: currentAskAILookupContext) } },
                    onStop: {
                        viewModel.cancelAskAIRequest()
                        viewModel.askAIError = "Search stopped. Retry when you’re ready."
                    },
                    onStartOver: { viewModel.resetAskAIConversation() },
                    selectedModel: askAITextModel,
                    onSelectModel: { askAITextModelRaw = $0.rawValue }

                )
                .sheet(isPresented: $showAskAIDraftEditor) {
                    CourseEditView(
                        course: viewModel.selectedCourse,
                        mode: .edit,
                        shouldTrackRoundSetup: viewModel.shouldTrackRoundSetup,
                        draftNotice: askAIDraftNotice,
                        onSave: { course, _, wasEdited in
                            Task {
                                await viewModel.saveCourseIfEdited(course: course, wasEdited: wasEdited)
                                showAskAIDraftEditor = false
                                showAskAI = false
                                viewModel.showConfirmation = true
                            }
                        }
                    )
                    .presentationDragIndicator(.visible)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
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
            .alert(
                "Are you sure you want to unset \(viewModel.modifyingCourse?.prettyCourseName ?? "this course") from this round?",
                isPresented: $showRemoveCourseAlert
            ) {
                Button("Remove", role: .destructive) {
                    onRemoveModification?()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You'll need to re-add it to set again.")
            }
        }
        .task {
            viewModel.shouldCommitSelectionAsModification = onModification != nil
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
        .onChange(of: locationService.authorizationStatus) { _, status in
            handleLocationAuthorizationChanged(status)
        }
        .alert("Location permissions required", isPresented: Binding(
            get: { locationSettingsAlertFlow != nil },
            set: { if !$0 { locationSettingsAlertFlow = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                locationSettingsAlertFlow = nil
            }
            Button("Go to settings") {
                openAppSettings()
                locationSettingsAlertFlow = nil
            }
        } message: {
            Text("Go to Settings > App > Location and turn on location permissions.")
        }
        .toast(isPresenting: $viewModel.isSearchingNearby) {
            .loader()
        }
        .toast(isPresenting: $viewModel.isLoadingSelectedCourse) {
            .loader()
        }
        .toast(isPresenting: $viewModel.showCourseFetchError) {
            .errorBanner("Couldn't load course", viewModel.courseFetchErrorMessage)
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
//                await viewModel.loadNearby(using: locationService.location)
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
        HStack(alignment: .center, spacing: 0) {
            PrimaryButton(
                appearance: .fill,
                title: "Skip",
                labelColor: courseSelectionPalette.foregroundColor,
                buttonColor: .neutral6,
                fillWidth: false,
                isDisabled: .constant(viewModel.isScanningScorecard),
                isLoading: .constant(false),
                onTap: {
                    Haptics.fire(.light)
                    showSimpleRoundSetup = true
                }
            )

            Spacer(minLength: 0)

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
                openAskAI()
            } label: {
                Label("Ask AI", systemImage: "sparkles")
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
        }
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

                if presentationType != .sheet {
                    NavButton(icon: "f00d", onTap: { dismiss() })
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }
            
            SearchBar(
                placeholder: "Search by course name",
                onDebounce: { text in
                    print("onDebounce \(text)")
                    searchText = text
                    viewModel.recoveryCourseName = nil
                    await viewModel.searchCourses(for: text, using: locationService.location)
                }
            )
            
            if searchText.isEmpty && viewModel.recoveryCourseName == nil {
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
            if searchText.isPopulated || viewModel.recoveryCourseName != nil {
                if let name = viewModel.recoveryCourseName {
                    Text("Choose a match for \(name) to confirm its current scorecard.")
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(Color.foregroundPrimary)
                        .alignLeading()
                    Button("Back to recent courses") {
                        viewModel.recoveryCourseName = nil
                    }
                }
                if viewModel.isSearching && viewModel.searchedCourses.isEmpty {
                    skeletonView
                } else if let error = viewModel.searchError {
                    if !viewModel.searchedCourses.isEmpty { list(for: viewModel.searchedCourses) }
                    Text(error)
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(Color.foregroundPrimary)
                        .alignLeading()
                    Button("Try again") {
                        Task {
                            await viewModel.searchCourses(for: viewModel.recoveryCourseName ?? searchText)
                        }
                    }
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

                        VStack(spacing: 12) {
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
                                openAskAI()
                            } label: {
                                Label("Ask AI", systemImage: "sparkles")
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
                VStack(alignment: .leading, spacing: 10) {
                    Text("Don’t see your course?").font(.subheadline).foregroundStyle(.secondary)
                    Button("Search more courses") {
                        Task { await viewModel.searchCourses(for: viewModel.recoveryCourseName ?? searchText,
                            using: locationService.location, searchMore: true) }
                    }
                    .disabled(viewModel.isSearching)
                    if viewModel.isSearching { ProgressView("Searching more courses…") }
                    if !viewModel.searchedCourses.isEmpty || viewModel.searchError != nil {
                        Button("Ask AI") { openAskAI() }
                        Menu("Scan scorecard") {
                            Button("Take photo") { showCamera = true }
                            Button("Choose photo") { showPhotoPicker = true }
                        }
                        Button("Enter manually") { viewModel.select(course: Course(origin: .manual), source: .manual) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
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
                
                HStack(spacing: 12) {
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

                    PrimaryButton(
                        appearance: .fill,
                        title: "Remove",
                        labelColor: .white,
                        buttonColor: .systemError,
                        fillWidth: false,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: {
                            showRemoveCourseAlert = true
                        }
                    )
                }
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
        } else if let error = viewModel.recentCoursesError {
            Text(error).font(.subheadline).foregroundStyle(.secondary)
            Button("Retry recent courses") { Task { await viewModel.loadRecents() } }
            list(for: viewModel.recentCourseEntries)
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
            Task { await viewModel.selectSearchCourse(course) }
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
        
        if !course.displayLocality.isEmpty { parts.append(course.displayLocality) }
        if let location = course.location {
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
        let shouldUseLocationAssist = resolvedScorecardLocationAssistEnabled()
        let approximateLocation = shouldUseLocationAssist
            ? locationService.location.map(ScorecardScanApproximateLocation.init)
            : nil
        showScorecardScanNotes = false

        Task {
            await viewModel.scanScorecard(
                image: image,
                scanContext: ScorecardScanContext(
                    notes: notes.isEmpty ? nil : notes,
                    isLocationAssistEnabled: shouldUseLocationAssist,
                    approximateLocation: approximateLocation
                ),
                vision: vision,
                scanSource: scanSource
            )

            pendingScorecardImage = nil
            pendingScorecardScanSource = nil
            scorecardScanNotes = ""
        }
    }

    private func locationAssistBinding(for flow: LocationAssistFlow) -> Binding<Bool> {
        Binding(
            get: {
                let storedValue: Bool = switch flow {
                case .scorecardScan:
                    scorecardLocationAssistEnabled
                case .askAI:
                    askAILocationAssistEnabled
                }

                switch locationService.authorizationStatus {
                case .authorizedAlways, .authorizedWhenInUse, .notDetermined:
                    return storedValue
                case .denied, .restricted:
                    return false
                @unknown default:
                    return false
                }
            },
            set: { newValue in
                handleLocationAssistToggleChange(newValue, for: flow)
            }
        )
    }

    private func handleLocationAssistToggleChange(_ newValue: Bool, for flow: LocationAssistFlow) {
        guard newValue else {
            setLocationAssistEnabled(false, for: flow)
            return
        }

        switch locationService.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            setLocationAssistEnabled(true, for: flow)
        case .notDetermined:
            setLocationAssistEnabled(true, for: flow)
            locationService.requestLocation()
        case .denied, .restricted:
            setLocationAssistEnabled(false, for: flow)
            locationSettingsAlertFlow = flow
        @unknown default:
            setLocationAssistEnabled(false, for: flow)
        }
    }

    private func setLocationAssistEnabled(_ enabled: Bool, for flow: LocationAssistFlow) {
        switch flow {
        case .scorecardScan:
            scorecardLocationAssistEnabled = enabled
        case .askAI:
            askAILocationAssistEnabled = enabled
        }
    }

    private func handleLocationAuthorizationChanged(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .denied, .restricted:
            scorecardLocationAssistEnabled = false
            askAILocationAssistEnabled = false
        case .notDetermined:
            return
        @unknown default:
            scorecardLocationAssistEnabled = false
            askAILocationAssistEnabled = false
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    private var askAIExamplePrompts: [String] {
        [
            "Pebble Beach in California", "PGA Frisco in Frisco, Texas", "East Lake in Atlanta, Georgia"
        ]
    }

    private var askAIDraftNotice: String {
        "We didn’t confidently confirm this course yet. Review these details before continuing. Any default hole values shown here are editable scaffolding, not confirmed course facts."
    }

    private var currentAskAILookupContext: AskAICourseLookupContext {
        let enabled = resolvedAskAILocationAssistEnabled()
        return AskAICourseLookupContext(
            isLocationAssistEnabled: enabled,
            approximateLocation: enabled ? locationService.location.map(ScorecardScanApproximateLocation.init) : nil,
            model: askAITextModel
        )
    }

    private func resolvedAskAILocationAssistEnabled() -> Bool {
        askAILocationAssistEnabled && locationService.authorizationStatus.isAuthorized
    }

    private func resolvedScorecardLocationAssistEnabled() -> Bool {
        scorecardLocationAssistEnabled && locationService.authorizationStatus.isAuthorized
    }

    private func openAskAI() {
        showAskAI = true
        if askAILocationAssistEnabled { locationService.requestLocation() }

        guard viewModel.shouldTrackRoundSetup else { return }
        addEvent(
            "round_setup.course_ask_ai_opened",
            eventProps: [
                "location_assist_enabled": resolvedAskAILocationAssistEnabled(),
                "has_approximate_location": resolvedAskAILocationAssistEnabled() && locationService.location != nil,
                "is_existing_round_change": viewModel.isModifying
            ]
        )
    }
}

private struct LocationAssistToggleRow: View {
    @Binding var isEnabled: Bool
    let title: String
    let subtitle: String
    let approximateLocation: ScorecardScanApproximateLocation?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(Color.foregroundPrimary)

                    Text(subtitle)
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .multilineTextAlignment(.leading)
                }
            }
            .tint(.accentGreen)

            if isEnabled, let approximateLocation {
                Text("Using approximate location near \(approximateLocation.promptDescription)")
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.neutral2)
            }
        }
    }
}

private struct ScorecardScanNotesSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var notes: String
    @Binding var isLocationAssistEnabled: Bool
    @Binding var selectedVision: ScorecardScanVisionModel
    let approximateLocation: ScorecardScanApproximateLocation?
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

            locationAssistRow

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

    @ViewBuilder
    private var locationAssistRow: some View {
        LocationAssistToggleRow(
            isEnabled: $isLocationAssistEnabled,
            title: "Use location",
            subtitle: "We'll use your current location to improve chat results and quality of response.",
            approximateLocation: approximateLocation
        )
    }
}

struct AskAICourseSheet: View {
    let messages: [AskAICourseChatMessage]
    let isSending: Bool
    @Binding var isLocationAssistEnabled: Bool
    let approximateLocation: ScorecardScanApproximateLocation?
    let examplePrompts: [String]
    var onCancel: Callback?
    var onSend: ((String) async -> Void)?
    var onUseCandidate: CallbackValue<AskAICourseCandidate>?
    var errorMessage: String?
    var onRetry: Callback?
    var onStop: Callback?
    var onStartOver: Callback?
    var selectedModel: AskAITextModel
    var onSelectModel: CallbackValue<AskAITextModel>?

    @State private var prompt: String
    @FocusState private var isPromptFocused: Bool

    init(
        messages: [AskAICourseChatMessage], isSending: Bool,
        isLocationAssistEnabled: Binding<Bool>,
        approximateLocation: ScorecardScanApproximateLocation?, examplePrompts: [String],
        initialPrompt: String = "", onCancel: Callback? = nil,
        onSend: ((String) async -> Void)? = nil,
        onUseCandidate: CallbackValue<AskAICourseCandidate>? = nil,
        errorMessage: String? = nil, onRetry: Callback? = nil,
        onStop: Callback? = nil, onStartOver: Callback? = nil,
        selectedModel: AskAITextModel = .defaultSelection,
        onSelectModel: CallbackValue<AskAITextModel>? = nil
    ) {
        self.messages = messages
        self.isSending = isSending
        _isLocationAssistEnabled = isLocationAssistEnabled
        self.approximateLocation = approximateLocation
        self.examplePrompts = examplePrompts
        self.onCancel = onCancel
        self.onSend = onSend
        self.onUseCandidate = onUseCandidate
        self.errorMessage = errorMessage
        self.onRetry = onRetry
        self.onStop = onStop
        self.onStartOver = onStartOver
        self.selectedModel = selectedModel
        self.onSelectModel = onSelectModel
        _prompt = State(initialValue: initialPrompt)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if messages.isEmpty {
                            messageBubble(.init(role: .assistant, text: "What course are you playing? Enter its name and, if you know it, the city or state."))
                            Text("Try a course name and location")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(examplePrompts, id: \.self) { example in
                                Button(example) { send(example) }
                                    .buttonStyle(.bordered).tint(.accentGreen)
                                    .disabled(isSending)
                            }
                        }
                        ForEach(messages) { message in
                            messageBubble(message)
                        }
                        if isSending {
                            HStack(spacing: 12) {
                                ProgressView().tint(.accentGreen)
                                Text("Finding your course…").font(.subheadline)
                            }
                            .padding(14)
                            .background(Color.neutral6, in: RoundedRectangle(cornerRadius: 16))
                            .accessibilityLabel("Finding your course")
                        }
                        if let errorMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(errorMessage).font(.subheadline)
                                Button("Retry search") { onRetry?() }
                                    .disabled(isSending)
                            }
                            .padding(14)
                            .background(Color.neutral6, in: RoundedRectangle(cornerRadius: 16))
                        }
                        if !isSending, errorMessage == nil, messages.last?.isUser == true {
                            Button("Continue search") { onRetry?() }
                                .buttonStyle(.bordered)
                        }
                        Color.clear.frame(height: 1).id("ASK_AI_BOTTOM")
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom, spacing: 0) { composer }
                .onAppear {
                    if !messages.isEmpty { proxy.scrollTo("ASK_AI_BOTTOM", anchor: .bottom) }
                }
                .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: isSending) { _, _ in scrollToBottom(proxy) }
                .onChange(of: errorMessage) { _, _ in scrollToBottom(proxy) }
                .onChange(of: isPromptFocused) { _, _ in scrollToBottom(proxy) }
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Find a course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { onCancel?() }
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Start over", systemImage: "arrow.counterclockwise") { onStartOver?() }
                        Toggle("Use my location", isOn: $isLocationAssistEnabled)
                        if let onSelectModel {
                            Picker("Assistant", selection: Binding(
                                get: { selectedModel }, set: { onSelectModel($0) }
                            )) {
                                ForEach(AskAITextModel.allCases) { model in
                                    Text(model.displayName).tag(model)
                                }
                            }
                            .disabled(isSending)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Conversation options")
                }
            }
        }
    }

    private func messageBubble(_ message: AskAICourseChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if message.isUser { Spacer(minLength: 40) }
                Text(message.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .foregroundStyle(message.isUser ? Color.white : Color.foregroundPrimary)
                    .padding(14)
                    .background(message.isUser ? Color.accentGreen : Color.neutral6,
                                in: RoundedRectangle(cornerRadius: 18))
                if !message.isUser { Spacer(minLength: 24) }
            }
            ForEach(Array(message.candidates.prefix(3).enumerated()), id: \.offset) { _, candidate in
                AskAICourseCandidateCard(candidate: candidate, onUse: { onUseCandidate?(candidate) })
                    .disabled(isSending)
            }
            if message.candidates.count > 3 {
                Text("More matches are available. Send the city or state to narrow the list.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isLocationAssistEnabled.toggle()
            } label: {
                Label(locationLabel, systemImage: isLocationAssistEnabled ? "location" : "location.slash")
                    .font(.caption)
            }
            .tint(.secondary)
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Course name and city, or a reply…", text: $prompt, axis: .vertical)
                    .font(.body)
                    .focused($isPromptFocused)
                    .lineLimit(1...5)
                    .padding(12)
                    .accessibilityIdentifier("courseChatInput")
                Button {
                    if isSending { onStop?() } else { send(prompt) }
                } label: {
                    Image(systemName: isSending ? "stop.fill" : "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.accentGreen, in: Circle())
                }
                .disabled(!isSending && prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(isSending || !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0.4)
                .accessibilityLabel(isSending ? "Stop search" : "Send message")
                .padding(4)
            }
            .background(Color.neutral6, in: RoundedRectangle(cornerRadius: 24))
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color.backgroundPrimary)
    }

    private var locationLabel: String {
        guard isLocationAssistEnabled else { return "Use my location" }
        return approximateLocation == nil ? "Location unavailable · you can type a city" : "Using approximate location"
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSending, !trimmed.isEmpty else { return }
        prompt = ""
        Task { await onSend?(trimmed) }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("ASK_AI_BOTTOM", anchor: .bottom) }
    }
}

private struct AskAICourseCandidateCard: View {
    let candidate: AskAICourseCandidate
    var onUse: Callback? = nil

    private var course: Course { candidate.course }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(course.prettyCourseName.isPopulated ? course.prettyCourseName : course.prettyClubName)
                    .font(.headline)
                    .foregroundStyle(Color.foregroundPrimary)

                if course.prettyClubName.isPopulated,
                   course.prettyClubName != course.prettyCourseName {
                    Text(course.prettyClubName)
                        .font(.subheadline)
                        .foregroundStyle(Color.neutral)
                }

                if let location = candidate.locationText ?? course.location.map({ [$0.city, $0.state].compactMap { $0 }.joined(separator: ", ") }),
                   !location.isEmpty {
                    Text(location)
                        .font(.subheadline)
                        .foregroundStyle(Color.neutral)
                }
            }

            if !candidate.needsScorecard, let tee = preferredSummaryTee {
                Text("\(tee.totalHoles) holes · \(course.tees.count) tees")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Par \(tee.par(for: course.defaultSegment)) · \(tee.yardage(for: course.defaultSegment)) yards · \(tee.name) tees")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            if let website = course.venueDetails?.websiteURL, website.isPopulated {
                Text(website)
                    .font(.caption)
                    .foregroundStyle(Color.accentGreen)
                    .lineLimit(1)
            }

            PrimaryButton(
                appearance: .fill,
                title: candidate.requiresReview ? "Review scorecard" : (candidate.needsScorecard ? "Choose course" : "Continue"),
                labelColor: .white,
                buttonColor: .accentGreen,
                fillWidth: true,
                isDisabled: .false,
                isLoading: .false,
                onTap: { onUse?() }
            )
        }
        .padding(12)
        .background(Color.backgroundPrimary)
        .cornerRadius(radius: 14)
    }

    private var preferredSummaryTee: Tee? {
        if let male = course.tees.male.first {
            return male
        }
        if let other = course.tees.other.first {
            return other
        }
        return course.tees.first
    }


}

private struct SimpleRoundSetupSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    private enum HoleCountOption: String, CaseIterable, Identifiable {
        case nine
        case eighteen
        case custom

        var id: String { rawValue }

        var label: String {
            switch self {
            case .nine: return "9"
            case .eighteen: return "18"
            case .custom: return "Custom"
            }
        }
    }

    private let initialValue: SimpleRoundSetup
    private let onCancel: Callback?
    private let onContinue: CallbackValue<SimpleRoundSetup>?

    @State private var courseName: String
    @State private var holeCountOption: HoleCountOption
    @State private var holeCount: Int
    @State private var startingHole: Int
    @State private var showCustomHoleCountSheet = false

    init(
        initialValue: SimpleRoundSetup,
        onCancel: Callback? = nil,
        onContinue: CallbackValue<SimpleRoundSetup>? = nil
    ) {
        self.initialValue = initialValue
        self.onCancel = onCancel
        self.onContinue = onContinue

        let initialOption: HoleCountOption
        switch initialValue.holeCount {
        case 9:
            initialOption = .nine
        case 18:
            initialOption = .eighteen
        default:
            initialOption = .custom
        }

        _courseName = State(initialValue: initialValue.courseName)
        _holeCountOption = State(initialValue: initialOption)
        _holeCount = State(initialValue: initialValue.holeCount)
        _startingHole = State(initialValue: min(max(initialValue.startingHole, 1), max(initialValue.holeCount, 1)))
    }

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var isCourseNameEmpty: Bool {
        courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Skip course data")
                        .fontStyle(kFontName, size: 22, weight: .semibold)
                        .foregroundStyle(Color.foregroundPrimary)

                    Text("Play a round using friendly net scoring (par = 0, birdie = -1, bogey = 1).")
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                NavButton(icon: "f00d", theme: .primary, onTap: { onCancel?() })
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text("Course or round name")
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(Color.foregroundPrimary)

                        Spacer(minLength: 0)

                        if isCourseNameEmpty {
                            Chip.required
                        } else {
                            Chip.requiredSuccess
                        }
                    }

                    TextField("Enter course or round name", text: $courseName)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.foregroundPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.neutral6)
                        .cornerRadius(radius: 12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Number of holes")
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(Color.foregroundPrimary)

                    HStack(spacing: 10) {
                        ForEach(HoleCountOption.allCases) { option in
                            Button {
                                Haptics.fire(.light)
                                select(option: option)
                            } label: {
                                Text(option.label)
                                    .fontStyle(kFontName, size: 14, weight: .semibold)
                                    .foregroundStyle(holeCountOption == option ? .white : Color.foregroundPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(holeCountOption == option ? Color.accentGreen : Color.neutral6)
                                    .cornerRadius(radius: 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if holeCountOption == .custom {
                        Button {
                            Haptics.fire(.light)
                            showCustomHoleCountSheet = true
                        } label: {
                            HStack {
                                Text("Custom hole count")
                                    .fontStyle(kFontName, size: 14, weight: .medium)
                                    .foregroundStyle(Color.foregroundPrimary)

                                Spacer(minLength: 0)

                                Text("\(holeCount)")
                                    .fontStyle(kFontName, size: 14, weight: .semibold)
                                    .foregroundStyle(Color.accentGreen)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.neutral6)
                            .cornerRadius(radius: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: 8) {
                Text("Starting hole")
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(Color.foregroundPrimary)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(1...max(holeCount, 1), id: \.self) { hole in
                            Button {
                                Haptics.fire(.light)
                                startingHole = hole
                            } label: {
                                Text("\(hole)")
                                    .fontStyle(kFontName, size: 14, weight: .semibold)
                                    .foregroundStyle(startingHole == hole ? .white : Color.foregroundPrimary)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .padding(.horizontal, 4)
                                    .background(startingHole == hole ? Color.accentGreen : Color.neutral6)
                                    .cornerRadius(radius: 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 20)
                    .padding(.vertical, 4)
                }
            }
            .padding(.top, 8)

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
                    title: "Continue",
                    labelColor: .backgroundPrimary,
                    buttonColor: .foregroundPrimary,
                    fillWidth: true,
                    isDisabled: Binding(
                        get: { isCourseNameEmpty },
                        set: { _ in }
                    ),
                    isLoading: .false,
                    onTap: {
                        onContinue?(SimpleRoundSetup(
                            courseName: courseName,
                            holeCount: holeCount,
                            startingHole: startingHole
                        ))
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(palette.backgroundColor)
        .sheet(isPresented: $showCustomHoleCountSheet) {
            CustomHoleCountSheet(
                holeCount: holeCount,
                onCancel: { showCustomHoleCountSheet = false },
                onSave: { value in
                    holeCount = min(max(value, 1), 18)
                    startingHole = min(max(startingHole, 1), holeCount)
                    showCustomHoleCountSheet = false
                }
            )
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: holeCount) { _, newValue in
            startingHole = min(max(startingHole, 1), max(newValue, 1))
        }
    }

    private func select(option: HoleCountOption) {
        holeCountOption = option
        switch option {
        case .nine:
            holeCount = 9
        case .eighteen:
            holeCount = 18
        case .custom:
            holeCount = initialValue.holeCount == 9 || initialValue.holeCount == 18
                ? 12
                : initialValue.holeCount
            showCustomHoleCountSheet = true
        }
        startingHole = min(max(startingHole, 1), holeCount)
    }
}

private struct CustomHoleCountSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var text: String
    private let onCancel: Callback?
    private let onSave: CallbackValue<Int>?

    init(
        holeCount: Int,
        onCancel: Callback? = nil,
        onSave: CallbackValue<Int>? = nil
    ) {
        _text = State(initialValue: "\(holeCount)")
        self.onCancel = onCancel
        self.onSave = onSave
    }

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom holes")
                .fontStyle(kFontName, size: 20, weight: .semibold)
                .foregroundStyle(Color.foregroundPrimary)

            Text("Enter a value from 1 to 18.")
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)

            TextField("Hole count", text: $text)
                .keyboardType(.numberPad)
                .fontStyle(kFontName, size: 15, weight: .regular)
                .foregroundStyle(Color.foregroundPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.neutral6)
                .cornerRadius(radius: 12)

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
                    title: "Save",
                    labelColor: .backgroundPrimary,
                    buttonColor: .foregroundPrimary,
                    fillWidth: true,
                    isDisabled: .constant(Int(text) == nil),
                    isLoading: .false,
                    onTap: {
                        guard let value = Int(text) else { return }
                        onSave?(min(max(value, 1), 18))
                    }
                )
            }
        }
        .padding(20)
        .background(palette.backgroundColor)
    }
}

private enum AskAICourseSheetPreviewData {
    static let prompts = [
        "I’m playing Oxmoor Valley on the RTJ Trail in Alabama.",
        "I’m at Twin Lakes in Austin and I think it’s the North course.",
        "I’m playing a municipal course in Greenville with a blue and gold scorecard."
    ]

    static let approximateLocation = ScorecardScanApproximateLocation(latitude: 34.85, longitude: -82.39)

    static let sampleTee = Tee(
        name: "Blue",
        gender: Gender.male.rawValue,
        totalHoles: 18,
        holes: (1...18).map { holeNumber in
            Hole(number: holeNumber, par: holeNumber == 18 ? 5 : 4, yardage: 360 + (holeNumber * 7), handicap: nil)
        },
        ratingFull: 72.0,
        slopeFull: 128,
        ratingFront: nil,
        slopeFront: nil,
        ratingBack: nil,
        slopeBack: nil
    )

    static let sampleCourse = Course(
        golfCourseApiID: 101,
        origin: .golfCourseAPI,
        clubName: "Twin Lakes Golf Club",
        courseName: "North Course",
        tees: [sampleTee]
    )

    static let messages: [AskAICourseChatMessage] = [
        .init(role: .user, text: "I’m at Twin Lakes in Austin and I think it’s the North course."),
        .init(
            role: .assistant,
            text: "I found a strong match for Twin Lakes Golf Club. Review it below or keep chatting if you want me to refine the details.",
            candidate: .init(
                course: sampleCourse,
                requiresReview: false,
                isCanonicalMatch: true,
                sources: [.internet, .golfCourseAPI]
            )
        )
    ]
}

#Preview {
    CourseSelectionView(viewModel: .init())
        .environmentObject(AppSession())
        .environmentObject(LocationService())
}

#Preview("Ask AI Empty") {
    AskAICourseSheet(
        messages: [],
        isSending: false,
        isLocationAssistEnabled: .constant(true),

        approximateLocation: AskAICourseSheetPreviewData.approximateLocation,
        examplePrompts: AskAICourseSheetPreviewData.prompts
    )
}

#Preview("Ask AI Conversation") {
    AskAICourseSheet(
        messages: AskAICourseSheetPreviewData.messages,
        isSending: false,
        isLocationAssistEnabled: .constant(false),

        approximateLocation: AskAICourseSheetPreviewData.approximateLocation,
        examplePrompts: AskAICourseSheetPreviewData.prompts
    )
}

#Preview("Ask AI Draft Composer") {
    AskAICourseSheet(
        messages: AskAICourseSheetPreviewData.messages,
        isSending: false,
        isLocationAssistEnabled: .constant(true),

        approximateLocation: AskAICourseSheetPreviewData.approximateLocation,
        examplePrompts: AskAICourseSheetPreviewData.prompts,
        initialPrompt: "I’m pretty sure this is a municipal course in Greenville.\nThe scorecard is blue and gold.\nCan you help me narrow it down?"
    )
}

#Preview("Scan notes") {
    CourseSelectionView(viewModel: .init())
        .environmentObject(AppSession())
        .environmentObject(LocationService())
        .sheet(isPresented: .true) {
            ScorecardScanNotesSheet(
                notes: .blank,
                isLocationAssistEnabled: .constant(true),
                selectedVision: .constant(.defaultSelection),
                approximateLocation: .init(latitude: 34.85, longitude: -82.39)
            )
            .presentationDetents([.height(460)])
            .presentationDragIndicator(.visible)
        }
}
