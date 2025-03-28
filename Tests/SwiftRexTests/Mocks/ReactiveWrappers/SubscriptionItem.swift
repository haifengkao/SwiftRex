import Foundation
import SwiftRex

final class SubscriptionItem: SubscriptionType {
    let uuid = UUID()
    let onUnsubscribe: @MainActor (UUID) -> Void

    init(onUnsubscribe: @escaping @MainActor (UUID) -> Void) {
        self.onUnsubscribe = onUnsubscribe
    }

    func unsubscribe() {
        onUnsubscribe(uuid)
    }
}
