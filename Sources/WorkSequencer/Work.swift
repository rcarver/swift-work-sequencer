import Combine

/// A unit of work is a function that returns a signal.
public typealias Work = () -> WorkSignal

/// The signal used to signal work completion (or error).
public typealias WorkSignal = AnyPublisher<Void, Error>

/// A work item is an identifiable unit of work
public struct WorkItem<ID: Hashable>: Identifiable {

    public init(id: ID, work: @escaping Work) {
        self.id = id
        self.work = work
    }

    public let id: ID
    public let work: Work
}
