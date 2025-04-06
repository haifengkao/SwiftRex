import Foundation

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
@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
@Observable
open class ObservableViewModel<ViewAction: Sendable, ViewState: Sendable>: StateProvider, MainActorActionHandler {
    private var subscription: SubscriptionType?
    private let store: StoreProjection<ViewAction, ViewState>

    public var state: ViewState
    public let statePublisher: UnfailablePublisherType<ViewState>

    @MainActor
    public init<S>(initialState: ViewState, store: S, emitsValue: ShouldEmitValue<ViewState>)
    where S: StoreType, S.ActionType == ViewAction, S.StateType == ViewState {
        self.state = initialState
        self.store = store.eraseToAnyStoreType()
        self.statePublisher = store
            .statePublisher
            .removeDuplicates(by: emitsValue.shouldRemove)

        self.subscription =
            self.statePublisher.sink(
                receiveValue: { [weak self] value in
                    self?.state = value
                }
            )
    }
    deinit {
        let unsubscribe = subscription?.unsubscribe
        Task { @MainActor in
            unsubscribe?()
        }
    }
    
    @MainActor
    open func dispatch(_ dispatchedAction: DispatchedAction<ViewAction>) {
        store.dispatch(dispatchedAction)
    }
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
extension ObservableViewModel where ViewState: Equatable {
    @MainActor
    public convenience init<S: StoreType>(initialState: ViewState, store: S)
    where S.ActionType == ViewAction, S.StateType == ViewState {
        self.init(
            initialState: initialState,
            store: store,
            emitsValue: .whenDifferent
        )
    }
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
extension StoreType {
    @MainActor
    public func asObservableViewModel(
        initialState: StateType,
        emitsValue: ShouldEmitValue<StateType>
    ) -> ObservableViewModel<ActionType, StateType> {
        .init(initialState: initialState, store: self, emitsValue: emitsValue)
    }
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
extension StoreType where StateType: Equatable {
    @MainActor
    public func asObservableViewModel(
        initialState: StateType
    ) -> ObservableViewModel<ActionType, StateType> {
        .init(initialState: initialState, store: self, emitsValue: .whenDifferent)
    }
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
extension ObservableViewModel {
    /// Creates a subset of the current store by applying any transformation to the State or Action types.
    ///
    /// - Parameters:
    ///   - action: a closure that will transform the View Actions into global App Actions, to be dispatched in the original Store
    ///   - state: a closure that will transform the global App State into the View State, to subscribe the original Store and drive the View upon
    ///            changes
    /// - Returns: a ``StoreProjection`` struct, that uses the original Store under the hood, by applying the required transformations on state and
    ///            action when app state changes or view actions arrive. It doesn't store anything, just proxies the original store.
    public func projection<SubViewAction: Sendable, SubViewState: Sendable>(
        action viewActionToGlobalAction: @Sendable @escaping (SubViewAction) -> ViewAction?,
        state globalStateToViewState: @MainActor @escaping (ViewState) -> SubViewState
    ) -> StoreProjection<SubViewAction, SubViewState> {
        .init(
            action: { [store] dispatchedAction in
                guard let globalAction = dispatchedAction.compactMap(viewActionToGlobalAction) else { return }
                store.dispatch(globalAction)
            },
            state: self.statePublisher.map(globalStateToViewState)
        )
    }
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
extension ObservableViewModel {
    /// Create another ``StoreType`` that handles a different type of Action. The original store will be used behind the scenes, by only the provided
    /// "transform" closure whenever an action arrives.
    ///
    /// - Parameters:
    ///   - transform: a closure that will be executed every time an action arrives at the proxy ``StoreType``, so we can map it into the expected
    ///                action type of the original ``StoreType``.
    /// - Returns: an ``AnyStoreType`` with same `Statetype` but different `ActionType` than the original store.
    public func contramapAction<NewActionType: Sendable>(_ transform: @escaping @Sendable (NewActionType) -> ActionType)
    -> AnyStoreType<NewActionType, StateType> {
        AnyStoreType(
            action: { [store] dispatchedAction in
                let oldAction = transform(dispatchedAction.action)
                store.dispatch(oldAction, from: dispatchedAction.dispatcher)
            },
            state: self.statePublisher
        )
    }

    /// Create another ``StoreType`` that handles a different type of State. The original store will be used behind the scenes, by only applying
    /// the provided "transform" closure whenever the state changes in the original store.
    ///
    /// - Parameters:
    ///   - transform: a closure that will be executed every time the state changes in the original store, so we can map it into the state type
    ///                expected by the subscribers of the proxy ``StoreType``.
    /// - Returns: an ``AnyStoreType`` with same `ActionType` but different `StateType` than the original store.
    public func mapState<NewStateType>(_ transform: @Sendable @escaping (StateType) -> NewStateType)
    -> AnyStoreType<ActionType, NewStateType> {
        AnyStoreType(
            action: store.dispatch,
            state: self.statePublisher.map(transform)
        )
    }
}

#if DEBUG
@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
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
    @MainActor
    public static func mock(state: StateType, action: (@escaping (ActionType, ActionSource, inout StateType) -> Void) = { _, _, _ in })
        -> ObservableViewModel<ActionType, StateType> {
        let subject = RexValueSubject<StateType, Never>(state)

        return AnyStoreType<ActionType, StateType>(
            action: { dispatchedAction in
                var state = subject.value
                action(dispatchedAction.action, dispatchedAction.dispatcher, &state)
                subject.send(state)
            },
            state: subject.asPublisherType()
        ).asObservableViewModel(initialState: state, emitsValue: .always)
    }
}
#endif
