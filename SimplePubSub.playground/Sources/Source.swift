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

    public func filterNils<T>() -> Observable<T> where Element == Optional<T> {
        let observable = Observable<T>()

        let disposable = subscribe { optional in
            if let value = optional {
                observable.emit(value)
            }
        }

        observable.setupChain(parent: self, chainedDisposable: disposable)

        return observable
    }
}

// MARK: - Combine

extension Observable {
    public func combine<T>(_ other: Observable<T>) -> Observable<(Element, T)> {
        return Observable.combine(self, other)
    }

    public static func combine<T>(_ other0: Observable<Element>, _ other1: Observable<T>) -> Observable<(Element, T)> {
        let observable = Observable<(Element, T)>()

        var lastValues: (Element?, T?) = (nil, nil)

        let disposable0 = other0.subscribe { value0 in
            lastValues = (value0, lastValues.1)
            if let value1 = lastValues.1 {
                observable.emit((value0, value1))
            }
        }
        let disposable1 = other1.subscribe { value1 in
            lastValues = (lastValues.0, value1)
            if let value0 = lastValues.0 {
                observable.emit((value0, value1))
            }
        }

        observable.setupChain(parent: other0, chainedDisposable: disposable0)
        observable.setupChain(parent: other1, chainedDisposable: disposable1)

        return observable
    }

    public static func combine<T, U>(_ other0: Observable<Element>, _ other1: Observable<T>, _ other2: Observable<U>) -> Observable<(Element, T, U)> {
        let observable = Observable<(Element, T, U)>()

        var lastValues: (Element?, T?, U?) = (nil, nil, nil)

        let disposable0 = other0.subscribe { value0 in
            lastValues = (value0, lastValues.1, lastValues.2)
            if let value1 = lastValues.1, let value2 = lastValues.2 {
                observable.emit((value0, value1, value2))
            }
        }
        let disposable1 = other1.subscribe { value1 in
            lastValues = (lastValues.0, value1, lastValues.2)
            if let value0 = lastValues.0, let value2 = lastValues.2 {
                observable.emit((value0, value1, value2))
            }
        }
        let disposable2 = other2.subscribe { value2 in
            lastValues = (lastValues.0, lastValues.1, value2)
            if let value0 = lastValues.0, let value1 = lastValues.1 {
                observable.emit((value0, value1, value2))
            }
        }

        observable.setupChain(parent: other0, chainedDisposable: disposable0)
        observable.setupChain(parent: other1, chainedDisposable: disposable1)
        observable.setupChain(parent: other2, chainedDisposable: disposable2)

        return observable
    }

    public static func combine<T, U, V>(_ other0: Observable<Element>, _ other1: Observable<T>, _ other2: Observable<U>, _ other3: Observable<V>) -> Observable<(Element, T, U, V)> {
        let observable = Observable<(Element, T, U, V)>()

        var lastValues: (Element?, T?, U?, V?) = (nil, nil, nil, nil)

        let disposable0 = other0.subscribe { value0 in
            lastValues = (value0, lastValues.1, lastValues.2, lastValues.3)
            if let value1 = lastValues.1, let value2 = lastValues.2, let value3 = lastValues.3 {
                observable.emit((value0, value1, value2, value3))
            }
        }
        let disposable1 = other1.subscribe { value1 in
            lastValues = (lastValues.0, value1, lastValues.2, lastValues.3)
            if let value0 = lastValues.0, let value2 = lastValues.2, let value3 = lastValues.3 {
                observable.emit((value0, value1, value2, value3))
            }
        }
        let disposable2 = other2.subscribe { value2 in
            lastValues = (lastValues.0, lastValues.1, value2, lastValues.3)
            if let value0 = lastValues.0, let value1 = lastValues.1, let value3 = lastValues.3 {
                observable.emit((value0, value1, value2, value3))
            }
        }
        let disposable3 = other3.subscribe { value3 in
            lastValues = (lastValues.0, lastValues.1, lastValues.2, value3)
            if let value0 = lastValues.0, let value1 = lastValues.1, let value2 = lastValues.2 {
                observable.emit((value0, value1, value2, value3))
            }
        }

        observable.setupChain(parent: other0, chainedDisposable: disposable0)
        observable.setupChain(parent: other1, chainedDisposable: disposable1)
        observable.setupChain(parent: other2, chainedDisposable: disposable2)
        observable.setupChain(parent: other3, chainedDisposable: disposable3)

        return observable
    }
}

// MARK: - Merge

extension Observable {
    public static func merge(_ lhs: Observable<Element>, _ rhs: Observable<Element>) -> Observable<Element> {
        let observable = Observable<Element>()

        let lhsDisposable = lhs.subscribe { value in
            observable.emit(value)
        }
        let rhsDisposable = rhs.subscribe { value in
            observable.emit(value)
        }

        observable.setupChain(parent: lhs, chainedDisposable: lhsDisposable)
        observable.setupChain(parent: rhs, chainedDisposable: rhsDisposable)

        return observable
    }
}
