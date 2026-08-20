import SwiftUI

struct WatchChipOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String

    var id: Value { value }
}

struct WatchChipPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [WatchChipOption<Value>]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            selection == option.value ? Color.green : Color.clear,
                            in: Capsule()
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.secondary.opacity(0.2), in: Capsule())
    }
}
