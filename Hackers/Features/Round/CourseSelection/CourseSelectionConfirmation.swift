//
//  CourseSelectionConfirmation.swift
//  Hackers
//
//  Created by Kyle Beard on 8/9/25.
//

import AlertToast
import SwiftUI

struct CourseSelectionConfirmation: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var locationService: LocationService
    
    @StateObject var viewModel: CourseSelectionViewModel
    
    @State private var showTeeSelection = false
    @State private var showCourseEdit = false
    @State private var teeGender: Gender = .male
    
    private var course: Course { viewModel.selectedCourse }
    /// Prefer club name, then course name, then first tee label; avoids a blank header when OCR omits names.
    private var confirmationTitle: String {
        let club = course.prettyClubName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !club.isEmpty { return club }
        let name = course.prettyCourseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        if let firstTee = course.tees.first?.name.trimmingCharacters(in: .whitespacesAndNewlines), !firstTee.isEmpty {
            return firstTee
        }
        return "Scanned course"
    }
    private var disableRoundCreation: Bool { viewModel.selectedTee == nil && course.tees.isPopulated }
    private var hasMapLocation: Bool {
        guard let loc = course.location else { return false }
        return loc.latitude != 0 || loc.longitude != 0
    }
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                if hasMapLocation, let loc = course.location {
                    CourseMapView(
                        latitude: loc.latitude,
                        longitude: loc.longitude,
                        meters: 600
                    )
                } else {
                    BackgroundTheme(palette: palette, theme: .course)
                        .clipped()
                }
            }
            .frame(height: 200)
            .clipped()
            
            Group {
                if course.isEmpty {
                    Text("Unexpected error occurred")
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .alignCenter()
                        .alignMiddle()
                } else {
                    content
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Color.backgroundPrimary)
//        .edgesIgnoringSafeArea(.top)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
            }

            if viewModel.modifyingCourse.exists {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { viewModel.globalDismiss = true }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }
        .onAppear() {
            viewModel.holeSegment = course.defaultSegment
        }
        .sheet(isPresented: $showCourseEdit) {
            CourseEditView(
                course: viewModel.selectedCourse,
                mode: .edit,
                onSave: { course, _, wasEdited in
                    Task {
                        await viewModel.saveCourseIfEdited(course: course, wasEdited: wasEdited)
                        showCourseEdit = false
                    }
                }
            )
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTeeSelection) {
            TeeSelectionSheet(
                selectedTee: viewModel.selectedTee,
                maleTees: course.tees.male,
                femaleTees: course.tees.female,
                otherTees: course.tees.other,
                segment: viewModel.holeSegment,
                onChange: { tee in
                    showTeeSelection = false
                    viewModel.selectedTee = tee //.toggle(to: tee)
                }
            )
            .presentationDragIndicator(.visible)
        }
        .toast(isPresenting: $viewModel.showRoundCreationError) {
            .errorBanner("Failed to continue - please try again")
        }
    }
    
    private var buttonTitle: String {
        if viewModel.isSetHomeCourseMode {
            "Set as home course"
        } else if viewModel.isSetSeriesDefaultCourseMode {
            "Set as default course"
        } else if viewModel.isSetSeriesRoundCourseMode {
            "Continue"
        } else if viewModel.selectedCourse == viewModel.modifyingCourse {
            "Update course"
        } else if viewModel.isModifying {
            "Change course"
        } else {
            "Continue"
        }
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 4) {
                    Text(confirmationTitle)
                        .fontStyle(kFontName, size: 24, weight: .semibold)
                        .foregroundStyle(Color.foregroundPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .alignLeading()
                    
                    if let location = course.location {
                        HStack {
                            Text(location.trimmedAddress)
                                .fontStyle(kFontName, size: 14, weight: .regular)
                                .foregroundStyle(Color.neutral)

                            if locationService.authorizationStatus.isAuthorized {
                                Dot()
                                
                                Text(location.formattedDistance(to: locationService.location))
                                    .fontStyle(kFontName, size: 14, weight: .regular)
                                    .foregroundStyle(Color.neutral)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Haptics.fire(.light)
                    showCourseEdit = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.neutral6)
                            .frame(width: 40, height: 40)
                        Icon(name: "f044", size: 18, weight: .regular)
                            .foregroundStyle(Color.foregroundPrimary)
                    }
                }
                .buttonStyle(.plain)
            }

            Line()
            
            Picker("Holes", selection: $viewModel.holeSegment) {
                ForEach(course.availableSegments, id: \.self) { segment in
                    Text(segment.title)
                        .foregroundStyle(Color.foregroundPrimary)
                        .tag(segment)
                }
            }
            .pickerStyle(.segmented)
            
            Line()
            
            HStack {
                Text("Tees")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(Color.foregroundPrimary)
                
                Spacer(minLength: 0)
                
                if disableRoundCreation {
                    Chip.required
                }
            }
            
            TeeDropdown(
                tee: viewModel.selectedTee,
                segment: viewModel.holeSegment,
                onTap: { showTeeSelection = true }
            )
            
            Text("You can choose different tees for each player in the game lobby before your round.")
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.leading)
                .alignLeading()
            
            Spacer(minLength: 0)
            
            HStack(spacing: 16) {
                if viewModel.modifyingCourse.exists {
                    PrimaryButton(
                        appearance: .fill,
                        title: "Pick new",
                        labelColor: .foregroundPrimary,
                        buttonColor: .neutral6,
                        fillWidth: false,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: {
                            dismiss()
                        }
                    )
                }
                
                PrimaryButton(
                    appearance: .fill,
                    title: buttonTitle,
                    labelColor: .backgroundPrimary,
                    buttonColor: .foregroundPrimary,
                    fillWidth: true,
                    isDisabled: .constant(disableRoundCreation),
                    isLoading: $viewModel.isCreatingRound || $viewModel.modificationRequested,
                    onTap: {
                        if viewModel.isSetHomeCourseMode, let callback = viewModel.onSetHomeCourse {
                            let course = viewModel.selectedCourse
                            let apiID = course.golfCourseApiID ?? 0
                            let name = course.prettyCourseName
                            let teeID = viewModel.selectedTee?.id
                            let teeName = viewModel.selectedTee?.name
                            callback(apiID, name, teeID, teeName)
                        } else if viewModel.isSetSeriesDefaultCourseMode, let callback = viewModel.onSetSeriesDefaultCourse {
                            let course = viewModel.selectedCourse
                            let courseID = course.golfCourseApiID != nil ? String(course.golfCourseApiID!) : course.id
                            let cachedName = course.prettyCourseName
                            let teeID = viewModel.selectedTee?.id
                            callback(courseID, cachedName, teeID)
                        } else if viewModel.isSetSeriesRoundCourseMode, let callback = viewModel.onSetSeriesRoundCourse {
                            callback(viewModel.buildCourseSegment())
                        } else if viewModel.isModifying {
                            viewModel.confirmCourseModification()
                        } else {
                            Task { await viewModel.createRoundLobby() }
                        }
                    }
                )
            }

        }
    }
    
    // MARK: - Tee Selection
    
//    private var teeDropdown: some View {
//        Button(action: {
//            Haptics.fire(.light)
//            showTeeSelection = true
//        }) {
//            HStack {
//                if let tee = viewModel.selectedTee {
//                    TeeRow(tee: tee, showDifficulty: false, segment: viewModel.holeSegment)
//                } else {
//                    Text("Select default tee")
//                        .fontStyle(kFontName, size: 15, weight: .regular)
//                        .foregroundStyle(Color.neutral)
//                }
//
//                Spacer()
//                
//                Icon(name: "f078", size: 12, weight: .solid)
//                    .foregroundStyle(Color.neutral3)
//            }
//            .padding(16)
//            .border(Color.neutral5, width: 1.5, cornerRadius: 10)
//        }
//    }
}

@MainActor
private enum Mock {
    static func viewModel(for course: GolfCourseAPIModel) -> CourseSelectionViewModel {
        let vm = CourseSelectionViewModel()
        vm.selectedCourse = Course(from: course)
        return vm
    }
    
    static let locationService: LocationService = {
        let ls = LocationService()
        ls.location = MockLocations.greenville
        return ls
    }()
}

#Preview("Mountain Park") {
    ZStack { }.sheet(isPresented: .true) {
        CourseSelectionConfirmation(viewModel: Mock.viewModel(for: MockCourses.mountainPark))
            .presentationDragIndicator(.visible)
    }
    .environmentObject(AppSession())
    .environmentObject(Mock.locationService)
}

#Preview("3's Greenville") {
    ZStack { }.sheet(isPresented: .true) {
        CourseSelectionConfirmation(viewModel: Mock.viewModel(for: MockCourses.threesGreenville))
            .presentationDragIndicator(.visible)
    }
    .environmentObject(AppSession())
    .environmentObject(Mock.locationService)
}
