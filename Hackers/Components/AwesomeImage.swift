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
enum Awesome: String, Codable {
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
    case beerMug = "\u{e0b3}"
    case bookmark = "\u{f02e}"
    case cardsBlank = "\u{e4df}"
    case check = "\u{f00c}"
    case checkCircle = "\u{f058}"
    case chevronDown = "\u{f078}"
    case chevronRight = "\u{f054}"
    case ellipsis = "\u{f141}"
    case faceSmileHalo = "\u{e38f}"
    case faceSmileHorns = "\u{e391}"
    case filter = "\u{f0b0}"
    case grid = "\u{e196}"
    case golfBallTee = "\u{f450}"
    case golfClub = "\u{f451}"
    case golfFlagHole = "\u{e3ac}"
    case home = "\u{e487}"
    case menuBars = "\u{f0c9}"
    case pencil = "\u{f303}"
    case rectangle = "\u{f2fa}"
    case rows = "\u{e475}"
    case search = "\u{f002}"
    case shuffle = "\u{f074}"
    case sliders = "\u{f1de}"
    case squarePlus = "\u{f0fe}"
    case thumbsDown = "\u{f165}"
    case thumbsUp = "\u{f164}"
    case umbrellaBeach = "\u{f5ca}"
    case trashcan = "\u{f2ed}"
    case trees = "\u{f724}"
    case questionSquare = "\u{f2fd}"
    case water = "\u{f773}"
    case wind = "\u{f72e}"
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

struct AwesomeImage: View {
    var icon: Awesome?
    var rawIcon: String?
    var style: AwesomeFont
    var size: CGFloat
    var color: Color
    var secondaryColor: Color?
    var startPoint: UnitPoint = .top
    var endPoint: UnitPoint = .bottom
    
    var body: some View {
        HStack {
            if let icon {
                Text(icon.rawValue)
            }
            if let rawIcon = rawIcon {
                Text(rawIcon)
            }
        }
        .font(.custom(style.memberName, size: size))
        .foregroundStyle(
            LinearGradient(colors: [color, secondaryColor ?? color], startPoint: startPoint, endPoint: endPoint)
        )
    }
}

struct AwesomeImage_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    AwesomeImage(icon: .search, style: .thin, size: 24, color: .systemBlue)
                    AwesomeImage(icon: .search, style: .light, size: 24, color: .systemBlue)
                    AwesomeImage(icon: .search, style: .regular, size: 24, color: .systemBlue)
                    AwesomeImage(icon: .search, style: .solid, size: 24, color: .systemBlue)
                    AwesomeImage(icon: .apple, style: .brand, size: 24, color: .systemBlue)

                }
                HStack(spacing: 16) {
                    AwesomeImage(icon: .apple, style: .brand, size: 24, color: .systemPink, secondaryColor: .systemYellow)
                    AwesomeImage(icon: .faceSmileHorns, style: .regular, size: 24, color: .systemBlue)
                    AwesomeImage(rawIcon: "\u{f2fe}", style: .regular, size: 24, color: .systemBlue)
                }
            }
            .alignTop()
            .previewDisplayName("Sample")
            
            ZStack {
                Circle()
                    .fill(Color.systemGray6)
                    .frame(width: 240, height: 240)
                AwesomeImage(
                    icon: .golfClub,
                    style: .regular,
                    size: 120,
                    color: .systemPink.opacity(0.6),
                    secondaryColor: .systemYellow.opacity(0.6),
                    startPoint: .top,
                    endPoint: .bottom)
            }
            .lightModePreview()
            
            ZStack {
                Circle()
                    .fill(Color.systemGray6)
                    .frame(width: 240, height: 240)
                AwesomeImage(
                    icon: .golfClub,
                    style: .regular,
                    size: 120,
                    color: .systemPink.opacity(0.6),
                    secondaryColor: .systemYellow.opacity(0.6),
                    startPoint: .top,
                    endPoint: .bottom)
            }
            .darkModePreview()
        }

    }
}
