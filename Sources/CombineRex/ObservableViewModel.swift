import Combine
import Foundation
import SwiftRex

/// A Store Projection made to be used in SwiftUI
///
/// All you need is to create an instance of this class by projecting the main store and providing maps for state and
/// actions. For the consumers, it will act as a real Store, but in fact it's only a proxy to the main store but working
/// in types more close to what a View should know, instead of working on global domain.
///
/// ```
///             ┌────────┐
///             │ Button │────────┐
///             └────────┘        │                     ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐             ┏━━━━━━━━━━━━━━━━━━━━━━━┓
///        ┌──────────────────┐   │         dispatch                                            ┃                       ┃░
///        │      Toggle      │───┼────────────────────▶│   ─ ─ ─ ─ ─ ─ ─ ─ ─ ─▶  │────────────▶┃                       ┃░
///        └──────────────────┘   │         view event      f: (Event) → Action     app action  ┃                       ┃░
///            ┌──────────┐       │                     │                         │             ┃                       ┃░
///            │ onAppear │───────┘                                                             ┃                       ┃░
///            └──────────┘                             │   ObservableViewModel   │             ┃                       ┃░
///                                                                                             ┃                       ┃░
///                                                     │     a projection of     │  projection ┃         Store         ┃░
///                                                          the actual store                   ┃                       ┃░
///                                                     │                         │             ┃                       ┃░
///    ┌────────────────────────┐                                                               ┃                       ┃░
///    │                        │                       │                         │            ┌┃─ ─ ─ ─ ─ ┐            ┃░
///    │    @ObservedObject     │◀ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─    ◀─ ─ ─ ─ ─ ─ ─ ─ ─ ─   ◀─ ─ ─ ─ ─ ─    State                ┃░
///    │                        │           view state  │   f: (State) → View     │  app state │ Publisher │            ┃░
///    └────────────────────────┘                                        State                  ┳ ─ ─ ─ ─ ─             ┃░
///      │          │          │                        └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘             ┗━━━━━━━━━━━━━━━━━━━━━━━┛░
///      ▼          ▼          ▼                                                                 ░░░░░░░░░░░░░░░░░░░░░░░░░
/// ┌────────┐ ┌────────┐ ┌────────┐
/// │  Text  │ │  List  │ │ForEach │
/// └────────┘ └────────┘ └────────┘
/// ```
public final class ObservableViewModel<ViewAction, ViewState>: StoreType, ObservableObject {
    @Published public var state: ViewState
    public let statePublisher: UnfailablePublisherType<ViewState>
    private var cancellableBinding: AnyCancellable!
    private var store: AnyStoreType<ViewAction, ViewState>

    public func dispatch(_ action: ViewAction) {
        store.dispatch(action)
    }

    public init<S: StoreType>(
        initialState: ViewState,
        store: S,
        emitsValue: ShouldEmitValue<ViewState>
    ) where S.ActionType == ViewAction, S.StateType == ViewState {
        self.state = initialState
        self.store = store.eraseToAnyStoreType()
        self.statePublisher = store.statePublisher.removeDuplicates(by: emitsValue.shouldRemove).asPublisherType()
        cancellableBinding = statePublisher.assign(to: \.state, on: self)
    }
}

extension ObservableViewModel where ViewState: Equatable {
    public convenience init<S: StoreType>(
        initialState: ViewState,
        store: S
    ) where S.ActionType == ViewAction, S.StateType == ViewState {
        self.init(
            initialState: initialState,
            store: store,
            emitsValue: .whenDifferent
        )
    }
}

extension StoreType {
    public func asObservableViewModel(
        initialState: StateType,
        emitsValue: ShouldEmitValue<StateType>
    ) -> ObservableViewModel<ActionType, StateType> {
        .init(initialState: initialState, store: self, emitsValue: emitsValue)
    }
}

extension StoreType where StateType: Equatable {
    public func asObservableViewModel(
        initialState: StateType
    ) -> ObservableViewModel<ActionType, StateType> {
        .init(initialState: initialState, store: self, emitsValue: .whenDifferent)
    }
}

#if DEBUG
extension ObservableViewModel {
    /// Mock for using in tests or SwiftUI previews, available in DEBUG mode only
    /// You can use if as a micro-redux for tests and SwiftUI previews, for example:
    /// ```
    /// let mock = ObservableViewModel<(user: String, pass: String, buttonEnabled: Bool), ViewAction>.mock(
    ///     state: (user: "ozzy", pass: "", buttonEnabled: false),
    ///     action: { action, state in
    ///         switch action {
    ///         case let .userChanged(newUser):
    ///             state.user = newUser
    ///             state.buttonEnabled = !state.user.isEmpty && !state.pass.isEmpty
    ///         case let .passwordChanged(newPass):
    ///             state.pass = newPass
    ///             state.buttonEnabled = !state.user.isEmpty && !state.pass.isEmpty
    ///         case .buttonTapped:
    ///             print("Button tapped")
    ///         }
    ///     }
    /// )
    /// ```
    /// - Parameter state: Initial state mock
    /// - Parameter action: a simple reducer function, of type `(ActionType, inout StateType) -> Void`, useful if
    ///                     you want to use in SwiftUI live previews and quickly change an UI property when a
    ///                     button is tapped, for example. It's like a micro-redux for tests and SwiftUI previews.
    ///                     Defaults to do nothing.
    /// - Returns: a very simple ObservableViewModel mock, that you can inject in your SwiftUI View for tests or
    ///            live preview.
    public static func mock(state: StateType, action: (@escaping (ActionType, inout StateType) -> Void) = { _, _ in })
        -> ObservableViewModel<ActionType, StateType> {
        let subject = CurrentValueSubject<StateType, Never>(state)

        return AnyStoreType<ActionType, StateType>(
            action: {
                var state = subject.value
                action($0, &state)
                subject.send(state)
            },
            state: subject.asPublisherType()
        ).asObservableViewModel(initialState: state, emitsValue: .always)
    }
}
#endif
