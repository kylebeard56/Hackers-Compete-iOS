//
//  HackersCard.swift
//  Hackers
//
//  Created by Kyle Beard on 10/1/25.
//

import SkeletonUI
import SwiftUI

enum HackersCardHeaderStyle {
    case primary
    case secondary
    
    var fontSize: CGFloat {
        switch self {
        case .primary:      return 17
        case .secondary:    return 15
        }
    }
    
    var horizontalSpacing: CGFloat {
        switch self {
        case .primary:      return 12
        case .secondary:    return 8
        }
    }
    
    var foreground: Color {
        switch self {
        case .primary:      return .boxFoxForeground
        case .secondary:    return .boxFoxGray2
        }
    }
}

struct SkeletonPoint: Hashable {
    let id = HackersID.string()

    /// Pixel height
    var h: CGFloat = 24

    /// Screen boundary ratio
    var w: CGFloat = 1

    /// Corner radius
    var r: CGFloat = 10

    static var large: SkeletonPoint { .init(h: 32, w: 1, r: 12) }
    static var medium: SkeletonPoint { .init(h: 20, w: 0.5, r: 8) }
    static var small: SkeletonPoint { .init(h: 13, w: 0.33, r: 5) }

    func width(padding: CGFloat, layers: CGFloat) -> CGFloat {
        UIScreen.main.bounds.width - (padding * layers * 2.0)
    }
}

struct HackersCard<Header: View, Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    
    let icon: String?
    let title: String
    let headerStyle: HackersCardHeaderStyle
    let callToAction: (() -> Header)?
    let content: () -> Content
    let background: Color
    let skeletonCount: Int
    let skeletonHeight: CGFloat
//    let skeletonPoints: [SkeletonPoint]
    let showLine: Bool
    @Binding var isLoading: Bool
    
    init(
        icon: String? = nil,
        title: String,
        headerStyle: HackersCardHeaderStyle = .secondary,
        callToAction: (() -> Header)? = nil,
        @ViewBuilder content: @escaping () -> Content,
        background: Color = .boxFoxCard,
        skeletonCount: Int = 3,
        skeletonHeight: CGFloat = 24,
//        skeletonPoints: [SkeletonPoint] = [.large, .medium, .small],
        showLine: Bool = true,
        isLoading: Binding<Bool> = .false
    ) {
        self.icon = icon
        self.title = title
        self.headerStyle = headerStyle
        self.callToAction = callToAction
        self.content = content
        self.background = background
        self.skeletonCount = skeletonCount
        self.skeletonHeight = skeletonHeight
//        self.skeletonPoints = skeletonPoints
        self.showLine = showLine
        _isLoading = isLoading
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: headerStyle.horizontalSpacing) {
                if let icon {
                    Icon(name: icon, size: headerStyle.fontSize, maxSize: headerStyle.fontSize, weight: .regular)
                        .foregroundStyle(headerStyle.foreground)
                }

                Text(title)
                    .fontStyle(.poppins, size: headerStyle.fontSize, weight: .semibold)
                    .foregroundStyle(headerStyle.foreground)
                
                Spacer(minLength: 0)
                
                if let callToAction {
                    callToAction()
                }
            }
            
            if !(content() is EmptyView) && !showLine {
                Line()
            }
            
            if isLoading {
                ForEach(0..<skeletonCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: skeletonHeight / 2)
                        .skeleton(
                            with: isLoading,
                            animation: .linear(duration: 2),
                            appearance: .solid(
                                color: colorScheme.set(.gray5, .gray4),
                                background: colorScheme.set(.gray7, .gray5)
                            ),
                            shape: .rounded(.radius(skeletonHeight / 2)),
                            lines: 1,
                            scales: [1: 0.5, 2: 0.25]
                        )
                        .frame(height: skeletonHeight)
                }
            } else {
                content()
            }
        }
        .padding(16)
        .background(background)
        .cornerRadius(12)
    }
}

import Flow

#Preview {
    ZStack {
        Color.boxFoxBackground.edgesIgnoringSafeArea(.all)
        
        ScrollView {
            VStack(spacing: 16) {
                HackersCard(
                    title: "Loading",
                    callToAction: { EmptyView() },
                    content: { EmptyView() },
                    isLoading: .true
                )
                
                HackersCard(
                    icon: "e1d8",
                    title: "Notes or instructions",
                    callToAction: { EmptyView() },
                    content: {
                        HFlow(spacing: 8) {
                            Chip(text: "Today")
                            Chip(text: "Tomorrow", style: .outline)
                            Chip(text: "Thursday", style: .outline)
                            Chip(text: "Friday", style: .outline)
                            Chip(text: "Saturday", style: .outline)
                            Chip(text: "See more dates", icon: "2b", style: .outline)
                        }
                        .alignLeading()
                        
                        SecondaryButton(text: "See more", isDisabled: .false, isLoading: .false)
                            .padding(.top, 16)
                    }
                )
                
                HackersCard(
                    title: "Your week",
                    callToAction: { Chip(text: "Oct 20-26", weight: .semibold, size: .xSmall, style: .fill) },
                    content: {
                        ForEach(0...3, id: \.self) { i in
                            HStack(spacing: 16) {
                                if i == 0 {
                                    Icon(name: "f058", size: 20, maxSize: 20, weight: .solid)
                                        .foregroundStyle(Color.boxFoxForeground)
                                } else {
                                    Circle()
                                        .stroke(Color.boxFoxGray4, lineWidth: 1)
                                        .frame(width: 20, height: 20)
                                }
                                
                                Text("Some checklist text")
                                    .fontStyle()
                                    .foregroundColor(Color.boxFoxForeground)
                                    .alignLeading()
                            }
                            
                            Line()
                                .padding(.leading, 36)
                        }
                        
                        SecondaryButton(text: "See your calendar", isDisabled: .false, isLoading: .false, onTap: {})
                            .padding(.top, 16)
                    }
                )
                
                HackersCard(
                    icon: "e1d8",
                    title: "Notes",
                    headerStyle: .primary,
                    callToAction: { NavButton(icon: "2b", size: 15, weight: .solid) },
                    content: { EmptyView() }
                )
            }
            .padding(16)
        }
    }
}
