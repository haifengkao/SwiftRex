import Foundation

public struct ReduxPipelineWrapper<MiddlewareType: Middleware>: ActionHandler
    where MiddlewareType.InputActionType == MiddlewareType.OutputActionType {
    public typealias ActionType = MiddlewareType.InputActionType
    public typealias StateType = MiddlewareType.StateType

    private var onAction: (ActionType, ActionSource) -> Void

    public init(
        state: UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware: MiddlewareType,
        emitsValue: ShouldEmitValue<StateType>
    ) {
        DispatchQueue.setMainQueueID()

        let onAction: (ActionType, ActionSource) -> Void = { action, dispatcher in
            var afterReducer: AfterReducer = .doNothing()
            middleware.handle(action: action, from: dispatcher, afterReducer: &afterReducer)

            state.mutate(
                when: { $0 },
                action: { value in
                    switch emitsValue {
                    case .always:
                        reducer.reduce(action, &value)
                        return true
                    case .never:
                        return false
                    case let .when(predicate):
                        var newValue = value
                        reducer.reduce(action, &newValue)
                        guard predicate(value, newValue) else { return false }
                        value = newValue
                        return true
                    }
                }
            )

            afterReducer.reducerIsDone()
        }

        middleware.receiveContext(
            getState: { state.value() },
            output: .init { action, dispatcher in
                DispatchQueue.main.async {
                    onAction(action, dispatcher)
                }
            }
        )

        self.onAction = onAction
    }

    public func dispatch(_ action: MiddlewareType.InputActionType, from dispatcher: ActionSource) {
        DispatchQueue.asap {
            self.onAction(action, dispatcher)
        }
    }
}

extension ReduxPipelineWrapper where StateType: Equatable {
    public init(
        state: UnfailableReplayLastSubjectType<StateType>,
        reducer: Reducer<ActionType, StateType>,
        middleware: MiddlewareType
    ) {
        self.init(state: state, reducer: reducer, middleware: middleware, emitsValue: .whenDifferent)
    }
}
