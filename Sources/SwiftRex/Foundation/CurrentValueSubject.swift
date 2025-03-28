import Foundation

/// A subject that wraps a single value and publishes changes to subscribers
/// This is designed to be a replacement for Combine's CurrentValueSubject to remove the dependency
final class CurrentValueSubject<Output, Failure: Error> {
    /// The current value
    private var _value: Output
    
    /// List of subscribers
    private var subscribers: [UUID: (Result<Output, Failure>) -> Void] = [:]
    
    /// Access to the current value
    public var value: Output {
        get { _value }
        set {
            _value = newValue
            send(newValue)
        }
    }
    
    /// Initialize with a default value
    /// - Parameter value: The initial value to publish
    public init(_ value: Output) {
        self._value = value
    }
    
    /// Send a new value to subscribers
    /// - Parameter value: The value to send
    public func send(_ value: Output) {
        _value = value
        subscribers.values.forEach { $0(.success(value)) }
    }
    
    /// Send a completion to subscribers
    /// - Parameter completion: The completion to send
    public func send(completion: Result<Void, Failure>) {
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
    public func send(failure: Failure) {
        subscribers.values.forEach { $0(.failure(failure)) }
    }
    
    /// Subscribe to value changes
    /// - Parameter subscriber: The closure to call when values change
    /// - Returns: A subscription identifier that can be used to cancel
    @discardableResult
    public func sink(receiveValue: @escaping (Output) -> Void) -> Subscription {
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
    public func sink(
        receiveCompletion: @escaping (Result<Void, Failure>) -> Void,
        receiveValue: @escaping (Output) -> Void
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
    public struct Subscription {
        private let cancellationClosure: () -> Void
        
        init(_ cancellationClosure: @escaping () -> Void) {
            self.cancellationClosure = cancellationClosure
        }
        
        /// Cancel the subscription
        public func cancel() {
            cancellationClosure()
        }
    }
}

extension CurrentValueSubject.Subscription: Hashable {
    public static func == (lhs: CurrentValueSubject.Subscription, rhs: CurrentValueSubject.Subscription) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
