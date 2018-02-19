import Foundation

private extension Array {
    mutating func removeFirst(where predicate: (Element) -> Bool) {
        let enumeration = enumerated().first { predicate($0.element) }

        if let index = enumeration?.offset {
            remove(at: index)
        }
    }
}

// MARK: - Pub Sub

private class Subscription<T> {
    let onEmit: (T) -> Void
    let id: UUID

    init(onEmit: @escaping (T) -> Void, id: UUID) {
        self.onEmit = onEmit
        self.id = id
    }
}

public class Disposable {
    private let disposeHandler: () -> Void
    fileprivate let id: UUID

    fileprivate init<T>(observable: Observable<T>, id: UUID) {
        self.id = id
        disposeHandler = {
            observable.removeSubscription(withID: id)
        }
    }

    public func dispose() {
        disposeHandler()
    }

    public func addTo(_ disposer: Disposer) {
        disposer.add(self)
    }
}

public class Disposer {
    private var disposables: [Disposable] = []

    public init() { }

    deinit {
        disposables.forEach { disposable in
            disposable.dispose()
        }
    }

    func add(_ disposable: Disposable) {
        disposables.append(disposable)
    }
}

public protocol SubscriptionRemovable: class {
    func addSubscriptionRemovable(_ subscriptionRemovable: SubscriptionRemovable)
    func removeSubscription(withID id: UUID)
}

public class Observable<Element>: SubscriptionRemovable {
    fileprivate var subscriptions: [Subscription<Element>] = []
    private var subscriptionRemovables: [SubscriptionRemovable] = []
    private weak var parentRemovable: SubscriptionRemovable?
    private var uuidToRemoveOnDeinit: UUID?

    deinit {
        guard let parentRemovable = parentRemovable, let id = uuidToRemoveOnDeinit else {
            return
        }

        parentRemovable.removeSubscription(withID: id)
    }

    public func subscribe(onEmit: @escaping (Element) -> Void) -> Disposable {
        let id = UUID()
        let holder = Subscription(onEmit: onEmit, id: id)
        subscriptions.append(holder)

        return Disposable(observable: self, id: id)
    }

    fileprivate func emit(_ value: Element) {
        subscriptions.forEach { $0.onEmit(value) }
    }

    fileprivate func setupChain(parent: SubscriptionRemovable, chainedDisposable: Disposable) {
        parent.addSubscriptionRemovable(self)
        self.parentRemovable = parent
        uuidToRemoveOnDeinit = chainedDisposable.id
    }

    // MARK: - SubscriptionRemovable

    public func addSubscriptionRemovable(_ subscriptionRemovable: SubscriptionRemovable) {
        subscriptionRemovables.append(subscriptionRemovable)
    }

    public func removeSubscription(withID id: UUID) {
        subscriptions.removeFirst { $0.id == id }
        subscriptionRemovables.forEach { $0.removeSubscription(withID: id) }
    }
}

public class Publisher<T> {
    public let observable: Observable<T>

    public init() {
        self.observable = Observable()
    }

    public func emit(_ value: T) {
        observable.emit(value)
    }
}

// MARK: - Map

extension Observable {
    public func map<T>(_ mapper: @escaping (Element) -> T) -> Observable<T> {
        let observable = Observable<T>()

        let disposable = subscribe { value in
            observable.emit(mapper(value))
        }

        observable.setupChain(parent: self, chainedDisposable: disposable)

        return observable
    }
}

// MARK: - Filter

extension Observable {
    public func filter(_ predicate: @escaping (Element) -> Bool) -> Observable<Element> {
        let observable = Observable<Element>()

        let disposable = subscribe { value in
            if predicate(value) {
                observable.emit(value)
            }
        }

        observable.setupChain(parent: self, chainedDisposable: disposable)

        return observable
    }
}
