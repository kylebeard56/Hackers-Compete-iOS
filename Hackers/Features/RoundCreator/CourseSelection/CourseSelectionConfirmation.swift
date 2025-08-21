//
//  CourseSelectionConfirmation.swift
//  Hackers
//
//  Created by Kyle Beard on 8/9/25.
//

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
//                ZStack {
//                    CourseMapView(
//                        latitude: course.location.latitude,
//                        longitude: course.location.longitude,
//                        meters: 600
//                    )
//                    .frame(height: 200)
//    
//                    NavButton(icon: "f00d", onTap: { dismiss() })
//                        .alignTop()
//                        .alignTrailing()
//                        .padding(16)
//                }
//                .frame(height: 200)
                
                if let location = course.location {
                    CourseMapView(
                        latitude: location.latitude,
                        longitude: location.longitude,
                        meters: 600
                    )
                    .frame(height: 200)
                }
                
                Group {
                    if course.isEmpty {
                        Text("Unexpected error occurred")
                            .fontStyle(.poppins, size: 15, weight: .medium)
                            .foregroundStyle(Color.hackersGray)
                            .alignCenter()
                            .alignMiddle()
                    } else {
                        content
                    }
                }
                .padding(.horizontal, 16)
            }
            .background(Color.hackersBackground)
            .navigationBarTitleDisplayMode(.inline)
            .edgesIgnoringSafeArea(.top)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .accessibilityLabel("Close")
                }
            }
            .onAppear() {
                viewModel.holeSegment = course.defaultSegment
            }
            .sheet(isPresented: $showTeeSelection) {
                teeSelectionSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(course.prettyClubName)
                    .fontStyle(.poppins, size: 24, weight: .semibold)
                    .foregroundStyle(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .alignLeading()
                
                if let location = course.location {
                    HStack {
                        Text(location.trimmedAddress)
                            .fontStyle(.poppins, size: 13, weight: .regular)
                            .foregroundStyle(Color.hackersGray)

                        Dot()
                        
                        Text(location.formattedDistance(to: locationService.location))
                            .fontStyle(.poppins, size: 13, weight: .regular)
                            .foregroundStyle(Color.hackersGray)
                        
                        Spacer()
                    }
                }
            }

            Line()
            
            Picker("Holes", selection: $viewModel.holeSegment) {
                ForEach(course.availableSegments, id: \.self) { segment in
                    Text(segment.title)
                        .tag(segment)
                }
            }
            .pickerStyle(.segmented)
            
            Line()
            
            Text("Tees")
                .fontStyle(.poppins, size: 15, weight: .semibold)
                .foregroundStyle(Color.systemBlack)
                .alignLeading()
            
            teeDropdown
            
            Text("You can choose different tees for each player in the game lobby before your round.")
                .fontStyle(.poppins, size: 13, weight: .regular)
                .foregroundStyle(Color.hackersGray)
                .multilineTextAlignment(.leading)
                .alignLeading()
            
            Spacer()
            
            PrimaryButton(
                appearance: .fill,
                title: "Continue",
                labelColor: .systemWhite,
                buttonColor: .systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    print("todo: go to game lobby")
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
                Text("Select default tee")
                    .fontStyle(.poppins, size: 15, weight: .regular)
                    .foregroundStyle(Color.hackersGray)
                Spacer()
                Icon(name: "f078", size: 12, weight: .solid)
                    .foregroundStyle(Color.hackersGray3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .border(Color.hackersGray5, width: 1.5, cornerRadius: 10)
        }
    }
    
    // TODO: Read below
    // Display different values if selecting full18, front9, back9 for slope/course/difficulty
    private var teeSelectionSheet: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer().frame(height: 0)
                
                VStack(spacing: 4) {
                    Text("Select your default tee")
                        .fontStyle(.poppins, size: 20, weight: .semibold)
                        .foregroundStyle(Color.systemBlack)
                        .alignLeading()
                    
                    Text("Pick the default tee for your group based on yardage, course/slope rating, and normalized difficulty.")
                        .fontStyle(.poppins, size: 13, weight: .regular)
                        .foregroundStyle(Color.hackersGray)
                        .multilineTextAlignment(.leading)
                        .alignLeading()
                }

                Picker("Gender", selection: $teeGender) {
                    ForEach([Gender.male, Gender.female]) { gender in
                        Text(gender.name)
                            .tag(gender)
                    }
                }
                .pickerStyle(.segmented)
                
                if course.tees.male.isPopulated, teeGender == .male {
                    ForEach(course.tees.male.sortedByDifficulty(for: viewModel.holeSegment), id: \.id) { tee in
                        display(for: tee, isSelected: false)
                    }
                }
                if course.tees.female.isPopulated, teeGender == .female {
                    ForEach(course.tees.female.sortedByDifficulty(for: viewModel.holeSegment), id: \.id) { tee in
                        display(for: tee, isSelected: false)
                    }
                }

            }
            .padding(16)
        }
    }
    
    @ViewBuilder
    private func display(for tee: Tee, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(tee.name)
                    .fontStyle(.poppins, size: 15, weight: .semibold)
                    .foregroundStyle(Color.systemBlack)
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(tee.difficultyScore(for: viewModel.holeSegment))")
                        .fontStyle(.poppins, size: 13, weight: .medium)
                    Icon(name: "f06d", size: 13, weight: .regular)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .foregroundStyle(tee.difficultyColor(for: viewModel.holeSegment))
                .background(tee.difficultyColor(for: viewModel.holeSegment).opacity(colorScheme.translucent))
                .cornerRadius(radius: 6)
            }
            
            HStack {
                Text("Par \(tee.par(for: viewModel.holeSegment))")
                    .fontStyle(.poppins, size: 13, weight: .regular)
                    .foregroundStyle(Color.hackersGray)
                    
                Dot()
                
                Text("\(tee.yardage(for: viewModel.holeSegment)) yards")
                    .fontStyle(.poppins, size: 13, weight: .regular)
                    .foregroundStyle(Color.hackersGray)
                    
                if let rating = tee.prettyRating(for: viewModel.holeSegment),
                   let slope = tee.slope(for: viewModel.holeSegment) {
                    Dot()
                    Text("\(rating) / \(slope)")
                        .fontStyle(.poppins, size: 13, weight: .regular)
                        .foregroundStyle(Color.hackersGray)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .border(Color.hackersGray5, width: 1.5, cornerRadius: 10)
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
