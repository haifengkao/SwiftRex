/// Type-erasure for the protocol ``StoreType``.
///
/// For more information please check the protocol documentation.
/// The easiest way of creating this type is calling ``StoreType/eraseToAnyStoreType()`` on any store type.
public struct AnyStoreType<ActionType: Sendable, StateType: Sendable>: StoreType {
    private let actionHandler: AnyMainActorActionHandler<ActionType>
    private let stateProvider: AnyStateProvider<StateType>

    /// Type-erasure for the protocol ``StoreType``.
    ///
    /// For more information please check the protocol documentation.
    /// The easiest way of creating this type is calling ``StoreType/eraseToAnyStoreType()`` on any store type.
    public init<S: StoreType>(_ store: S) where S.ActionType == ActionType, S.StateType == StateType {
        self.init(action: store.dispatch, state: store.statePublisher)
    }

    /// Type-erasure for the protocol ``StoreType``.
    ///
    /// For more information please check the protocol documentation.
    /// The easiest way of creating this type is calling ``StoreType/eraseToAnyStoreType()`` on any store type.
    public init(action: @MainActor @escaping (DispatchedAction<ActionType>) -> Void, state: UnfailablePublisherType<StateType>) {
        self.actionHandler = AnyMainActorActionHandler(action)
        self.stateProvider = AnyStateProvider(state)
    }

    public init(actionHandler: AnyMainActorActionHandler<ActionType>, state: UnfailablePublisherType<StateType>) {
        self.actionHandler = actionHandler
        self.stateProvider = AnyStateProvider(state)
    }

    /// Type-erasure for the protocol ``StoreType``.
    ///
    /// This function implements the behaviour of ``ActionHandler/dispatch(_:)``
    ///
    /// For more information please check the protocol documentation.
    /// The easiest way of creating this type is calling ``StoreType/eraseToAnyStoreType()`` on any store type.
    public func dispatch(_ dispatchedAction: DispatchedAction<ActionType>) {
        actionHandler.dispatch(dispatchedAction)
    }

    /// Type-erasure for the protocol ``StoreType``.
    ///
    /// This function implements the behaviour of ``StateProvider/statePublisher``
    ///
    /// For more information please check the protocol documentation.
    /// The easiest way of creating this type is calling ``StoreType/eraseToAnyStoreType()`` on any store type.
    public var statePublisher: UnfailablePublisherType<StateType> {
        stateProvider.statePublisher
    }
}

extension StoreType {
    /// Type-erasure for the protocol ``StoreType``.
    ///
    /// For more information please check the protocol documentation.
    /// - Returns: a type-erased store (``AnyStoreType``) from the current ``StoreType``
    public func eraseToAnyStoreType() -> AnyStoreType<ActionType, StateType> {
        AnyStoreType(self)
    }
}
