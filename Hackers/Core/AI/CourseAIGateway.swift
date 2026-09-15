import FirebaseAuth
import FirebaseFunctions
import Foundation

enum CourseAIGatewayError: LocalizedError {
    case signInRequired
    case unavailable
    case invalidResponse
    case requestTooLarge
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .signInRequired: return "Please sign in again to find courses or scan scorecards."
        case .unavailable, .invalidResponse: return "Course AI is temporarily unavailable. Please try again later."
        case .requestTooLarge: return "That request is too large. Try a smaller image or a shorter course description."
        case .rateLimitExceeded: return "Too many course requests. Please try again later."
        }
    }
}

/// Only course-specific tasks cross this boundary. Firebase supplies the signed-in user's
/// ID token; provider credentials, prompts, model IDs, and tools are never sent by the app.
@MainActor
struct CourseAIGateway {
    typealias Transport = ([String: Any]) async throws -> [String: Any]
    private let transport: Transport

    init(transport: Transport? = nil) {
        self.transport = transport ?? Self.callFunction
    }

    func extractScorecard(
        imageBase64: String, model: String, context: ScorecardScanContext
    ) async throws -> CourseScorecardDTO {
        guard imageBase64.utf8.count <= 7_000_000 else { throw CourseAIGatewayError.requestTooLarge }
        let result = try await call([
            "operation": "scorecard", "model": model,
            "imageBase64": imageBase64, "context": Self.contextPayload(context)
        ])
        return try decode(CourseScorecardToolOutput.self, result).scorecard
    }

    func lookupCourse(
        messages: [LLMMessage], model: String, context: ScorecardScanContext
    ) async throws -> AskAICourseLookupDTO {
        let transcript = messages.suffix(12).filter { ["user", "assistant"].contains($0.role) }.map { message in
            ["role": message.role, "text": message.content.compactMap { item -> String? in
                if case .text(let text) = item { return text }
                return nil
            }.joined(separator: "\n")]
        }
        let result = try await call([
            "operation": "courseLookup", "model": model,
            "messages": transcript, "context": Self.contextPayload(context)
        ])
        return try decode(AskAICourseLookupToolOutput.self, result).courseLookup
    }

    static func contextPayload(_ context: ScorecardScanContext) -> [String: Any] {
        var data: [String: Any] = [:]
        if let notes = context.notes, !notes.isEmpty { data["notes"] = notes }
        if context.isLocationAssistEnabled, let location = context.approximateLocation {
            data["latitude"] = location.latitude
            data["longitude"] = location.longitude
        }
        return data
    }

    private func call(_ payload: [String: Any]) async throws -> [String: Any] {
        try Task.checkCancellation()
        do {
            let result = try await transport(payload)
            try Task.checkCancellation()
            return result
        } catch {
            try Task.checkCancellation()
            throw Self.mappedError(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, _ result: [String: Any]) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: result))
        } catch {
            throw CourseAIGatewayError.invalidResponse
        }
    }

    private static func callFunction(_ payload: [String: Any]) async throws -> [String: Any] {
        guard Auth.auth().currentUser != nil else { throw CourseAIGatewayError.signInRequired }
        let callable = Functions.functions(region: "us-central1").httpsCallable("courseAI")
        callable.timeoutInterval = 100
        let result = try await callable.call(payload)
        guard let data = result.data as? [String: Any] else { throw CourseAIGatewayError.invalidResponse }
        return data
    }

    static func mappedError(_ error: Error) -> Error {
        guard !(error is CourseAIGatewayError), !(error is CancellationError) else { return error }
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain else { return CourseAIGatewayError.unavailable }
        switch FunctionsErrorCode(rawValue: nsError.code) {
        case .unauthenticated, .permissionDenied: return CourseAIGatewayError.signInRequired
        case .resourceExhausted: return CourseAIGatewayError.rateLimitExceeded
        case .invalidArgument: return CourseAIGatewayError.requestTooLarge
        default: return CourseAIGatewayError.unavailable
        }
    }
}
