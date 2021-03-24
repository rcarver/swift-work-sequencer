import Combine
import CombineSchedulers
import XCTest
import WorkSequencer

struct FnWork: Workable {
    var id: Int
    var fn: (Int) -> Void
    func work() -> AnyPublisher<Void, Error> {
        fn(id)
        return Just<Void>(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
}

final class Tests: XCTestCase {

    func test_append() {
        let scheduler = DispatchQueue.immediateScheduler

        let worker = WorkSequencer<FnWork>(
            workers: 1,
            scheduler: scheduler.eraseToAnyScheduler())

        var completions: [Int] = []
        let append = { id in completions.append(id) }

        worker.append(FnWork(id: 1, fn: append))
        worker.append(FnWork(id: 2, fn: append))

        XCTAssertEqual(completions, [])

        worker.start()
        XCTAssertEqual(completions, [1, 2])

        worker.append(FnWork(id: 3, fn: append))
        XCTAssertEqual(completions, [1, 2, 3])

        worker.cancel()
        worker.append(FnWork(id: 4, fn: append))
        XCTAssertEqual(completions, [1, 2, 3])

        worker.start()
        XCTAssertEqual(completions, [1, 2, 3, 4])
    }

}
