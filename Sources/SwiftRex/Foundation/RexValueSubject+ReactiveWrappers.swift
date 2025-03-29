import Foundation

extension RexValueSubject {
    /// Convert a RexValueSubject to a PublisherType
    /// This allows integration with the reactive wrapper system
    public nonisolated func asPublisherType() -> PublisherType<Element, Failure> {
        PublisherType { subscriber in
            let subscription = self.sink(
                receiveCompletion: { result in
                    switch result {
                    case .success:
                        subscriber.onCompleted(nil)
                    case .failure(let error):
                        subscriber.onCompleted(error)
                    }
                },
                receiveValue: { value in
                    subscriber.onValue(value)
                }
            )

            subscriber.onSubscribe(AnySubscription {
                subscription.unsubscribe()
            })

            return AnySubscription {
                subscription.unsubscribe()
            }
        }
    }

    /// Convert a RexValueSubject to a ReplayLastSubjectType
    /// This allows integration with the reactive wrapper system
    public func asReplayLastSubjectType() -> ReplayLastSubjectType<Element, Failure> {
        ReplayLastSubjectType(
            publisher: self.asPublisherType(),
            subscriber: SubscriberType<Element, Failure>(
                onValue: { [weak self] value in
                    self?.send(value)
                },
                onCompleted: { [weak self] error in
                    if let error = error {
                        self?.send(failure: error)
                    }
                    // No completion handling in this simplified implementation
                },
                onSubscribe: { _ in }
            ),
            value: { [weak self] in self?.value ?? self!.value }
        )
    }
}

/// A concrete implementation of SubscriptionType that can be used with our custom RexValueSubject
private struct AnySubscription: SubscriptionType {
    private let _unsubscribe: @MainActor () -> Void

    init(_ unsubscribe: @MainActor @escaping () -> Void) {
        self._unsubscribe = unsubscribe
    }

    func unsubscribe() {
        _unsubscribe()
    }
}
