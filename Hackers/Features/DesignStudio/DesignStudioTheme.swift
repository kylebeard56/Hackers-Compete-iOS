#if SANDBOX
import SwiftUI
import UIKit

struct DesignStudioTheme {
    enum Space {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let section: CGFloat = 24
        static let screen: CGFloat = 32
    }

    enum Radius {
        static let compact: CGFloat = 10
        static let control: CGFloat = 16
        static let surface: CGFloat = 24
    }

    let scheme: ColorScheme

    static let forest = ColorValue(hex: "0F2B1F").color
    static let gold = ColorValue(hex: "D4AF37").color
    static let lavender = ColorValue(hex: "C4B5FD").color
    static let softPink = ColorValue(hex: "F4C7CF").color
    static let skyBlue = ColorValue(hex: "60A5FA").color
    static let tangerine = ColorValue(hex: "F97316").color
    static let warmGray = ColorValue(hex: "F5F3F0").color

    var canvas: Color {
        scheme == .dark ? ColorValue(hex: "07131D").color : Self.warmGray
    }

    var surface: Color {
        scheme == .dark ? ColorValue(hex: "13222E").color : .white
    }

    var elevatedSurface: Color {
        scheme == .dark ? ColorValue(hex: "1A2B38").color : ColorValue(hex: "FAF9F6").color
    }

    var primaryText: Color {
        scheme == .dark ? ColorValue(hex: "F8F6F0").color : Self.forest
    }

    var secondaryText: Color {
        scheme == .dark ? ColorValue(hex: "AAB2AD").color : ColorValue(hex: "70766F").color
    }

    var separator: Color {
        scheme == .dark ? ColorValue(hex: "2A3B47").color : ColorValue(hex: "E7E3DC").color
    }

    var success: Color { ColorValue(hex: "35945A").color }
    var danger: Color { ColorValue(hex: "D94C4C").color }
    var lavenderText: Color { scheme == .dark ? Self.lavender : ColorValue(hex: "6D55BD").color }
}

enum DesignStudioTypography {
    enum Role {
        case hero
        case title
        case heading
        case body
        case caption
        case eyebrow
    }

    static func font(_ role: Role) -> Font {
        let specification: (size: CGFloat, weight: Font.Weight, relativeTo: Font.TextStyle)
        switch role {
        case .hero: specification = (32, .bold, .largeTitle)
        case .title: specification = (24, .bold, .title2)
        case .heading: specification = (17, .semibold, .headline)
        case .body: specification = (15, .regular, .body)
        case .caption: specification = (12, .regular, .caption)
        case .eyebrow: specification = (11, .semibold, .caption2)
        }

        if UIFont(name: "Satoshi-Regular", size: specification.size) != nil {
            let name = specification.weight == .bold || specification.weight == .semibold
                ? "Satoshi-Bold"
                : "Satoshi-Regular"
            return .custom(name, size: specification.size, relativeTo: specification.relativeTo)
        }
        return .system(size: specification.size, weight: specification.weight, design: .rounded)
    }
}

struct DesignStudioInitialBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let initials: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(colorScheme == .dark ? 0.2 : 0.7), lineWidth: 2))
            .accessibilityLabel("Player \(initials)")
    }
}

struct DesignStudioIconBadge: View {
    let symbol: String
    let foreground: Color
    let background: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

struct DesignStudioPrimaryButton: View {
    let title: String
    var symbol: String? = nil
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignStudioTheme.Space.small) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(DesignStudioTypography.font(.heading))
            .foregroundStyle(DesignStudioTheme.forest)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isEnabled ? DesignStudioTheme.gold : Color.gray.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: DesignStudioTheme.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct DesignStudioSectionLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(DesignStudioTypography.font(.eyebrow))
            .tracking(1.4)
            .foregroundStyle(DesignStudioTheme(scheme: colorScheme).primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DesignStudioSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(DesignStudioTheme(scheme: colorScheme).surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignStudioTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignStudioTheme.Radius.control, style: .continuous)
                    .stroke(DesignStudioTheme(scheme: colorScheme).separator, lineWidth: 1)
            }
    }
}

#Preview("Design tokens") {
    DesignStudioComponentGalleryView()
}
#endif
