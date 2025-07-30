//
//  ViewModifier.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
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
            Spacer(minLength: 0)
        }
    }
}

struct AlignCenter: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
        }
    }
}

struct AlignTrailing: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            Spacer(minLength: 0)
            content
        }
    }
}

struct AlignTop: ViewModifier {
    func body(content: Content) -> some View {
        VStack {
            content
            Spacer(minLength: 0)
        }
    }
}

struct AlignMiddle: ViewModifier {
    func body(content: Content) -> some View {
        VStack {
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
        }
    }
}

struct AlignBottom: ViewModifier {
    func body(content: Content) -> some View {
        VStack {
            Spacer(minLength: 0)
            content
        }
    }
}

struct LightModePreview: ViewModifier {
    func body(content: Content) -> some View {
        content
            .previewDevice("iPhone 15 Pro")
            .preferredColorScheme(.light)
            .previewDisplayName("15 Pro Light")
    }
}

struct DarkModePreview: ViewModifier {
    func body(content: Content) -> some View {
        content
            .previewDevice("iPhone 15 Pro")
            .preferredColorScheme(.dark)
            .previewDisplayName("15 Pro Dark")
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

/// Modifier for text field box that highlights border when active.
struct BorderedTextFieldModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var isActive: Bool = false
    var isDisabled: Bool = false
    var color: Color = .hackersForeground
    var error: String = ""
    private let radius: CGFloat = 10

    private var backgroundColor: Color {
        if isDisabled {
            return colorScheme.isLight ? .hackersGray6 : .hackersGray5
        } else {
            return colorScheme.isLight ? .hackersBackground : .hackersGray6
        }
    }
    
    private var borderColor: Color {
        !error.isEmpty ? Color.systemError : isActive ? color : Color.hackersGray5
    }
    
    func body(content: Content) -> some View {
        VStack {
            content
            if !error.isEmpty {
                Text(error)
                    .fontStyle(size: 12)
                    .foregroundColor(Color.systemError)
                    .alignLeading()
                    .padding(.top, 6)
            }
        }
        .padding(12)
        .background(backgroundColor)
        .border(borderColor, width: isActive ? 4 : 2, cornerRadius: radius)
        .cornerRadius(radius)
        .disabled(isDisabled)
    }
}

struct UnderlinedTextFieldModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var isActive: Bool = false
    var isDisabled: Bool = false
    var success: String = ""
    var error: String = ""
    
    var lineColor: Color {
        if isDisabled {
            return Color.hackersGray
        } else if isActive {
            if success.isPopulated {
                return Color.systemGreen
            } else if error.isPopulated {
                return Color.systemError
            } else {
                return Color.hackersForeground
            }
        } else {
            return Color.hackersGray5
        }
    }
    
    func body(content: Content) -> some View {
        VStack {
            content
            RoundedRectangle(cornerRadius: 2, style: .circular)
                .fill(lineColor)
                .frame(height: isActive || !error.isEmpty ? 3 : 2)
                //.cornerRadius(2)
            if !success.isEmpty {
                Text(success)
                    .fontStyle(size: 13, weight: .medium)
                    .foregroundColor(Color.systemGreen)
                    .alignLeading()
                    .padding(.top, 4)
            }
            if !error.isEmpty {
                Text(error)
                    .fontStyle(size: 13, weight: .medium)
                    .foregroundColor(Color.systemError)
                    .alignLeading()
                    .padding(.top, 4)
            }
        }
        //.background(isDisabled ? Color.hackersGray6 : Color.clear)
        .disabled(isDisabled)
    }
}
