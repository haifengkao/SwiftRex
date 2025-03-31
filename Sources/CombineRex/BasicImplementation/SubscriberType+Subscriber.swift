import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubscriberType {
    public static func combine<Input, Failure>(onValue: (@MainActor (Input) -> Void)? = nil, onCompleted: (@MainActor (Failure?) -> Void)? = nil)
        -> SubscriberType<Input, Failure> {
            SubscriberType<Input, Failure>(onValue: onValue ?? { _ in },
                           onCompleted: { error in
                guard let error else {
                    onCompleted?(nil)
                    return
                }
                onCompleted?(error)
            })
    }
}
