import RxSwift
import SwiftRex

class SideEffectMiddlewareMock: SideEffectMiddleware {
    var allowEventToPropagate: Bool {
        get { return underlyingAllowEventToPropagate }
        set(value) { underlyingAllowEventToPropagate = value }
    }
    var underlyingAllowEventToPropagate: Bool!
    var disposeBag: DisposeBag {
        get { return underlyingDisposeBag }
        set(value) { underlyingDisposeBag = value }
    }
    var underlyingDisposeBag: DisposeBag!
    var actionHandler: ActionHandler?

    // MARK: - sideEffect

    var sideEffectForCallsCount = 0
    var sideEffectForCalled: Bool {
        return sideEffectForCallsCount > 0
    }
    var sideEffectForReceivedEvent: Event?
    var sideEffectForReturnValue: AnySideEffectProducer<StateType>?!
    var sideEffectForClosure: ((Event) -> AnySideEffectProducer<StateType>?)?

    func sideEffect(for event: Event) -> AnySideEffectProducer<StateType>? {
        sideEffectForCallsCount += 1
        sideEffectForReceivedEvent = event
        return sideEffectForClosure.map({ $0(event) }) ?? sideEffectForReturnValue
    }
}

extension SideEffectMiddlewareMock {
    typealias StateType = TestState
}
