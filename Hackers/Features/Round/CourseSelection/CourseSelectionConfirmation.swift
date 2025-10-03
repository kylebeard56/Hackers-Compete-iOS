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
    @State private var teeGender: Gender = .male
    
    private var course: Course { viewModel.selectedCourse }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack {
                    CourseMapView(
                        latitude: course.location?.latitude ?? 0,
                        longitude: course.location?.longitude ?? 0,
                        meters: 600
                    )

                    NavButton(icon: "f00d", onTap: { dismiss() })
                        .alignTop()
                        .alignTrailing()
                        .padding(16)
                }
                .frame(height: 200)
                
//                if let location = course.location {
//                    CourseMapView(
//                        latitude: location.latitude,
//                        longitude: location.longitude,
//                        meters: 600
//                    )
//                    .frame(height: 200)
//                }
                
                Group {
                    if course.isEmpty {
                        Text("Unexpected error occurred")
                            .fontStyle(.poppins, size: 15, weight: .medium)
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
            .navigationBarTitleDisplayMode(.inline)
            .edgesIgnoringSafeArea(.top)
//            .toolbar {
//                ToolbarItem(placement: .topBarLeading) {
//                    Button(action: { dismiss() }) {
//                        Image(systemName: "xmark")
//                            .font(.system(size: 16, weight: .semibold))
//                    }
//                }
//            }
            .onAppear() {
                viewModel.holeSegment = course.defaultSegment
            }
            .sheet(isPresented: $showTeeSelection) {
                TeeSelectionSheet(
                    selectedTee: viewModel.selectedTee,
                    maleTees: course.tees.male,
                    femaleTees: course.tees.female,
                    segment: viewModel.holeSegment,
                    onChange: { tee in
                        showTeeSelection = false
                        if viewModel.selectedTee == tee {
                            viewModel.selectedTee = nil
                        } else {
                            viewModel.selectedTee = tee
                        }
                    }
                )
                .presentationDragIndicator(.visible)
            }
            .toast(isPresenting: $viewModel.showRoundCreationError) {
                .errorBanner("Failed to continue - please try again")
            }
        }
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(course.prettyClubName)
                    .fontStyle(.poppins, size: 24, weight: .semibold)
                    .foregroundStyle(Color.foregroundPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .alignLeading()
                
                if let location = course.location {
                    HStack {
                        Text(location.trimmedAddress)
                            .fontStyle(.poppins, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral)

                        if locationService.authorizationStatus.isAuthorized {
                            Dot()
                            
                            Text(location.formattedDistance(to: locationService.location))
                                .fontStyle(.poppins, size: 13, weight: .regular)
                                .foregroundStyle(Color.neutral)
                        }

                        Spacer(minLength: 0)
                    }
                }
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
            
            Text("Tees")
                .fontStyle(.poppins, size: 15, weight: .semibold)
                .foregroundStyle(Color.foregroundPrimary)
                .alignLeading()
            
            teeDropdown
            
            Text("You can choose different tees for each player in the game lobby before your round.")
                .fontStyle(.poppins, size: 13, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.leading)
                .alignLeading()
            
            Spacer(minLength: 0)
            
            PrimaryButton(
                appearance: .fill,
                title: "Continue",
                labelColor: .backgroundPrimary,
                buttonColor: .foregroundPrimary,
                isDisabled: .false,
                isLoading: $viewModel.isCreatingRound,
                onTap: {
                    Task { await viewModel.createRoundLobby() }
                }
            )
        }
    }
    
    // MARK: - Tee Selection
    
    private var teeDropdown: some View {
        Button(action: {
            Haptics.fire(.light)
            showTeeSelection = true
        }) {
            HStack {
                if let tee = viewModel.selectedTee {
                    TeeRow(tee: tee, showDifficulty: false, segment: viewModel.holeSegment)
                    //teeDisplay(for: tee, showDifficulty: false)
                } else {
                    Text("Select default tee")
                        .fontStyle(.poppins, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer()
                
                Icon(name: "f078", size: 12, weight: .solid)
                    .foregroundStyle(Color.neutral3)
            }
            .padding(16)
            .border(Color.neutral5, width: 1.5, cornerRadius: 10)
        }
    }
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
