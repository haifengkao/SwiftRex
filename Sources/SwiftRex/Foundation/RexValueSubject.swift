import Foundation

/// A subject that wraps a single value and publishes changes to subscribers
/// This is designed to be a replacement for Combine's CurrentValueSubject to remove the dependency
@MainActor
public final class RexValueSubject<Element: Sendable, Failure: Error> {
    /// The current value
    private var _value: Element

    /// Completion state
    private var completionState: Result<Void, Failure>?

    /// List of subscribers for values
    private var valueSubscribers: [UUID: (Element) -> Void] = [:]

    /// List of subscribers for errors
    private var errorSubscribers: [UUID: (Failure) -> Void] = [:]

    /// List of subscribers for completion
    private var completionSubscribers: [UUID: () -> Void] = [:]

    /// Access to the current value
    public var value: Element {
        get { _value }
        set {
            guard completionState == nil else { return }
            _value = newValue
            send(newValue)
        }
    }

    /// Initialize with a default value
    /// - Parameter value: The initial value to publish
    public init(_ value: Element) {
        self._value = value
    }

    /// Send a new value to subscribers
    /// - Parameter value: The value to send
    public func send(_ value: Element) {
        guard completionState == nil else { return }
        _value = value

        // Only notify value subscribers if not completed
        valueSubscribers.values.forEach { $0(value) }
    }

    /// Send a completion to subscribers
    /// - Parameter completion: The completion to send
    public func send(completion: Result<Void, Failure>) {
        // Only process completion once
        guard completionState == nil else { return }
        completionState = completion

        switch completion {
        case .success:
            // Notify success completion handlers
            completionSubscribers.values.forEach { $0() }
        case .failure(let error):
            // Notify error handlers
            errorSubscribers.values.forEach { $0(error) }
        }
    }

    /// Send a failure to subscribers
    /// - Parameter error: The error to send
    public func send(failure: Failure) {
        send(completion: .failure(failure))
    }

    /// Handle a new subscription
    /// - Parameter subscription: The subscription to handle
    public func send(subscription: SubscriptionType) {
        // This method exists to maintain compatibility with code that previously used Combine
        // In our new implementation, subscriptions are handled directly by the sink methods
    }

    /// Subscribe to value changes
    /// - Parameter subscriber: The closure to call when values change
    /// - Returns: A subscription identifier that can be used to cancel
    @discardableResult
    public func sink(receiveValue: @escaping (Element) -> Void) -> Subscription {
        let id = UUID()
        valueSubscribers[id] = receiveValue

        // Immediately send current value to new subscriber if not completed
        if completionState == nil {
            receiveValue(_value)
        }

        return Subscription { [weak self] in
            self?.valueSubscribers.removeValue(forKey: id)
            self?.errorSubscribers.removeValue(forKey: id)
            self?.completionSubscribers.removeValue(forKey: id)
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

        // Split completion handling into success and failure 
        valueSubscribers[id] = receiveValue
        errorSubscribers[id] = { error in receiveCompletion(.failure(error)) }
        completionSubscribers[id] = { receiveCompletion(.success(())) }

        // If already completed, immediately send completion
        if let state = completionState {
            receiveCompletion(state)
        } else {
            // Only send current value if not completed
            receiveValue(_value)
        }

        return Subscription { [weak self] in
            self?.valueSubscribers.removeValue(forKey: id)
            self?.errorSubscribers.removeValue(forKey: id)
            self?.completionSubscribers.removeValue(forKey: id)
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
