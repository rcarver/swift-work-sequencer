import Combine
import CombineSchedulers
import XCTest
import WorkSequencer

final class WorkFunctionTests: XCTestCase {

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
        worker.append(WorkItem(id: UUID(), unit: appender(1)))
        worker.append(WorkItem(id: UUID(), unit: appender(2)))

        XCTAssertEqual(completions, [1, 2])
    }

    func test_replace() throws {
        let a = worker.append(appender(1))
        let b = worker.append(appender(2))

        let items = [
            WorkItem(id: b, unit: appender(22)),
            WorkItem(id: a, unit: appender(11)),
            WorkItem(id: UUID(), unit: appender(33))
        ]

        worker.replace(items: items)
        worker.start()

        XCTAssertEqual(completions, [22, 11, 33])
    }
}

final class WorkableTests: XCTestCase {

    var scheduler = DispatchQueue.immediateScheduler
    var worker: WorkSequencer<Int>!
    var effects: Effects!

    struct TestItem: Workable {
        var id: Int
        var effects: Effects
        func work() -> WorkSignal {
            effects.completions.append(id)
            return WorkCompleted()
        }
    }

    class Effects {
        var completions: [Int] = []
    }

    override func setUp() {
        worker = WorkSequencer(
            workers: 1,
            scheduler: scheduler.eraseToAnyScheduler())

        effects = Effects()
    }

    func test_append() {
        worker.start()
        worker.append(TestItem(id: 1, effects: effects))
        worker.append(TestItem(id: 2, effects: effects))

        XCTAssertEqual(effects.completions, [1, 2])
    }

    func test_replace() throws {
        let a = TestItem(id: 1, effects: effects)
        let b = TestItem(id: 2, effects: effects)
        let c = TestItem(id: 3, effects: effects)

        worker.replace(items: [a, b, c])
        worker.replace(items: [b, a, c])
        worker.start()

        XCTAssertEqual(effects.completions, [2, 1, 3])
    }
}
