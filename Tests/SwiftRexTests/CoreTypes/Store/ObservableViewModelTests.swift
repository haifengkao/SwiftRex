@testable import SwiftRex
import XCTest

struct ViewModelTestState: Equatable {
    var value = UUID()
    var name = "Initial State"
}

enum Event: Equatable {
    case event1(Event1)
    case event2(Event2)
}

struct Event1: Equatable {
    var value = UUID()
    var name = "e1"
}

struct Event2: Equatable {
    var value = UUID()
    var name = "e2"
}

indirect enum Action: Equatable, Sendable {
    case action1(Action1)
    case action2(Action2)
    case middlewareAction(Action)
    case middlewareActionAfterReducer(Action)

    var name: String {
        switch self {
        case let .action1(action): return action.name
        case let .action2(action): return action.name
        case let .middlewareAction(action): return action.name
        case let .middlewareActionAfterReducer(action): return action.name
        }
    }
}

struct Action1: Equatable {
    var value = UUID()
    var name = "a1"
    let event: Event1
}

struct Action2: Equatable {
    var value = UUID()
    var name = "a2"
    let event: Event2
}

final class MiddlewareTest: MiddlewareProtocol {
    typealias InputActionType = Action
    typealias OutputActionType = Action
    typealias StateType = ViewModelTestState

    func handle(action: Action, from dispatcher: SwiftRex.ActionSource, state: @escaping SwiftRex.GetState<ViewModelTestState>) -> SwiftRex.IO<Action> {
        switch action {
        case .middlewareAction, .middlewareActionAfterReducer:
            return .pure()
        default:
            break
        }
        return .init { output in
            output.dispatch(.middlewareAction(action), from: .here())
            output.dispatch(.middlewareActionAfterReducer(action), from: .here())
        }
    }
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
class ObservableViewModelTests: XCTestCase, @unchecked Sendable {
    let reducerTest = Reducer<Action, ViewModelTestState>.reduce { action, state in
        switch action {
        case let .action1(action):
            state = .init(value: UUID(), name: state.name + "_" + action.name)
        case let .action2(action):
            state = .init(value: UUID(), name: state.name + "_" + action.name)
        case let .middlewareAction(action):
            state = .init(value: UUID(), name: state.name + "_ma:" + action.name)
        case let .middlewareActionAfterReducer(action):
            state = .init(value: UUID(), name: state.name + "_maar:" + action.name)
        }
    }
    var statePublisher: RexValueSubject<ViewModelTestState, Never>!
    let middlewareTest = MiddlewareTest()
    var viewModel: ObservableViewModel<Event, String>!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        statePublisher = .init(ViewModelTestState())
        viewModel = ReduxStoreBase(
            subject: .init(currentValueSubject: statePublisher),
            reducer: reducerTest,
            middleware: middlewareTest,
            emitsValue: .whenDifferent
        ).projection(
            action: { event in
                switch event {
                case let .event1(event1): return Action.action1(.init(event: event1))
                case let .event2(event2): return Action.action2(.init(event: event2))
                }
            },
            state: { (state: ViewModelTestState) -> String in
                "name: \(state.name)"
            }
        ).asObservableViewModel(initialState: "")
    }

    func testInitialState() {
        XCTAssertEqual("name: Initial State", viewModel.state)
    }

    @MainActor
    func testStatePublisherNotifyOnSubscribeIntegrationTest() {
        let shouldBeNotified = expectation(description: "should be notified by state publisher")
        // Can't test objectWillChange Publisher because it happens before the mutation
        let subscription = viewModel.statePublisher.sink { state in
            XCTAssertEqual("name: Initial State", state)
            shouldBeNotified.fulfill()
        }

        wait(for: [shouldBeNotified], timeout: 1)
        XCTAssertNotNil(subscription)
}

    @MainActor
    func testStatePublisherNotifyOnChangeIntegrationTest() {
        let shouldBeNotified = expectation(description: "should be notified by state publisher")
        var count = 0
        // Can't test objectWillChange Publisher because it happens before the mutation
        let subscription = viewModel.statePublisher.sink { [unowned self] state in
            switch count {
            case 0:
                XCTAssertEqual("name: Initial State", state)
            case 1:
                XCTAssertEqual("name: Initial State_a1", state)
            case 2:
                XCTAssertEqual("name: Initial State_a1_ma:a1", state)
            case 3:
                XCTAssertEqual("name: Initial State_a1_ma:a1_maar:a1", state)
                shouldBeNotified.fulfill()
            default:
                XCTFail("Unexpected notification: \(self.viewModel.state)")
            }
            count += 1
        }
        viewModel.dispatch(.event1(Event1()), from: .here())

        wait(for: [shouldBeNotified], timeout: 1)
        XCTAssertNotNil(subscription)
    }

    @MainActor
    func testObservableViewModelShouldNotLeak() {
        weak var obVMWeakRef: ObservableViewModel<String, String>?
        weak var storeWeakRef: ReduxStoreBase<String, String>?

        autoreleasepool {
            let store = ReduxStoreBase(
                subject: .combine(initialValue: ""),
                reducer: Reducer<String, String>.identity,
                middleware: IdentityMiddleware<String, String, String>(),
                emitsValue: .whenDifferent
            )
            storeWeakRef = store

            let obVMStrongRef = store.asObservableViewModel(initialState: "")
            obVMWeakRef = obVMStrongRef
            XCTAssertNotNil(obVMWeakRef)
        }

        XCTAssertNil(storeWeakRef)
        XCTAssertNil(obVMWeakRef, "middleware should be freed")
    }

//    func testWillChangePublisherCanHaveMultipleSubscriptions() {
//        let shouldBeNotifiedByWillChangePublisher3 = expectation(description: "should be notified by will change publisher 1")
//        let shouldBeNotifiedByWillChangePublisher4 = expectation(description: "should be notified by will change publisher 2")
//        let subscription1 = viewModel.objectWillChange.sink { _ in
//            XCTFail("On subscribe this notification should never be triggered")
//        }
//        subscription1.cancel()
//
//        let subscription2 = viewModel.objectWillChange.sink { _ in
//            XCTFail("On subscribe this notification should never be triggered")
//        }
//        subscription2.cancel()
//
//        var countSub3 = 0
//        let subscription3 = viewModel.objectWillChange.sink { [unowned self] _ in
//            switch countSub3 {
//            // expected one notification less (only changes, not initial state) and always with the previous value
//            // not yet the one being set.
//            case 0:
//                XCTAssertEqual("name: Initial State", self.viewModel.state)
//            case 1:
//                XCTAssertEqual("name: Initial State_a1", self.viewModel.state)
//            case 2:
//                XCTAssertEqual("name: Initial State_a1_ma:a1", self.viewModel.state)
//                shouldBeNotifiedByWillChangePublisher3.fulfill()
//            default:
//                XCTFail("Unexpected notification: \(self.viewModel.state)")
//            }
//            countSub3 += 1
//        }
//
//        var countSub4 = 0
//        let subscription4 = viewModel.objectWillChange.sink { [unowned self] _ in
//            switch countSub4 {
//            // expected one notification less (only changes, not initial state) and always with the previous value
//            // not yet the one being set.
//            case 0:
//                XCTAssertEqual("name: Initial State", self.viewModel.state)
//            case 1:
//                XCTAssertEqual("name: Initial State_a1", self.viewModel.state)
//            case 2:
//                XCTAssertEqual("name: Initial State_a1_ma:a1", self.viewModel.state)
//                shouldBeNotifiedByWillChangePublisher3.fulfill()
//            default:
//                XCTFail("Unexpected notification: \(self.viewModel.state)")
//            }
//            countSub4 += 1
//        }
//
//        viewModel.dispatch(.event1(Event1()))
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//            subscription3.cancel()
//        }
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
//            self.viewModel.dispatch(.event2(Event2()))
//        }
//
//        wait(for: [shouldBeNotifiedByWillChangePublisher3, shouldBeNotifiedByWillChangePublisher4], timeout: 5)
//        XCTAssertNotNil(subscription4)
//    }
//
//    func testStatePublisherCanHaveMultipleSubscriptions() {
//        let shouldBeNotifiedByStatePublisher1 = expectation(description: "should be notified by state publisher")
//        let shouldBeNotifiedByStatePublisher2 = expectation(description: "should be notified by state publisher")
//        let subscription1 = store.statePublisher.sink { [unowned self] value in
//            XCTAssertEqual("Initial State", self.store.state.name)
//            XCTAssertEqual("Initial State", value.name)
//        }
//        subscription1.cancel()
//
//        let subscription2 = store.statePublisher.sink { [unowned self] value in
//            XCTAssertEqual("Initial State", self.store.state.name)
//            XCTAssertEqual("Initial State", value.name)
//        }
//        subscription2.cancel()
//
//        var time1 = 0
//        let subscription3 = store.statePublisher.sink { [unowned self] value in
//            switch time1 {
//            case 0:
//                XCTAssertEqual("Initial State", self.store.state.name)
//                XCTAssertEqual("Initial State", value.name)
//            case 1:
//                XCTAssertEqual("Initial State_a1", self.store.state.name)
//                XCTAssertEqual("Initial State_a1", value.name)
//                shouldBeNotifiedByStatePublisher1.fulfill()
//            default:
//                XCTFail("Too many calls")
//            }
//            time1 += 1
//        }
//
//        var time2 = 0
//        let subscription4 = store.statePublisher.sink { [unowned self] value in
//            switch time2 {
//            case 0:
//                XCTAssertEqual("Initial State", self.store.state.name)
//                XCTAssertEqual("Initial State", value.name)
//            case 1:
//                XCTAssertEqual("Initial State_a1", self.store.state.name)
//                XCTAssertEqual("Initial State_a1", value.name)
//                shouldBeNotifiedByStatePublisher2.fulfill()
//            default:
//                XCTFail("Too many calls")
//            }
//            time2 += 1
//        }
//
//        store.eventHandler.dispatch(Event1())
//
//        wait(for: [shouldBeNotifiedByStatePublisher1, shouldBeNotifiedByStatePublisher2], timeout: 1)
//        XCTAssertNotNil(subscription3)
//        XCTAssertNotNil(subscription4)
//    }
}

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
