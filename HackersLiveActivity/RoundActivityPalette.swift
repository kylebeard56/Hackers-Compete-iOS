import SwiftUI

struct RoundActivityPalette {
    let background: Color
    let surface: Color
    let elevatedSurface: Color
    let primary: Color
    let secondary: Color
    let outline: Color
    let brand: Color
    let status: Color

    init(colorScheme _: ColorScheme, status: RoundActivityPresentation.Status) {
        background = Color(red: 0.055, green: 0.075, blue: 0.025)
        surface = Color.white.opacity(0.10)
        elevatedSurface = Color.white.opacity(0.15)
        primary = Color(red: 0.98, green: 0.99, blue: 0.97)
        secondary = Color(red: 0.72, green: 0.76, blue: 0.69)
        outline = Color.white.opacity(0.15)
        brand = Color(red: 0.58, green: 0.91, blue: 0.31)

        switch status {
        case .live:
            self.status = Color(red: 0.43, green: 0.86, blue: 0.30)
        case .attention:
            self.status = Color(red: 1.0, green: 0.66, blue: 0.26)
        case .complete:
            self.status = secondary
        }
    }
}
