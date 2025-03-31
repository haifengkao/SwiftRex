import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension ReplayLastSubjectType {
    public init(currentValueSubject: RexValueSubject<Element, ErrorType>,
                willChange: (@Sendable (Element) -> Void)? = nil) {
        self.init(
            publisher: currentValueSubject.asPublisherType(),
            subscriber: SubscriberType(
                onValue: { newValue in
                    willChange?(newValue)
                    currentValueSubject.value = newValue
                },
                onCompleted: { error in
                    currentValueSubject.send(completion: error.map { .failure($0) } ?? .success(()))
                },
                onSubscribe: { subscription in
                    currentValueSubject.send(subscription: subscription)
                }
            ),
            value: { currentValueSubject.value }
        )
    }

    @MainActor
    public static func combine(initialValue: Element, willChange: (@Sendable (Element) -> Void)? = nil) -> ReplayLastSubjectType<Element, ErrorType> {
        .init(currentValueSubject: RexValueSubject<Element, ErrorType>(initialValue),
              willChange: willChange)
    }
}
