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

public protocol SubscriptionRemovable {
    func removeSubscription(withID id: UUID)
}

public class Observable<Element>: SubscriptionRemovable {
    private var subscriptions: [Subscription<Element>] = []
    private var subscriptionRemovables: [SubscriptionRemovable] = []

    public func subscribe(onEmit: @escaping (Element) -> Void) -> UUID {
        let id = UUID()
        let holder = Subscription(onEmit: onEmit, id: id)
        subscriptions.append(holder)

        return id
    }

    public func addSubscriptionRemovable(_ subscriptionRemovable: SubscriptionRemovable) {
        subscriptionRemovables.append(subscriptionRemovable)
    }

    fileprivate func emit(_ value: Element) {
        subscriptions.forEach { $0.onEmit(value) }
    }

    // MARK: - SubscriptionRemovable

    public func removeSubscription(withID id: UUID) {
        subscriptions.removeFirst { $0.id == id }
        subscriptionRemovables.forEach { $0.removeSubscription(withID: id) }
    }
}

public class Publisher<T> {
    public let observable = Observable<T>()

    public init() { }

    public func emit(_ value: T) {
        observable.emit(value)
    }
}

// MARK: - Map

extension Observable {
    public func map<T>(_ mapper: @escaping (Element) -> T) -> Observable<T> {
        let observable = Observable<T>()
        addSubscriptionRemovable(observable)

        subscribe { value in
            observable.emit(mapper(value))
        }

        return observable
    }
}

// MARK: - Filter

extension Observable {
    public func filter(_ predicate: @escaping (Element) -> Bool) -> Observable<Element> {
        let observable = Observable<Element>()
        addSubscriptionRemovable(observable)

        subscribe { value in
            if predicate(value) {
                observable.emit(value)
            }
        }

        return observable
    }
}
