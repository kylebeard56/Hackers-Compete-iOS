//
//  EmptyStateView.swift
//  Hackers
//
//  Reusable empty state with image, optional title, and optional subtitle.
//

import SwiftUI

enum EmptyStatePreset {
    case activeRounds
    case playerHistory
    case courseHistory
    case roundHistory

    var imageName: String {
        switch self {
        case .activeRounds: return "GolfIsometric"
        case .playerHistory: return "GolferIsometric"
        case .courseHistory: return "ClubhouseIsometric"
        case .roundHistory: return "LeaderboardIsometric"
        }
    }

    var title: String {
        switch self {
        case .activeRounds: return "No active rounds"
        case .playerHistory: return "No players yet"
        case .courseHistory: return "No courses yet"
        case .roundHistory: return "No rounds found"
        }
    }

    var subtitle: String {
        switch self {
        case .activeRounds: return "Start or join a round to see it here."
        case .playerHistory: return "Recent or common players will appear here."
        case .courseHistory: return "Courses you've played will show up here."
        case .roundHistory: return "Your completed rounds will appear here."
        }
    }
}

struct EmptyStateBackgroundStyle {
    let cornerRadius: CGFloat
    let fill: Color
    let padding: CGFloat
}

struct EmptyStateView: View {
    let imageName: String
    var title: String? = nil
    var subtitle: String? = nil
    var background: EmptyStateBackgroundStyle? = nil

    init(imageName: String, title: String? = nil, subtitle: String? = nil, background: EmptyStateBackgroundStyle? = nil) {
        self.imageName = imageName
        self.title = title
        self.subtitle = subtitle
        self.background = background
    }

    init(preset: EmptyStatePreset, background: EmptyStateBackgroundStyle? = nil) {
        self.imageName = preset.imageName
        self.title = preset.title
        self.subtitle = preset.subtitle
        self.background = background
    }

    private var content: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Image(imageName)
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width * 0.45)

            if let title, title.isPopulated {
                Text(title)
                    .fontStyle(kFontName, size: 20, weight: .semibold)
                    .foregroundStyle(Color.foregroundPrimary)
                    .alignCenter()
            }

            if let subtitle, subtitle.isPopulated {
                Text(subtitle)
                    .fontStyle(kFontName, size: 15, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .multilineTextAlignment(.center)
                    .alignCenter()
            }

            Spacer(minLength: 0)
        }
    }

    var body: some View {
        Group {
            if let bg = background {
                content
                    .padding(.horizontal, bg.padding)
                    .background(
                        RoundedRectangle(cornerRadius: bg.cornerRadius)
                            .fill(bg.fill)
                    )
            } else {
                content
                    .padding(.horizontal, 16)
            }
        }
    }
}
