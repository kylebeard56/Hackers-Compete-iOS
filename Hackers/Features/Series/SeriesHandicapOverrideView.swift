//
//  SeriesHandicapOverrideView.swift
//  Hackers
//

import SwiftUI

struct SeriesHandicapOverrideView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SeriesViewModel

    @State private var overrides: [String: OverrideState] = [:]

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private struct OverrideState {
        var isOverridden: Bool
        var valueText: String
    }

    var body: some View {
        StickyScrollView(
            header: {
                SeriesSheetHeader(
                    palette: palette,
                    title: "Handicap Overrides",
                    subtitle: "Commissioner overrides replace the computed league handicap until turned off.",
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(spacing: 12) {
                    ForEach(viewModel.activeMembers, id: \.id) { member in
                        overrideRow(member)
                    }
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            },
            footer: {
                Button {
                    Haptics.fire(.light)
                    saveOverrides()
                    dismiss()
                } label: {
                    Text("Save")
                        .fontStyle(kFontName, size: 16, weight: .semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(palette.foregroundColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(palette.backgroundColor)
            },
            onScroll: { _ in }
        )
        .background(palette.backgroundColor.ignoresSafeArea())
        .onAppear { loadOverrides() }
    }

    private func overrideRow(_ member: SeriesMember) -> some View {
        let state = overrides[member.id] ?? OverrideState(isOverridden: false, valueText: "")
        let hc = viewModel.memberHandicaps[member.id]
        let computedText = hc?.computedIndex.map { String(format: "%.1f", $0) } ?? "--"

        return SeriesSheetCard(palette: palette) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(member.name.fullName)
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text("Computed: \(computedText)")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                Spacer(minLength: 0)

                Toggle("", isOn: Binding(
                    get: { overrides[member.id]?.isOverridden ?? false },
                    set: {
                        overrides[member.id, default: OverrideState(isOverridden: false, valueText: "")].isOverridden = $0
                    }
                ))
                .tint(.orange)
                .labelsHidden()
            }

            if state.isOverridden {
                TextField("Index", text: Binding(
                    get: { overrides[member.id]?.valueText ?? "" },
                    set: { overrides[member.id, default: OverrideState(isOverridden: true, valueText: "")].valueText = $0 }
                ))
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(Color.orange)
                .keyboardType(.decimalPad)
                .mutedGlassTextFieldContainer(cornerRadius: 14, baseFill: palette.cardEmbeddedRowBackground)
            }
        }
    }

    private func loadOverrides() {
        for member in viewModel.activeMembers {
            let hc = viewModel.memberHandicaps[member.id]
            overrides[member.id] = OverrideState(
                isOverridden: hc?.isOverridden ?? false,
                valueText: hc?.overrideIndex.map { String(format: "%.1f", $0) } ?? ""
            )
        }
    }

    private func saveOverrides() {
        for (memberID, state) in overrides {
            let value = Double(state.valueText)
            Task {
                await viewModel.setHandicapOverride(
                    memberID: memberID,
                    value: value,
                    isOverridden: state.isOverridden && value != nil
                )
            }
        }
    }
}
