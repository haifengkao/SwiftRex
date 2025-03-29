import Foundation

/// A subject that wraps a single value and publishes changes to subscribers
/// This is designed to be a replacement for Combine's CurrentValueSubject to remove the dependency
@MainActor
final class RexValueSubject<Element: Sendable, Failure: Error> {
    /// The current value
    private var _value: Element

    /// List of subscribers
    private var subscribers: [UUID: (Result<Element, Failure>) -> Void] = [:]

    /// Access to the current value
    var value: Element {
        get { _value }
        set {
            _value = newValue
            send(newValue)
        }
    }

    /// Initialize with a default value
    /// - Parameter value: The initial value to publish
    init(_ value: Element) {
        self._value = value
    }

    /// Send a new value to subscribers
    /// - Parameter value: The value to send
    func send(_ value: Element) {
        _value = value
        subscribers.values.forEach { $0(.success(value)) }
    }

    /// Send a completion to subscribers
    /// - Parameter completion: The completion to send
    func send(completion: Result<Void, Failure>) {
        switch completion {
        case .success:
            // Do nothing, as we don't handle "completed" in this simplified implementation
            break
        case .failure(let error):
            subscribers.values.forEach { $0(.failure(error)) }
        }
    }

    /// Send a failure to subscribers
    /// - Parameter error: The error to send
    func send(failure: Failure) {
        subscribers.values.forEach { $0(.failure(failure)) }
    }

    /// Handle a new subscription
    /// - Parameter subscription: The subscription to handle
    func send(subscription: SubscriptionType) {
        // This method exists to maintain compatibility with code that previously used Combine
        // In our new implementation, subscriptions are handled directly by the sink methods
    }

    /// Subscribe to value changes
    /// - Parameter subscriber: The closure to call when values change
    /// - Returns: A subscription identifier that can be used to cancel
    @discardableResult
    func sink(receiveValue: @escaping (Element) -> Void) -> Subscription {
        let id = UUID()
        subscribers[id] = { result in
            if case .success(let value) = result {
                receiveValue(value)
            }
        }

        // Immediately send current value to new subscriber
        receiveValue(_value)

        return Subscription { [weak self] in
            self?.subscribers.removeValue(forKey: id)
        }
    }

    /// Subscribe to value changes and completions
    /// - Parameters:
    ///   - completed: Called when the subject completes
    ///   - failure: Called when the subject errors
    ///   - receiveValue: Called when a new value is available
    /// - Returns: A subscription identifier that can be used to cancel
    @discardableResult
    func sink(
        receiveCompletion: @escaping (Result<Void, Failure>) -> Void,
        receiveValue: @escaping (Element) -> Void
    ) -> Subscription {
        let id = UUID()
        subscribers[id] = { result in
            switch result {
            case .success(let value):
                receiveValue(value)
            case .failure(let error):
                receiveCompletion(.failure(error))
            }
        }

        // Immediately send current value to new subscriber
        receiveValue(_value)

        return Subscription { [weak self] in
            self?.subscribers.removeValue(forKey: id)
        }
    }

    /// Represents a cancellable subscription
    public struct Subscription: SubscriptionType {
        private let cancellationClosure: @MainActor () -> Void

        init(_ cancellationClosure: @MainActor @escaping () -> Void) {
            self.cancellationClosure = cancellationClosure
        }

        /// Cancel the subscription
        public func unsubscribe() {
            cancellationClosure()
        }
    }
}
