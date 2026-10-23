import FirebaseAuth
import FirebaseCore
import FirebaseFunctions
import Testing

/// Exercise the SDK request-context paths implicated in Firebase #15974 using
/// a separate app and loopback endpoints. No production account or backend is used.
@MainActor
@Suite(.serialized)
struct FirebaseStartupCrashRegressionTests {
    @Test
    func authRequestHeaderCleanupSurvivesRepeatedNetworkFailures() async throws {
        let app = try makeApp()
        let auth = Auth.auth(app: app)
        auth.useEmulator(withHost: "127.0.0.1", port: 1)
        for _ in 0..<20 {
            do {
                _ = try await auth.signIn(withCustomToken: "startup-crash-regression-invalid-token")
                Issue.record("The local endpoint must not sign in")
            } catch {
                let error = error as NSError
                #expect(error.domain == AuthErrors.domain)
                #expect(error.code == AuthErrorCode.networkError.rawValue)
            }
        }
        #expect(auth.currentUser == nil)
        await delete(app)
    }

    @Test
    func callableContextCleanupSurvivesRepeatedNetworkFailures() async throws {
        let app = try makeApp()
        let functions = Functions.functions(app: app)
        functions.useEmulator(withHost: "127.0.0.1", port: 1)
        let callable = functions.httpsCallable("startupCrashRegression")
        callable.timeoutInterval = 2
        for _ in 0..<20 {
            do {
                _ = try await callable.call(["regression": true])
                Issue.record("The local endpoint must not return a function result")
            } catch {
                // Transport errors propagate from URLSession before a callable
                // response exists; expect the closed loopback connection itself.
                let error = error as NSError
                #expect(error.domain == NSURLErrorDomain)
                #expect(error.code == URLError.cannotConnectToHost.rawValue)
            }
        }
        await delete(app)
    }

    private func makeApp() throws -> FirebaseApp {
        let name = "startup-crash-\(UUID().uuidString)"
        let options = FirebaseOptions(
            googleAppID: "1:1234567890:ios:0123456789abcdef",
            gcmSenderID: "1234567890"
        )
        // Installations validates the format even for loopback-only Auth/Functions.
        // This syntactically valid placeholder is not a real Firebase API key.
        options.apiKey = "A" + String(repeating: "0", count: 38)
        options.projectID = "startup-crash-regression"
        FirebaseApp.configure(name: name, options: options)
        return try #require(FirebaseApp.app(name: name))
    }

    private func delete(_ app: FirebaseApp) async {
        let deleted: Bool = await withCheckedContinuation { continuation in
            app.delete { continuation.resume(returning: $0) }
        }
        #expect(deleted)
    }
}
