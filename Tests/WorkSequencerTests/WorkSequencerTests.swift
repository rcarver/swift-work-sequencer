import Combine
import CombineSchedulers
import XCTest
import WorkSequencer

final class Tests: XCTestCase {

    func test_functional_append() {
        let scheduler = DispatchQueue.immediateScheduler

        let worker = WorkSequencer<UUID>(
            workers: 1,
            scheduler: scheduler.eraseToAnyScheduler())

        var completions: [Int] = []
        let appender = { (id: Int) -> Work in
            {
                completions.append(id)
                return WorkCompleted()
            }
        }

        worker.append(appender(1))
        worker.append(appender(2))

        XCTAssertEqual(completions, [])

        worker.start()
        XCTAssertEqual(completions, [1, 2])

        worker.append(appender(3))
        XCTAssertEqual(completions, [1, 2, 3])

        worker.cancel()
        worker.append(appender(4))
        XCTAssertEqual(completions, [1, 2, 3])

        worker.start()
        XCTAssertEqual(completions, [1, 2, 3, 4])
    }
}
