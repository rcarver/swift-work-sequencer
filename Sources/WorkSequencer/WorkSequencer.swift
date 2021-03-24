import Combine
import CombineSchedulers

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

public func WorkCompleted() -> WorkSignal {
    Just<Void>(())
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
}

public func WorkFailed(_ error: Error) -> WorkSignal {
    Fail(error: error)
        .eraseToAnyPublisher()
}

public class WorkSequencer<ID: Hashable> {

    public typealias Item = WorkItem<ID>

    public init(workers count: Int = 1, scheduler: AnySchedulerOf<DispatchQueue>) {
        self.workerCount = count
        self.scheduler = scheduler
    }

    private var workerCount: Int
    private var scheduler: AnySchedulerOf<DispatchQueue>

    private var itemLookup: [ Item.ID : Item ] = [:]
    private var lock = DispatchQueue(label: "WorkSequencer-Lock")

    private(set) var itemList: [Item.ID] = []

    private typealias Worker = PassthroughSubject<Item, Never>

    private var workers: [ Int : Worker ] = [:]
    private var working: [ Int: Bool ] = [:]
    private var cancellables = Set<AnyCancellable>()

    public func start() {
        for index in 0..<workerCount {
            makeWorker(index)
        }
        distributeWork()
    }

    public func stop() {
        cancellables.removeAll()
        workers.removeAll()
    }
}

extension WorkSequencer: Cancellable {
    public func cancel() {
        stop()
    }
}

public extension WorkSequencer where ID == UUID {

    @discardableResult
    func append(_ work: @escaping Work) -> ID {
        let id = UUID()
        append(WorkItem(id: id, work: work))
        return id
    }
}

public extension WorkSequencer {

    func append(_ item: Item) {
        lock.sync {
            if itemLookup[item.id] == nil {
                itemList.append(item.id)
                itemLookup[item.id] = item
            }
        }
        distributeWork()
    }

    func replace(items: [Item]) {
        lock.sync {
            let diffs = items.map(\.id).difference(from: itemList)
            for diff in diffs {
                switch diff {
                case .insert(let index, let element, _):
                    if let item = items.first(where: { $0.id == element }) {
                        itemList.insert(item.id, at: index)
                        itemLookup[item.id] = item
                    }
                case .remove(let index, let element, _):
                    if let item = items.first(where: { $0.id == element }) {
                        itemList.remove(at: index)
                        itemLookup[item.id] = nil
                    }
                }
            }
        }
        distributeWork()
    }
}

// MARK: - Work lifecycle

private extension WorkSequencer {

    enum Result {
        case success(Item.ID)
        case failure(Item.ID)
    }

    func work(on item: Item) -> AnyPublisher<Void, Never> {
        item.work()
            .first()
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        self?.finished(item.id)
                    case .failure:
                        self?.failed(item.id)
                    }
                },
                receiveCancel: { [weak self] in
                    self?.cancelled(item.id)
                })
            .catch { _ in Empty() }
            .eraseToAnyPublisher()
    }

    func finished(_ id: Item.ID) {
        lock.sync {
            itemLookup[id] = nil
        }
    }

    func failed(_ id: Item.ID) {
        lock.sync {
            // infinite retry?
            if itemLookup[id] != nil {
                itemList.append(id)
            }
        }
    }

    func cancelled(_ id: Item.ID) {
        lock.sync {
            itemLookup[id] = nil
        }
    }
}

// MARK: - Worker lifecycle.

private extension WorkSequencer {

    func makeWorker(_ index: Int) {
        let subject = Worker()

        subject
            .receive(on: scheduler)
            .flatMap { [weak self] item -> AnyPublisher<Void, Never> in
                guard let self = self else { return Empty().eraseToAnyPublisher() }
                self.workerWillStart(index)
                return self.work(on: item)
            }
            .sink { [weak self] result in
                guard let self = self else { return }
                self.workerDidFinish(index)
            }
            .store(in: &cancellables)

        workers[index] = subject
    }

    func workerWillStart(_ index: Int) {
        working[index] = true
    }

    func workerDidFinish(_ index: Int) {
        working[index] = nil
        distributeWork()
    }

    func distributeWork() {
        var jobs: [(Item, Worker)] = []
        lock.sync {
            let available = Set(workers.keys).subtracting(working.keys)
            for key in available {
                if let next = unsafe_next(), let worker = workers[key] {
                    jobs.append((next, worker))
                }
            }
        }
        for job in jobs {
            let (item, worker) = job
            worker.send(item)
        }
    }

    func unsafe_next() -> Item? {
        if let id = unsafe_nextId(), let item = itemLookup[id] {
            return item
        } else {
            return nil
        }
    }

    func unsafe_nextId() -> Item.ID? {
        if itemList.count > 0 {
            return itemList.removeFirst()
        } else {
            return nil
        }
    }
}
