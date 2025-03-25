/**
 Zero-argument function that returns the current state. <br/>
 `() -> StateType`
 */
public typealias GetState<StateType> = @Sendable () -> StateType

/**
 State reducer: takes inout version of the current state and an action, computes the new state changing the provided mutable state. <br/>
 `(ActionType, inout StateType) -> Void`
 */
public typealias MutableReduceFunction<ActionType, StateType> = @Sendable (ActionType, inout StateType) -> Void
