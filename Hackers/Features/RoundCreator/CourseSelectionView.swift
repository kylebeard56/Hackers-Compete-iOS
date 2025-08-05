//
//  CourseSelectionView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/2/25.
//

import SwiftUI

struct CourseSelectionView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel = CourseSelectionViewModel()
    
    @State private var searchText: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("Step 1 of 4")
                        .fontStyle(.poppins, size: 13, weight: .regular)
                        .foregroundStyle(Color.hackersGray)
                        .alignLeading()
                    
                    Text("Pick your course")
                        .fontStyle(.poppins, size: 24, weight: .semibold)
                        .foregroundStyle(Color.systemBlack)
                        .alignLeading()
                }
                
                Spacer(minLength: 0)
                
                NavButton(icon: "f00d", onTap: { dismiss() })
            }
            
            SearchBar(
                placeholder: "Search by course name",
                onDebounce: { text in
                    print("onDebounce \(text)")
                    searchText = text
                    await viewModel.searchCourses(for: text)
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
                    
                    ForEach(viewModel.searchedCourses, id: \.id) { course in
                        row(for: course)
                    }
                    
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
        .task {
            await viewModel.loadRecents()
        }
    }
    
    @ViewBuilder
    private func row(for course: GolfCourseAPIModel) -> some View {
        VStack {
            HStack(spacing: 16) {
                Icon(name: "f3c5", size: 22, weight: .solid)
                    .foregroundStyle(Color.hackersGray4)
                
                VStack {
                    Text("\(course.prettyClubName)")
                        .fontStyle(.poppins, size: 17, weight: .medium)
                        .foregroundStyle(Color.systemBlack)
                        .alignLeading()
                    
                    Text(course.location.city + ", " + course.location.state)
                        .fontStyle(.poppins, size: 13, weight: .regular)
                        .foregroundStyle(Color.hackersGray)
                        .alignLeading()
                }
            }
            
            Line()
        }
    }
    
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
                if viewModel.isLoadingRecents {
                    skeletonView
                } else if viewModel.recentCourses.isPopulated {
                    ForEach(viewModel.recentCourses, id: \.id) { course in
                        row(for: course)
                    }
                } else {
                    Spacer()
                    Text("No recent courses")
                        .fontStyle(.poppins, size: 15, weight: .medium)
                        .foregroundStyle(Color.hackersGray)
                        .alignCenter()
                    Spacer()
                }
            }
            
            if viewModel.selectedChip == .nearby {
                Spacer()
                Text("Prompt for location, query API for nearby")
                Spacer()
            }
            
            if viewModel.selectedChip == .favorite {
                Spacer()
                Text("Favorite roe go here")
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var skeletonView: some View {
        ForEach(0...5, id: \.self) { _ in
            SkeletonRow()
            Line()
        }
    }
}

#Preview {
    CourseSelectionView()
        .environmentObject(AppSession())
}
