//
//  FirebaseIDValidationTests.swift
//  HackersUnitTests
//

@testable import Hackers
import XCTest

final class FirebaseIDValidationTests: XCTestCase {
    private struct MockIdentifiable: FirebaseIdentifiable {
        var id: String
        var collection: String { "test-collection" }
        var createdAt = Time(for: Date())
        var lastUpdatedAt = Time(for: Date())
        var schema = 1
    }

    private struct MockSubcollectable: FirebaseSubcollectable {
        var id: String
        var parentID: String
        var createdAt = Time(for: Date())
        var lastUpdatedAt = Time(for: Date())
        var schema = 1

        static let parentCollection = "test-parents"
        static let subcollectionName = "test-children"
    }

    func testUpdateDocumentRejectsInvalidID() async {
        let badIDs = ["", "   ", "bad/id", " /leadingSlash", "trailing/ "]

        for id in badIDs {
            let result = await FirebaseService.shared.updateDocument(
                MockIdentifiable(id: id),
                in: "test-collection"
            )

            assertInvalidDocumentID(result, context: "id: '\(id)'")
        }
    }

    func testUpdateSubcollectableRejectsInvalidPath() async {
        let badPairs = [
            (id: "", parentID: "parent"),
            (id: "child", parentID: ""),
            (id: "bad/id", parentID: "parent"),
            (id: "child", parentID: "bad/parent")
        ]

        for pair in badPairs {
            let result = await FirebaseService.shared.updateDocument(
                MockSubcollectable(id: pair.id, parentID: pair.parentID)
            )

            assertInvalidDocumentID(
                result,
                context: "id=\(pair.id) parent=\(pair.parentID)"
            )
        }
    }

    private func assertInvalidDocumentID<T>(
        _ result: Result<T, Error>,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch result {
        case .failure(let error as HackersError):
            XCTAssertEqual(error, .invalidDocumentID, "Unexpected error for \(context)", file: file, line: line)
        case .failure(let error):
            XCTFail("Expected invalidDocumentID for \(context), got \(error)", file: file, line: line)
        case .success:
            XCTFail("Expected invalidDocumentID for \(context), got success", file: file, line: line)
        }
    }
}
