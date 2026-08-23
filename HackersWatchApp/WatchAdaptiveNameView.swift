import SwiftUI

struct WatchAdaptiveNameView: View {
    let title: String
    let compactTitle: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(title)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Text(compactTitle ?? title)
                .lineLimit(1)
        }
    }
}

#Preview {
    WatchAdaptiveNameView(
        title: "Alexandria Wilson-Thompson",
        compactTitle: "Alexandria W."
    )
}
