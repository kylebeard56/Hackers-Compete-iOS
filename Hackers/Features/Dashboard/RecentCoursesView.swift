//
//  RecentCoursesView.swift
//  Hackers
//
//  Full course history with "Play again" on each row.
//

import SwiftUI

struct RecentCoursesView: View {
    @ObservedObject var homeViewModel: DashboardHomeViewModel

    let palette: DesignPalette
    let onDismiss: () -> Void
    let onPlayAgain: (CourseHistoryEntry) -> Void

    private var allCourses: [CourseHistoryEntry] {
        homeViewModel.recentCourses
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(allCourses, id: \.compositeKey) { entry in
                        DashboardCourseRow(
                            entry: entry,
                            palette: palette,
                            rank: nil,
                            onPlayAgain: { onPlayAgain(entry) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.fire(.light)
                        onDismiss()
                    } label: {
                        Icon(name: "f00d", size: 18, weight: .solid)
                            .foregroundStyle(palette.foregroundColor)
                            .frame(width: 44, height: 44)
                            .glassCardEffect(shape: .circle, interactive: false)
                    }
                }
            }
        }
    }
}
