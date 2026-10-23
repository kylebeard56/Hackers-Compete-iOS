import XCTest
@testable import Hackers

@MainActor
final class DashboardStartupLoaderTests: XCTestCase {
    func testBothLoadsStartBeforeEitherCompletesAndReadinessWaitsForBoth() async {
        let rounds = StartupLoadGate()
        let series = StartupLoadGate()
        let bothStarted = expectation(description: "Both requests start concurrently")
        bothStarted.expectedFulfillmentCount = 2
        var ready: Bool?
        let task = Task {
            ready = await DashboardStartupLoader.load(
                rounds: { bothStarted.fulfill(); await rounds.wait() },
                series: { bothStarted.fulfill(); await series.wait() }
            )
        }

        await fulfillment(of: [bothStarted], timeout: 3)
        XCTAssertNil(ready)
        rounds.finish()
        await Task.yield()
        XCTAssertNil(ready, "One completed request must not enable companion reconciliation")
        series.finish()
        await task.value
        XCTAssertEqual(ready, true)
    }

    func testCancelledStartupDrainsChildrenWithoutPublishingReadiness() async {
        let rounds = StartupLoadGate()
        let series = StartupLoadGate()
        let bothStarted = expectation(description: "Both requests started")
        bothStarted.expectedFulfillmentCount = 2
        var ready: Bool?
        let task = Task {
            ready = await DashboardStartupLoader.load(
                rounds: { bothStarted.fulfill(); await rounds.wait() },
                series: { bothStarted.fulfill(); await series.wait() }
            )
        }
        await fulfillment(of: [bothStarted], timeout: 3)
        task.cancel()
        rounds.finish()
        await Task.yield()
        XCTAssertNil(ready, "Cancelled startup still owns its unfinished child")
        series.finish()
        await task.value
        XCTAssertEqual(ready, false)
    }

    func testAlreadyCancelledStartupDoesNotBeginRequests() async {
        var requestCount = 0
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await DashboardStartupLoader.load(
                rounds: { requestCount += 1 },
                series: { requestCount += 1 }
            )
        }
        let ready = await task.value
        XCTAssertFalse(ready)
        XCTAssertEqual(requestCount, 0)
    }

    func testRepeatedStartupCompletion() async {
        var roundsLoaded = 0
        var seriesLoaded = 0
        for _ in 0..<250 {
            let ready = await DashboardStartupLoader.load(
                rounds: { roundsLoaded += 1; await Task.yield() },
                series: { seriesLoaded += 1; await Task.yield() }
            )
            XCTAssertTrue(ready)
        }
        XCTAssertEqual(roundsLoaded, 250)
        XCTAssertEqual(seriesLoaded, 250)
    }
}

@MainActor
private final class StartupLoadGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var finished = false

    func wait() async {
        guard !finished else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func finish() {
        finished = true
        continuation?.resume()
        continuation = nil
    }
}
