import Foundation

/// `MainActorActionHandler` defines a protocol for entities able to handle actions - defined by the associated type `ActionType`
///  and `AnyMainActorActionHandler` erases this protocol to a generic struct type.
///
/// The only protocol requirement is a function that allows other entities to dispatch actions, so Views (or Presenters,
/// ViewModels) in your UI layer, or even Middlewares can create actions of a certain type and send to your store, that
/// is generalized by this protocol.
public struct AnyMainActorActionHandler<ActionType: Sendable>: MainActorActionHandler {
    private let realHandler: @MainActor (DispatchedAction<ActionType>) -> Void

    /// Erases the provided `MainActorActionHandler` by using its inner methods from this wrapper
    /// - Parameter realHandler: the concrete `MainActorActionHandler` you're erasing
    public init<A: MainActorActionHandler>(_ realHandler: A) where A.ActionType == ActionType {
        self.init(realHandler.dispatch)
    }

    /// Erases the any type that implements the `dispatch` function to act as a `MainActorActionHandler`
    /// - Parameter realHandler: a function with the same signature of `MainActorActionHandler.dispatch`
    public init(_ realHandler: @MainActor @escaping (DispatchedAction<ActionType>) -> Void) {
        self.realHandler = realHandler
    }

    /// The function that allows Views, ViewControllers, Presenters to dispatch actions to the store.
    /// Also way for a `Middleware` to trigger their own actions, usually in response to events or async operations.
    /// - Parameters:
    ///   - dispatchedAction: struct holding the action (action to be dispatched) + dispatcher (information about the action source, containing
    ///                       file/line, function and additional information for debugging and logging purposes)
    public func dispatch(_ dispatchedAction: DispatchedAction<ActionType>) {
        realHandler(dispatchedAction)
    }
}

extension MainActorActionHandler {
    /// Erases the provided `MainActorActionHandler` by using its inner methods from a newly created wrapper of type `AnyActionHandler`
    public func eraseAnyMainActorActionHandler() -> AnyMainActorActionHandler<ActionType> {
        AnyMainActorActionHandler(self)
    }

    public func eraseAnyActionHandler() -> AnyActionHandler<ActionType> {
        AnyActionHandler { output in
            Thread.asap {
                self.dispatch(output)
            }
        }
    }
}
