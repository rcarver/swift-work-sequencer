import Combine

/// A unit of work is a function that returns a signal.
public typealias Work = () -> WorkSignal

/// The signal used to signal work completion (or error).
public typealias WorkSignal = AnyPublisher<Void, Error>

/// A work item is an identifiable unit of work
public protocol Workable: Identifiable {
    func work() -> WorkSignal
}

/// A concrete work item.
public struct WorkItem<ID: Hashable>: Workable {

    public init(id: ID, unit: @escaping Work) {
        self.id = id
        self.unit = unit
    }

    public let id: ID
    public let unit: Work

    public func work() -> WorkSignal {
        unit()
    }
}

public extension Workable {

    /// Type-erase any workable so you can mulitple types uniformly.
    func eraseToAnyWorkItem() -> WorkItem<ID> {
        WorkItem(id: id, unit: work)
    }
}

public extension Collection where Element: Workable {

    /// Type-erase any workable so you can mulitple types uniformly.
    func eraseToAnyWorkItem() -> [WorkItem<Element.ID>] {
        map { $0.eraseToAnyWorkItem() }
    }
}
