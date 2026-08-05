#if SANDBOX
import SwiftUI

struct DesignStudioRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var roundStore = DesignStudioRoundStore()
    @StateObject private var seriesStore = DesignStudioSeriesRoundStore()

    private var theme: DesignStudioTheme { .init(scheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignStudioTheme.Space.section) {
                header
                prototypeLinks
                principles
            }
            .padding(.horizontal, DesignStudioTheme.Space.large)
            .padding(.top, DesignStudioTheme.Space.small)
            .padding(.bottom, DesignStudioTheme.Space.screen)
        }
        .background(theme.canvas.ignoresSafeArea())
        .navigationTitle("Design Studio")
        .navigationBarTitleDisplayMode(.inline)
        .tint(DesignStudioTheme.forest)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.small) {
            Text("HACKERS GOLF · NEXT")
                .font(DesignStudioTypography.font(.eyebrow))
                .tracking(1.4)
                .foregroundStyle(DesignStudioTheme.gold)
            Text("A friendlier way to compete.")
                .font(DesignStudioTypography.font(.hero))
                .foregroundStyle(theme.primaryText)
            Text("Interactive, local-only explorations for the lobby, live round, and commissioner setup flows.")
                .font(DesignStudioTypography.font(.body))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var prototypeLinks: some View {
        VStack(spacing: DesignStudioTheme.Space.medium) {
            NavigationLink {
                DesignStudioLobbyView(store: roundStore)
            } label: {
                DesignStudioLaunchCard(
                    eyebrow: "PLAY FLOW",
                    title: "Lobby → Live Round",
                    subtitle: "Configure a foursome, enter scores, and finish a local round.",
                    symbol: "figure.golf",
                    accent: DesignStudioTheme.gold
                )
            }

            NavigationLink {
                DesignStudioSeriesRoundView(store: seriesStore)
            } label: {
                DesignStudioLaunchCard(
                    eyebrow: "COMMISSIONER FLOW",
                    title: "Series Round Setup",
                    subtitle: "Conditional guidance first, then jump-anywhere revisions.",
                    symbol: "list.clipboard.fill",
                    accent: DesignStudioTheme.lavender
                )
            }

            NavigationLink {
                DesignStudioComponentGalleryView()
            } label: {
                DesignStudioLaunchCard(
                    eyebrow: "FOUNDATIONS",
                    title: "Theme & Components",
                    subtitle: "Tokens, type, actions, grouped rows, and player initials.",
                    symbol: "paintpalette.fill",
                    accent: DesignStudioTheme.skyBlue
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var principles: some View {
        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.medium) {
            DesignStudioSectionLabel(title: "Guardrails")
            DesignStudioSurface {
                VStack(spacing: 0) {
                    principleRow(symbol: "square.fill", title: "Opaque content surfaces", detail: "Glass stays in navigation and overlays.")
                    Divider().padding(.leading, 60)
                    principleRow(symbol: "person.text.rectangle", title: "Initials, not portraits", detail: "Fast recognition without fake avatars.")
                    Divider().padding(.leading, 60)
                    principleRow(symbol: "circle.lefthalf.filled", title: "Light and dark together", detail: "One semantic theme from day one.")
                }
            }
        }
    }

    private func principleRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: DesignStudioTheme.Space.medium) {
            Image(systemName: symbol)
                .foregroundStyle(DesignStudioTheme.gold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: DesignStudioTheme.Space.xSmall) {
                Text(title)
                    .font(DesignStudioTypography.font(.heading))
                    .foregroundStyle(theme.primaryText)
                Text(detail)
                    .font(DesignStudioTypography.font(.caption))
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignStudioTheme.Space.large)
    }
}

private struct DesignStudioLaunchCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let eyebrow: String
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color

    private var theme: DesignStudioTheme { .init(scheme: colorScheme) }

    var body: some View {
        HStack(spacing: DesignStudioTheme.Space.large) {
            DesignStudioIconBadge(
                symbol: symbol,
                foreground: theme.primaryText,
                background: accent.opacity(colorScheme == .dark ? 0.28 : 0.45),
                size: 52
            )
            VStack(alignment: .leading, spacing: DesignStudioTheme.Space.xSmall) {
                Text(eyebrow)
                    .font(DesignStudioTypography.font(.eyebrow))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondaryText)
                Text(title)
                    .font(DesignStudioTypography.font(.heading))
                    .foregroundStyle(theme.primaryText)
                Text(subtitle)
                    .font(DesignStudioTypography.font(.caption))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
        }
        .padding(DesignStudioTheme.Space.large)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignStudioTheme.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignStudioTheme.Radius.control, style: .continuous)
                .stroke(theme.separator, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}

struct DesignStudioComponentGalleryView: View {
    enum Appearance: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        var id: String { rawValue }
        var scheme: ColorScheme? { self == .system ? nil : self == .light ? .light : .dark }
    }

    @Environment(\.colorScheme) private var colorScheme
    @State private var appearance: Appearance = .system
    @State private var toggleValue = true

    private var theme: DesignStudioTheme { .init(scheme: appearance.scheme ?? colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignStudioTheme.Space.section) {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                palette
                typography
                actions
                groupedRows
                initials
            }
            .padding(DesignStudioTheme.Space.large)
        }
        .background(theme.canvas.ignoresSafeArea())
        .navigationTitle("Theme & Components")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(appearance.scheme)
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.medium) {
            DesignStudioSectionLabel(title: "Palette")
            HStack(spacing: DesignStudioTheme.Space.small) {
                swatch("Forest", DesignStudioTheme.forest)
                swatch("Gold", DesignStudioTheme.gold)
                swatch("Lavender", DesignStudioTheme.lavender)
                swatch("Pink", DesignStudioTheme.softPink)
                swatch("Sky", DesignStudioTheme.skyBlue)
            }
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: DesignStudioTheme.Space.small) {
            Circle().fill(color).frame(width: 44, height: 44)
            Text(name)
                .font(DesignStudioTypography.font(.caption))
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var typography: some View {
        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.small) {
            DesignStudioSectionLabel(title: "Typography")
            DesignStudioSurface {
                VStack(alignment: .leading, spacing: DesignStudioTheme.Space.medium) {
                    Text("Ready for the first tee?")
                        .font(DesignStudioTypography.font(.title))
                    Text("Satoshi-ready semantic roles keep every screen consistent.")
                        .font(DesignStudioTypography.font(.body))
                        .foregroundStyle(theme.secondaryText)
                    Text("SERIES ROUND · SAT, JUL 25")
                        .font(DesignStudioTypography.font(.eyebrow))
                        .tracking(1.4)
                        .foregroundStyle(DesignStudioTheme.gold)
                }
                .foregroundStyle(theme.primaryText)
                .padding(DesignStudioTheme.Space.large)
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.medium) {
            DesignStudioSectionLabel(title: "Actions")
            DesignStudioPrimaryButton(title: "Start Round", symbol: "flag.fill") {}
            Toggle(isOn: $toggleValue) {
                VStack(alignment: .leading, spacing: DesignStudioTheme.Space.xSmall) {
                    Text("Use course handicaps").font(DesignStudioTypography.font(.heading))
                    Text("Calculate strokes from rating and slope.")
                        .font(DesignStudioTypography.font(.caption))
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .tint(DesignStudioTheme.forest)
            .padding(DesignStudioTheme.Space.large)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignStudioTheme.Radius.control, style: .continuous))
        }
    }

    private var groupedRows: some View {
        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.medium) {
            DesignStudioSectionLabel(title: "Grouped rows")
            DesignStudioSurface {
                VStack(spacing: 0) {
                    componentRow("Format & Scoring", "Team Match Play", "trophy.fill")
                    Divider().padding(.leading, 72)
                    componentRow("Handicap & Eligibility", "2 need review", "person.crop.circle")
                }
            }
        }
    }

    private func componentRow(_ title: String, _ subtitle: String, _ symbol: String) -> some View {
        HStack(spacing: DesignStudioTheme.Space.medium) {
            DesignStudioIconBadge(symbol: symbol, foreground: theme.primaryText, background: DesignStudioTheme.lavender.opacity(0.35))
            VStack(alignment: .leading, spacing: DesignStudioTheme.Space.xSmall) {
                Text(title).font(DesignStudioTypography.font(.heading))
                Text(subtitle).font(DesignStudioTypography.font(.caption)).foregroundStyle(theme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(theme.secondaryText)
        }
        .foregroundStyle(theme.primaryText)
        .padding(DesignStudioTheme.Space.large)
    }

    private var initials: some View {
        VStack(alignment: .leading, spacing: DesignStudioTheme.Space.medium) {
            DesignStudioSectionLabel(title: "Player identity")
            HStack(spacing: DesignStudioTheme.Space.medium) {
                DesignStudioInitialBadge(initials: "KB", color: DesignStudioTheme.gold)
                DesignStudioInitialBadge(initials: "AM", color: DesignStudioTheme.forest)
                DesignStudioInitialBadge(initials: "SP", color: ColorValue(hex: "3B8C5A").color)
                Text("Initials stay fast, personal, and honest.")
                    .font(DesignStudioTypography.font(.caption))
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }
}

#Preview("Studio") {
    NavigationStack { DesignStudioRootView() }
}
#endif
