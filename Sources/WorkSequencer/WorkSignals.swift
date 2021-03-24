import Combine

/// Create a signal that you can use to indicate completion in the future.
public func Working() -> PassthroughSubject<Void, Error> {
    PassthroughSubject()
}

/// Create a signal that the work is in progress. Optional callback tells you if the
/// work was cancelled so you can decide what to do.
public func WorkInProgress<P>(_ publisher: P, cancelled: @escaping () -> Void = {}) -> WorkSignal where P : Publisher {
    publisher
        .handleEvents(receiveCancel: cancelled)
        .map { _ in () }
        .mapError { $0 as Error }
        .eraseToAnyPublisher()
}

/// Create a signal that the work has completed.
public func WorkCompleted() -> WorkSignal {
    let signal = Working()
    signal.completed()
    return signal.eraseToAnyPublisher()
}

/// Create a signal that the work has failed.
public func WorkFailed(_ error: Error) -> WorkSignal {
    let signal = Working()
    signal.failed(error: error)
    return signal.eraseToAnyPublisher()
}

public extension PassthroughSubject where Output == Void, Failure == Error {

    /// Mark that the work has completed.
    func completed() {
        self.send(completion: .finished)
    }

    /// Mark that the work has failed.
    func failed(error: Error) {
        self.send(completion: .failure(error))
    }
}
