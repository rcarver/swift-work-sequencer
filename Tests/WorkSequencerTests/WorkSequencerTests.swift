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

final class ReplaceTests: XCTestCase {

    var scheduler = DispatchQueue.immediateScheduler
    var worker: WorkSequencer<Int>!
    var appender: ((Int) -> Work)!
    var completions: [Int]!

    override func setUp() {
        worker = WorkSequencer(
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

    func test_replace_insert_before_start() {
        let items1 = [
            WorkItem(id: 1, work: appender(1)),
            WorkItem(id: 2, work: appender(2))
        ]

        let items2 = [
            WorkItem(id: 2, work: appender(22)),
            WorkItem(id: 1, work: appender(11)),
            WorkItem(id: 3, work: appender(33))
        ]

        worker.replace(items: items1)
        worker.replace(items: items2)
        worker.start()

        XCTAssertEqual(completions, [22, 11, 33])
    }

    func test_replace_remove_before_start() {
        let items1 = [
            WorkItem(id: 1, work: appender(1)),
            WorkItem(id: 2, work: appender(2))
        ]

        let items2 = [
            WorkItem(id: 1, work: appender(11)),
            WorkItem(id: 3, work: appender(33))
        ]

        worker.replace(items: items1)
        worker.replace(items: items2)
        worker.start()

        XCTAssertEqual(completions, [11, 33])
    }
}

final class ReplaceWhileWorkingTests: XCTestCase {

    var scheduler = DispatchQueue.testScheduler
    var worker: WorkSequencer<Int>!
    var appender: ((Int, DispatchQueue.SchedulerTimeType.Stride) -> Work)!
    var completions: [Int]!

    override func setUp() {
        worker = WorkSequencer(
            workers: 1,
            scheduler: scheduler.eraseToAnyScheduler())

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

    func test_replace_insert() {
        let a = WorkItem(id: 1, work: appender(1, 1))
        let b = WorkItem(id: 2, work: appender(2, 1))
        let c = WorkItem(id: 3, work: appender(3, 1))

        worker.start()
        worker.replace(items: [a, b, c])

        scheduler.advance()
        XCTAssertEqual(completions, [1])

        worker.replace(items: [c, a, b])
        scheduler.advance()
        XCTAssertEqual(completions, [1])

        scheduler.advance(by: 1)
        XCTAssertEqual(completions, [1, 10, 3], "in progress work completes")

        scheduler.advance(by: 2)
        XCTAssertEqual(completions, [1, 10, 3, 30, 2, 20])
    }

    func test_replace_remove() {
        let a = WorkItem(id: 1, work: appender(1, 1))
        let b = WorkItem(id: 2, work: appender(2, 1))
        let c = WorkItem(id: 3, work: appender(3, 1))

        worker.start()
        worker.replace(items: [a, b, c])

        scheduler.advance()
        XCTAssertEqual(completions, [1])

        worker.replace(items: [c])
        scheduler.advance()
        XCTAssertEqual(completions, [1])

        scheduler.advance(by: 1)
        XCTAssertEqual(completions, [1, 10, 3], "in progress work completes")

        scheduler.advance(by: 1)
        XCTAssertEqual(completions, [1, 10, 3, 30])
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

final class FailedWorkTests: XCTestCase {

    var scheduler = DispatchQueue.immediateScheduler
    var worker: WorkSequencer<UUID>!
    var appender: ((Int, Bool) -> Work)!
    var completions: [Int]!

    struct Because: Error {}

    override func setUp() {
        completions = []
        appender = { (id: Int, fail: Bool) -> Work in
            {
                if fail {
                    self.completions.append(-id)
                    return WorkFailed(Because())
                } else {
                    self.completions.append(id)
                    return WorkCompleted()
                }
            }
        }
    }

    func test_failed_work() {
        worker = WorkSequencer<UUID>(
            workers: 1,
            scheduler: scheduler.eraseToAnyScheduler())

        worker.start()

        worker.append(appender(1, true))
        worker.append(appender(2, false))
        worker.append(appender(3, true))
        worker.append(appender(4, false))

        XCTAssertEqual(completions, [-1, 2, -3, 4])
    }
}
