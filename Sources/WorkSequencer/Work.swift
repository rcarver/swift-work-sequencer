import Combine

public typealias WorkSignal = AnyPublisher<Void, Error>

public typealias Work = () -> WorkSignal

public struct WorkItem<ID: Hashable>: Identifiable {

    public init(id: ID, work: @escaping Work) {
        self.id = id
        self.work = work
    }

    public let id: ID
    public let work: Work
}

public func WorkInProgress() -> PassthroughSubject<Void, Error> {
    PassthroughSubject()
}

public extension PassthroughSubject where Output == Void, Failure == Error {
    func completed() {
        self.send()
    }
}

public func WorkCompleted() -> WorkSignal {
    Just<Void>(())
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
}

public func WorkFailed(_ error: Error) -> WorkSignal {
    Fail(error: error)
        .eraseToAnyPublisher()
}
