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

final class DelayedWorkTests: XCTestCase {

    var scheduler = DispatchQueue.testScheduler
    var worker: WorkSequencer<UUID>!
    var appender: ((Int, DispatchQueue.SchedulerTimeType.Stride) -> Work)!
    var completions: [Int]!

    override func setUp() {
        completions = []
        appender = { (id: Int, delay: DispatchQueue.SchedulerTimeType.Stride) -> Work in
            {
                let signal = Working()
                self.completions.append(id)
                self.scheduler.schedule(after: self.scheduler.now.advanced(by: delay)) {
                    self.completions.append(id * 10)
                    signal.completed()
                }
                return WorkInProgress(signal)
            }
        }
    }

    func test_delayed_work() {
        worker = WorkSequencer<UUID>(
            workers: 1,
            scheduler: scheduler.eraseToAnyScheduler())

        worker.start()

        worker.append(appender(1, 1))
        worker.append(appender(2, 1))
        XCTAssertEqual(completions, [])

        scheduler.advance()
        XCTAssertEqual(completions, [1])

        scheduler.advance(by: 1)
        XCTAssertEqual(completions, [1, 10, 2])

        scheduler.advance(by: 1)
        XCTAssertEqual(completions, [1, 10, 2, 20])
    }

    func test_concurrent_work() {
        worker = WorkSequencer<UUID>(
            workers: 2,
            scheduler: scheduler.eraseToAnyScheduler())

        worker.start()

        worker.append(appender(1, 1))
        worker.append(appender(2, 1))
        XCTAssertEqual(completions, [])

        scheduler.advance()
        XCTAssertEqual(completions, [1, 2])

        scheduler.advance(by: 1)
        XCTAssertEqual(completions, [1, 2, 10, 20])
    }
}

final class CancelledWorkTests: XCTestCase {

    var scheduler = DispatchQueue.testScheduler
    var worker: WorkSequencer<UUID>!
    var appender: ((Int, DispatchQueue.SchedulerTimeType.Stride) -> Work)!
    var completions: [Int]!

    override func setUp() {
        completions = []
        appender = { (id: Int, delay: DispatchQueue.SchedulerTimeType.Stride) -> Work in
            {
                let signal = Working()
                var wasCancelled: Bool = false
                self.completions.append(id)
                self.scheduler.schedule(after: self.scheduler.now.advanced(by: delay)) {
                    if wasCancelled {
                        self.completions.append(id * -1)
                    } else {
                        self.completions.append(id * 10)
                    }
                    signal.completed()
                }
                return WorkInProgress(signal, cancelled: {
                    wasCancelled = true
                })
            }
        }
    }

    func test_cancelled_work() {
        worker = WorkSequencer<UUID>(
            workers: 1,
            scheduler: scheduler.eraseToAnyScheduler())

        worker.start()

        worker.append(appender(1, 1))
        worker.append(appender(2, 1))
        XCTAssertEqual(completions, [])

        scheduler.advance()
        XCTAssertEqual(completions, [1])

        worker.stop()
        scheduler.advance(by: 1)
        XCTAssertEqual(completions, [1, -1], "work was cancelled")

        scheduler.advance(by: 1)
        XCTAssertEqual(completions, [1, -1], "future work does not start")

        worker.start()
        scheduler.advance(by: 1)
        XCTAssertEqual(completions, [1, -1, 2, 20], "future work resumed")
    }
}

