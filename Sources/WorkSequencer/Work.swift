import Combine

/// The signal used to signal work completion (or error).
public typealias WorkSignal = AnyPublisher<Void, Error>

/// A unit of work is a function that returns a signal.
public typealias Work = () -> WorkSignal

public func WorkInProgress() -> PassthroughSubject<Void, Error> {
    PassthroughSubject()
}

public extension PassthroughSubject where Output == Void, Failure == Error {
    func completed() {
        self.send()
    }
}

/// Send a signal that the work has completed.
public func WorkCompleted() -> WorkSignal {
    Just<Void>(())
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
}

/// Send a signal that the work has failed.
public func WorkFailed(_ error: Error) -> WorkSignal {
    Fail(error: error)
        .eraseToAnyPublisher()
}

/// A work item is an identifiable unit of work
public struct WorkItem<ID: Hashable>: Identifiable {

    public init(id: ID, work: @escaping Work) {
        self.id = id
        self.work = work
    }

    public let id: ID
    public let work: Work
}
