//
//  AwesomeImage.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import SwiftUI

// NOTE: Duotone is not supported yet due to dual unicode chars.

/// https://fontawesome.com/icons
enum Awesome: String {
    // MARK: - Brands
    case apple = "\u{f179}"
    case facebook = "\u{f09a}"
    case google = "\u{f1a0}"
    case instagram = "\u{f16d}"
    case tiktok = "\u{e07b}"
    case twitter = "\u{f099}"
    
    // MARK: - Normal
    case arrowLeftLong = "\u{f177}"
    case arrowLeftRight = "\u{f178}"
    case bookmark = "\u{f02e}"
    case check = "\u{f00c}"
    case checkCircle = "\u{f058}"
    case chevronDown = "\u{f078}"
    case chevronRight = "\u{f054}"
    case ellipsis = "\u{f141}"
    case golfBallTee = "\u{f450}"
    case home = "\u{e487}"
    case menuBars = "\u{f0c9}"
    case search = "\u{f002}"
    case sliders = "\u{f1de}"
    case squarePlus = "\u{f0fe}"
    case thumbsDown = "\u{f165}"
    case thumbsUp = "\u{f164}"
    case xmark = "\u{f00d}"
}

enum AwesomeFont: String {
    case brand = "fa-brands-400"
    case regular = "fa-regular-400"
    case solid = "fa-solid-900"
    case thin = "fa-light-100"
    case light = "fa-light-300"
    //case duotone = "fa-duotone-900"
    
    var memberName: String {
        switch self {
        case .brand:    return "FontAwesome6Brands-Regular"
        case .regular:  return "FontAwesome6Pro-Regular"
        case .solid:    return "FontAwesome6Pro-Solid"
        case .thin:     return "FontAwesome6Pro-Thin"
        case .light:    return "FontAwesome6Pro-Light"
        //case .duotone:  return "FontAwesome6Duotone-Solid"
        }
    }
}

struct AwesomeIcon {
    var icon: Awesome
    var font: AwesomeFont
    
    init(icon: Awesome, font: AwesomeFont) {
        self.icon = icon
        self.font = font
    }

    func icon(fontSize: CGFloat) -> NSAttributedString {
        if let faFont = UIFont(name: font.memberName, size: fontSize) {
            return NSMutableAttributedString(string: icon.rawValue, attributes: [.font: faFont])
        } else {
            print("font not found: \(font.memberName)")
            return NSMutableAttributedString(string: "?")
        }
    }
}

private struct AwesomeImageWrapper: UIViewRepresentable {
    var image: AwesomeIcon
    var size: CGFloat
    var color: UIColor

    func makeUIView(context: Context) -> UILabel {
        return UILabel(frame: CGRect(x: 0, y: 0, width: size, height: size))
    }
    
    func updateUIView(_ label: UILabel, context: Context) {
        let attributedText = image.icon(fontSize: size)
        label.attributedText = attributedText
        label.textColor = color
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: 0, width: size, height: size)
    }
}

struct AwesomeImage: View {
    var icon: Awesome
    var style: AwesomeFont
    var size: CGFloat
    var color: Color
    
    var body: some View {
        AwesomeImageWrapper(
            image: AwesomeIcon(icon: icon, font: style),
            size: size,
            color: UIColor(color)
        ).frame(width: size, height: size)
    }
}

struct AwesomeImage_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            AwesomeImage(icon: .search, style: .thin, size: 24, color: .systemBlue)
            AwesomeImage(icon: .search, style: .light, size: 24, color: .systemBlue)
            AwesomeImage(icon: .search, style: .regular, size: 24, color: .systemBlue)
            AwesomeImage(icon: .search, style: .solid, size: 24, color: .systemBlue)
            AwesomeImage(icon: .apple, style: .brand, size: 24, color: .systemBlue)
        }
    }
}
