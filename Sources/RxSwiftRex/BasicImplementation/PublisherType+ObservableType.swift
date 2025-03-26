import Foundation
import RxSwift
import SwiftRex

extension PublisherType: @retroactive ObservableConvertibleType, @retroactive ObservableType {
    public func subscribe<Observer>(_ observer: Observer) -> Disposable
        where Observer: ObserverType, Element == Observer.Element {
        let subscriber: SubscriberType<Element, ErrorType> = .init(
            onValue: observer.onNext,
            onCompleted: { error in
                if let error = error {
                    observer.onError(error)
                    return
                }
                observer.onCompleted()
            }
        )
        let subscription: SubscriptionType = self.subscribe(subscriber)
        return subscription.asDisposable()
    }
}

extension ObservableType {
    public func asPublisherType() -> PublisherType<Element, Error> {
        .init { (subscriber: SubscriberType<Element, Error>) -> SubscriptionType in
            self.subscribe(subscriber.asObserver()).asSubscriptionType()
        }
    }
}

extension PublisherType {
    public static func lift<FromElement>(_ transform: @Sendable @escaping (FromElement) -> Element) -> (PublisherType<FromElement, Error>)
    -> PublisherType<Element, Error> { { originalPublisher in
            originalPublisher.map(transform).asPublisherType()
        }
    }
}
