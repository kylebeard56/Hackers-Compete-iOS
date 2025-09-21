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
    @StateObject var viewModel = CourseSelectionViewModel()
    
    @State private var searchText: String = ""
    @State private var didSearchNearby = false
    
    private let kGreenville = CLLocation(latitude: 34.851, longitude: -82.394)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Text("Pick your course")
                        .fontStyle(.poppins, size: 24, weight: .semibold)
                        .foregroundStyle(Color.systemBlack)
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
                
                if searchText.isPopulated {
                    if viewModel.isSearching {
                        skeletonView
                    } else if viewModel.searchedCourses.isPopulated {
                        let count = viewModel.searchedCourses.count
                        Text("\(count) course\(count.pluralized) found")
                            .fontStyle(.poppins, size: 13, weight: .semibold)
                            .foregroundStyle(Color.hackersGray)
                            .alignLeading()
                        list(for: viewModel.searchedCourses)
                    } else {
                        Text("No courses found")
                            .fontStyle(.poppins, size: 15, weight: .medium)
                            .foregroundStyle(Color.hackersGray)
                            .alignCenter()
                        
                        Text("Scan scorecard or enter manually")
                            .fontStyle(.poppins, size: 15, weight: .semibold)
                            .foregroundStyle(Color.hackersGreen)
                            .alignCenter()
                    }
                } else {
                    suggestiveStateView
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .background(Color.hackersBackground)
        }
        .task {
            await viewModel.loadRecents()
        }
        .toast(isPresenting: $viewModel.isSearchingNearby) {
            .loader()
        }
        .onReceive(viewModel.$roundCreationID, perform: { value in
            if value.isPopulated {
                appSession.activeRoundID = value
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
//            guard !didSearchNearby else { return }
//            Task {
//                await viewModel.loadNearby(using: kGreenville)
//            }
        })
        .onReceive(HackersNotification.locationAuthorizationChanged.publisher(), perform: { data in
            if let status = data.object as? CLAuthorizationStatus,
               let location = locationService.location,
               status.isAuthorized,
               viewModel.nearbyCourses.isEmpty {
                Task {
                    await viewModel.loadNearby(using: location)
                }
            }
        })
        .sheet(isPresented: $viewModel.showConfirmation) {
            CourseSelectionConfirmation(viewModel: viewModel)
        }
    }
    
    // MARK: - Chips
    
    @ViewBuilder
    private var suggestiveStateView: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(CourseSelectionChip.allCases, id: \.self) { chip in
                        let match = chip == viewModel.selectedChip
                        Button(action: {
                            Haptics.fire(.light)
                            viewModel.selectedChip = chip
                        }) {
                            Chip(text: chip.rawValue,
                                 foreground: match ? .white : .hackersForeground,
                                 background: match ? .hackersGreen : .hackersGray6
                            )
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            
            if viewModel.selectedChip == .recent {
                recentCourses
            }
            
            if viewModel.selectedChip == .nearby {
                nearbyCourses
            }
            
            if viewModel.selectedChip == .favorite {
                Spacer()
                Text("Favorite courses coming soon")
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(Color.hackersGray)
                    .alignCenter()
                Spacer()
            }
        }
    }
    
    // MARK: - Recent
    
    @ViewBuilder
    private var recentCourses: some View {
        if viewModel.isLoadingRecents {
            skeletonView
        } else if viewModel.recentCourses.isPopulated {
            list(for: viewModel.recentCourses)
        } else {
            Spacer()
            Text("No recent courses")
                .fontStyle(.poppins, size: 15, weight: .medium)
                .foregroundStyle(Color.hackersGray)
                .alignCenter()
            Spacer()
        }
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
                    .fontStyle(.poppins, size: 15, weight: .medium)
                    .foregroundStyle(Color.hackersGray)
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
    
    private func list(for courses: [Course]) -> some View {
        ScrollView(showsIndicators: false) {
            ForEach(courses, id: \.id) { course in
                row(for: course)
            }
        }
    }
    
    private func list(for courses: [GolfCoursePlacemark]) -> some View {
        ScrollView(showsIndicators: false) {
            ForEach(courses, id: \.id) { course in
                row(for: course)
            }
        }
    }
    
    private func row(for course: Course) -> some View {
        Button(action: {
            Haptics.fire(.light)
            viewModel.select(course: course)
        }) {
            VStack {
                HStack(spacing: 16) {
                    Icon(name: "f3c5", size: 15, weight: .solid)
                        .foregroundStyle(Color.hackersGray4)
                    
                    VStack(spacing: 2) {
                        Text(course.prettyCourseName)
                            .fontStyle(.poppins, size: 17, weight: .medium)
                            .foregroundStyle(Color.systemBlack)
                            .multilineTextAlignment(.leading)
                            .alignLeading()

                        HStack(spacing: 8) {
                            ForEach(Array(rowComponents(from: course).enumerated()), id: \.offset) { index, part in
                                if index > 0 {
                                    Dot()
                                }
                                Text(part)
                                    .fontStyle(.poppins, size: 13, weight: .regular)
                                    .foregroundStyle(Color.hackersGray)
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
                        .foregroundStyle(Color.hackersGray4)
                    
                    VStack {
                        Text("\(course.name)")
                            .fontStyle(.poppins, size: 17, weight: .medium)
                            .foregroundStyle(Color.systemBlack)
                            .multilineTextAlignment(.leading)
                            .alignLeading()
                        
                        Text(course.formattedDistance)
                            .fontStyle(.poppins, size: 13, weight: .regular)
                            .foregroundStyle(Color.hackersGray)
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
    CourseSelectionView()
        .environmentObject(AppSession())
        .environmentObject(LocationService())
}
