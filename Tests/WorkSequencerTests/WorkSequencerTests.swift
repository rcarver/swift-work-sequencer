import Combine
import CombineSchedulers
import XCTest
import WorkSequencer

final class LifecycleTests: XCTestCase {

    var scheduler = DispatchQueue.immediateScheduler
    var worker: WorkSequencer<UUID>!
    var appender: ((Int) -> Work)!
    var completions: [Int]!

    override func setUp() {
        worker = WorkSequencer<UUID>(
            workers: 1,
            scheduler: scheduler.eraseToAnyScheduler())

        completions = []
        appender = { (id: Int) -> Work in
            {
                self.completions.append(id)
                return WorkCompleted()
            }
        }
    }

    func test_append_before_start() {
        worker.append(appender(1))
        XCTAssertEqual(completions, [])
    }

    func test_start_after_append() {
        worker.append(appender(1))
        worker.append(appender(2))
        XCTAssertEqual(completions, [])
        worker.start()
        XCTAssertEqual(completions, [1, 2])
    }

    func test_append_after_start() {
        worker.start()
        worker.append(appender(1))
        worker.append(appender(2))
        XCTAssertEqual(completions, [1, 2])
    }

    func test_append_after_stop() {
        worker.start()
        worker.append(appender(1))
        worker.stop()
        worker.append(appender(2))
        XCTAssertEqual(completions, [1])
    }

    func test_start_after_stop() {
        worker.start()
        worker.append(appender(1))
        worker.stop()
        worker.append(appender(2))
        worker.start()
        XCTAssertEqual(completions, [1, 2])
    }
}

final class FunctionalTests: XCTestCase {

    var scheduler = DispatchQueue.immediateScheduler
    var worker: WorkSequencer<UUID>!
    var appender: ((Int) -> Work)!
    var completions: [Int]!

    override func setUp() {
        worker = WorkSequencer<UUID>(
            workers: 1,
            scheduler: scheduler.eraseToAnyScheduler())

        completions = []
        appender = { (id: Int) -> Work in
            {
                self.completions.append(id)
                return WorkCompleted()
            }
        }
    }

    func test_append_function() {
        worker.start()
        worker.append(appender(1))
        worker.append(appender(2))

        XCTAssertEqual(completions, [1, 2])
    }

    func test_append_item() {
        worker.start()
        worker.append(WorkItem(id: UUID(), work: appender(1)))
        worker.append(WorkItem(id: UUID(), work: appender(2)))

        XCTAssertEqual(completions, [1, 2])
    }

    func test_replace_function() throws {
        throw XCTSkip("not implemented")

        let a = worker.append(appender(1))
        let b = worker.append(appender(2))

        let items = [
            WorkItem(id: b, work: appender(22)),
            WorkItem(id: a, work: appender(11)),
            WorkItem(id: UUID(), work: appender(33))
        ]

        worker.replace(items: items)
        worker.start()

        XCTAssertEqual(completions, [22, 11, 33])
    }
}
