import SwiftUI

struct WatchEmptyRoundView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Live Round", systemImage: "flag.checkered")
        } description: {
            Text("Choose a live round in Hackers on iPhone.")
        }
    }
}

#Preview {
    WatchEmptyRoundView()
}
