import SwiftUI

@main
struct HackersWatchApp: App {
    @StateObject private var store: WatchRoundStore
    @State private var path = NavigationPath()

    init() {
#if DEBUG || targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let showsPreviewRound = arguments.contains("--watch-preview-round")
        _store = StateObject(
            wrappedValue: WatchRoundStore(
                snapshot: showsPreviewRound ? WatchPreviewFixtures.snapshot : nil,
                activateSession: !showsPreviewRound
            )
        )

        var previewPath = NavigationPath()
        if showsPreviewRound,
           let screenArgumentIndex = arguments.firstIndex(of: "--watch-preview-screen"),
           arguments.indices.contains(screenArgumentIndex + 1) {
            switch arguments[screenArgumentIndex + 1] {
            case "scores":
                previewPath.append(WatchHoleDestination())
            case "score-editor":
                if let subjectID = WatchPreviewFixtures.snapshot.subjects.first?.id {
                    previewPath.append(
                        WatchScoreEditorDestination(
                            subjectID: subjectID,
                            holeNumber: WatchPreviewFixtures.snapshot.selectedHole
                        )
                    )
                }
            case "leaderboard":
                previewPath.append(WatchCompetitionDestination(kind: .field))
            case "matchups":
                previewPath.append(WatchCompetitionDestination(kind: .matchup))
            default:
                break
            }
        }
        _path = State(initialValue: previewPath)
#else
        _store = StateObject(wrappedValue: WatchRoundStore())
#endif
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                Group {
                    if store.snapshot == nil {
                        WatchEmptyRoundView()
                    } else {
                        WatchRoundOverviewView(store: store)
                    }
                }
                .navigationDestination(for: WatchHoleDestination.self) { _ in
                    WatchHoleView(store: store)
                }
                .navigationDestination(for: WatchScoreEditorDestination.self) { destination in
                    WatchScoreEditorView(store: store, destination: destination)
                }
                .navigationDestination(for: WatchCompetitionDestination.self) { destination in
                    WatchLeaderboardView(store: store, kind: destination.kind)
                }
            }
            .onOpenURL {
                _ = store.handle(url: $0)
            }
            .onChange(of: store.deepLinkNavigationRevision) { _, _ in
                path = NavigationPath()
                path.append(WatchHoleDestination())
            }
            .onChange(of: store.snapshot?.roundID) { oldValue, newValue in
                guard oldValue != newValue, newValue == nil else { return }
                path = NavigationPath()
            }
        }
    }
}
