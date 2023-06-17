//
//  Modifiers.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import SwiftUI

/// Modifier for resigning first responder when view triggers a tap within the view.
struct ResignKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content.onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}

/// Modifier for resigning first responder when view triggers a drag gesture within the view.
struct ResignKeyboardOnDrag: ViewModifier {
    var gesture = DragGesture().onChanged({ _ in
        UIApplication.shared.endEditing()
    })
    func body(content: Content) -> some View {
        content.gesture(gesture)
    }
}

struct AlignLeading: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            content
            Spacer()
        }
    }
}

struct AlignCenter: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            Spacer()
            content
            Spacer()
        }
    }
}

struct AlignTrailing: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            Spacer()
            content
        }
    }
}

struct AlignTop: ViewModifier {
    func body(content: Content) -> some View {
        VStack {
            content
            Spacer()
        }
    }
}

struct AlignMiddle: ViewModifier {
    func body(content: Content) -> some View {
        VStack {
            Spacer()
            content
            Spacer()
        }
    }
}

struct AlignBottom: ViewModifier {
    func body(content: Content) -> some View {
        VStack {
            Spacer()
            content
        }
    }
}

struct LightModePreview: ViewModifier {
    func body(content: Content) -> some View {
        content
            .previewDevice("iPhone 14 Pro")
            .preferredColorScheme(.light)
            .previewDisplayName("14 Pro Light")
    }
}

struct DarkModePreview: ViewModifier {
    func body(content: Content) -> some View {
        content
            .previewDevice("iPhone 14 Pro")
            .preferredColorScheme(.dark)
            .previewDisplayName("14 Pro Dark")
    }
}

struct NotchDevicePreview: ViewModifier {
    func body(content: Content) -> some View {
        content
            .previewDisplayName("iPhone X")
            .preferredColorScheme(.light)
            .previewDevice("iPhone X")
    }
}

struct SmallDevicePreview: ViewModifier {
    func body(content: Content) -> some View {
        content
            .previewDisplayName("iPhone SE")
            .preferredColorScheme(.light)
            .previewDevice("iPhone SE (3rd generation)")
    }
}

struct HolisticPreview: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            content.lightModePreview()
            content.darkModePreview()
            content.notchDevicePreview()
            content.smallDevicePreview()
        }
    }
}

struct Shadow: ViewModifier {
    var opacity: CGFloat
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat
    
    init(
        opacity: CGFloat = 0.12,
        radius: CGFloat = 8,
        x: CGFloat = 0,
        y: CGFloat = 2
    ) {
        self.opacity = opacity
        self.radius = radius
        self.x = x
        self.y = y
    }
    
    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(opacity), radius: radius, x: x, y: y)
    }
}

/// Modifier for text field box that highlights border when active.
struct BorderedTextFieldModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var isActive: Bool = false
    var isDisabled: Bool = false
    var error: String = ""
    private let radius: CGFloat = 10

    func body(content: Content) -> some View {
        VStack {
            content
            if !error.isEmpty {
                Text(error)
                    .font(.dmSans(size: 12, weight: .regular))
                    .foregroundColor(Color.systemRed)
                    .alignLeading()
                    .padding(.top, 6)
            }
        }
        .padding(12)
        .background(colorScheme == .light
                     ? Color(isDisabled ? .systemGray6 : .systemBackground)
                     : Color(isDisabled ? .systemGray5 : .systemGray6))
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(!error.isEmpty
                        ? Color.systemRed
                        : isActive ? Color.systemBlack : Color.systemGray2, lineWidth: isActive ? 4 : 2)
        )
        .cornerRadius(radius)
        .disabled(isDisabled)
    }
}

struct UnderlinedTextFieldModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var isActive: Bool = false
    var isDisabled: Bool = false
    var error: String = ""
    private let radius: CGFloat = 10

    @State private var animateTitle: Bool = false
    
    var lineColor: Color {
        isActive
        ? Color.systemBlack
        : !error.isEmpty ? Color.systemRed
        : isDisabled ? Color.systemGray
        : Color.systemGray3
    }
    
    func body(content: Content) -> some View {
        VStack {
            content
            Rectangle()
                .fill(lineColor)
                .frame(height: isActive || !error.isEmpty ? 2 : 1)
            if !error.isEmpty {
                Text(error)
                    .font(.dmSans(size: 12, weight: .regular))
                    .foregroundColor(Color.systemRed)
                    .alignLeading()
                    .padding(.top, 6)
            }
        }
        .disabled(isDisabled)
    }
}
