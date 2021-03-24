import XCTest
import Combine
import WorkSequencer

final class ExampleTests: XCTestCase {

    func test_functionalExample() {
        let work1 = expectation(description: "work1")
        let work2 = expectation(description: "work2")

        /// Create a functional sequencer. This one has three concurrent workers
        /// and executes work on the main queue.
        let sequencer = FnWorkSequencer(workers: 3, scheduler: DispatchQueue.main.eraseToAnyScheduler())

        /// Start processing work.
        sequencer.start()

        // Perform some work
        sequencer.append {
            print("Immediate done!")
            work1.fulfill()
            return WorkCompleted()
        }

        // Perform work that takes time by sending a signal when it's done.
        sequencer.append {
            let signal = Just("Delayed done!")
                .delay(for: .milliseconds(10), scheduler: DispatchQueue.main)
                .handleEvents(receiveOutput: { message in
                    work2.fulfill()
                    print(message)
                })
            return WorkInProgress(signal)
        }

        wait(for: [work1, work2], timeout: 1, enforceOrder: true)
    }

    func test_structuralExample() {
        let work1 = expectation(description: "work1")
        let work2 = expectation(description: "work2")

        /// Anything can be workable
        struct Printer: Workable {
            var id: String
            var ex: XCTestExpectation
            func work() -> WorkSignal {
                print(id)
                ex.fulfill()
                return WorkCompleted()
            }
        }

        /// Create a sequencer matching our work's identifier.
        let sequencer = WorkSequencer<String>(scheduler: DispatchQueue.main.eraseToAnyScheduler())

        /// Start processing work.
        sequencer.start()

        /// Do some work.
        sequencer.append(Printer(id: "Hello", ex: work1))
        sequencer.append(Printer(id: "World", ex: work2))

        wait(for: [work1, work2], timeout: 1, enforceOrder: true)
    }

    func test_replacementExample() {

        /// Anything can be workable
        struct Printer: Workable {
            var id: String
            var ex: XCTestExpectation?
            func work() -> WorkSignal {
                print(id)
                ex?.fulfill()
                return WorkCompleted()
            }
        }

        /// Create a sequencer matching our work's identifier.
        let sequencer = WorkSequencer<String>(scheduler: DispatchQueue.main.eraseToAnyScheduler())

        // A bunch of work
        let hello = Printer(id: "Hello", ex: expectation(description: "hello"))
        let goodbye = Printer(id: "Goodbye", ex: expectation(description: "goodbye"))
        let cruel = Printer(id: "Cruel", ex: nil)
        let world = Printer(id: "World", ex: expectation(description: "world"))

        /// Start processing work.
        sequencer.start()

        // The initial set of work
        sequencer.replace(items: [goodbye, cruel, world])

        // The updated set of work
        sequencer.replace(items: [hello, world])

        // The first job from the first set is executed, then it switches to the second.
        wait(for: [goodbye.ex!, hello.ex!, world.ex!], timeout: 1, enforceOrder: true)
    }
}
