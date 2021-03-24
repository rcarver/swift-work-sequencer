import Combine
import CombineSchedulers

public protocol Workable: Identifiable {
    func work() -> AnyPublisher<Void, Error>
}

public class WorkSequencer<Item>: Cancellable where Item: Workable {

    public init(workers count: Int = 1, scheduler: AnySchedulerOf<DispatchQueue>) {
        self.workerCount = count
        self.scheduler = scheduler
    }

    private var workerCount: Int
    private var scheduler: AnySchedulerOf<DispatchQueue>
    private var cancellables = Set<AnyCancellable>()

    private var itemLookup: [ Item.ID : Item ] = [:]
    private var lock = DispatchQueue(label: "WorkQueue")

    private(set) var itemList: [Item.ID] = []

    public func start() {
        for _ in 0..<workerCount {
            startWorker()
        }
    }

    public func cancel() {
        cancellables.removeAll()
    }

    public func append(_ item: Item) {
        lock.sync {
            if itemLookup[item.id] == nil {
                itemList.append(item.id)
                itemLookup[item.id] = item
            }
        }
    }

    public func replace(items: [Item]) {
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
}

private extension WorkSequencer {

    enum Result {
        case success(Item.ID)
        case failure(Item.ID)
    }

    func startWorker() {
        let subject = PassthroughSubject<Item, Never>()

        subject
            .receive(on: scheduler)
            .flatMap { [weak self] item -> AnyPublisher<Void, Never> in
                guard let self = self else { return Empty().eraseToAnyPublisher() }
                return self.work(on: item)
            }
            .sink { [weak self] result in
                guard let self = self else { return }
                if let next = self.next() {
                    subject.send(next)
                }
            }
            .store(in: &cancellables)

        if let next = next() {
            subject.send(next)
        }
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

    func next() -> Item? {
        lock.sync {
            if let id = nextId(), let item = itemLookup[id] {
                return item
            } else {
                return nil
            }
        }
    }

    func nextId() -> Item.ID? {
        if itemList.count > 0 {
            return itemList.removeFirst()
        } else {
            return nil
        }
    }
}
