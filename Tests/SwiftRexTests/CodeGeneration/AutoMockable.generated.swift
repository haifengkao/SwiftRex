// Generated using Sourcery 2.1.8 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all
import Foundation
@testable import SwiftRex
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif













final class ActionHandlerMock<ActionType: Sendable>: SendableActionHandler {

    //MARK: - dispatch

    nonisolated(unsafe) var dispatchCallsCount = 0
    var dispatchCalled: Bool {
        return dispatchCallsCount > 0
    }
    nonisolated(unsafe) var dispatchReceivedDispatchedAction: DispatchedAction<ActionType>?
    nonisolated(unsafe) var dispatchClosure: ((DispatchedAction<ActionType>) -> Void)?

    func dispatch(_ dispatchedAction: DispatchedAction<ActionType>) {
        dispatchCallsCount += 1
        dispatchReceivedDispatchedAction = dispatchedAction
        dispatchClosure?(dispatchedAction)
    }

}
class MiddlewareProtocolMock<InputActionType: Sendable, OutputActionType: Sendable, StateType: Sendable>: MiddlewareProtocol, @unchecked Sendable {

    //MARK: - handle

    var handleActionFromStateCallsCount = 0
    var handleActionFromStateCalled: Bool {
        return handleActionFromStateCallsCount > 0
    }
    var handleActionFromStateReceivedArguments: (action: InputActionType, dispatcher: ActionSource, state: GetState<StateType>)?
    var handleActionFromStateReturnValue: IO<OutputActionType>!
    var handleActionFromStateClosure: (@MainActor (InputActionType, ActionSource, @escaping GetState<StateType>) -> IO<OutputActionType>)?

    func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType> {
        handleActionFromStateCallsCount += 1
        handleActionFromStateReceivedArguments = (action: action, dispatcher: dispatcher, state: state)
        return handleActionFromStateClosure.map({ $0(action, dispatcher, state) }) ?? handleActionFromStateReturnValue
    }

}
final class ReduxStoreProtocolMock<ActionType: Sendable, StateType: Sendable>: ReduxStoreProtocol, @unchecked Sendable {
    var actionHandler: ReduxPipelineWrapper<MiddlewareType>  {
        underlyingPipeline
    }
    
    var pipeline: ReduxPipelineWrapper<MiddlewareType> {
        get { return underlyingPipeline }
        set(value) { underlyingPipeline = value }
    }
    var underlyingPipeline: ReduxPipelineWrapper<MiddlewareType>!
    var statePublisher: UnfailablePublisherType<StateType> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    var underlyingStatePublisher: UnfailablePublisherType<StateType>!

}
class StateProviderMock<StateType: Sendable>: StateProvider {
    var statePublisher: UnfailablePublisherType<StateType> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    var underlyingStatePublisher: UnfailablePublisherType<StateType>!

}
final class StoreTypeMock<ActionType: Sendable, StateType: Sendable>: StoreType, ActionHandler, @unchecked Sendable {
    /// HasActionHandler conformance
    var actionHandler: StoreTypeMock<ActionType, StateType> { self }
    
    var statePublisher: UnfailablePublisherType<StateType> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    var underlyingStatePublisher: UnfailablePublisherType<StateType>!

    //MARK: - dispatch

    var dispatchCallsCount = 0
    var dispatchCalled: Bool {
        return dispatchCallsCount > 0
    }
    var dispatchReceivedDispatchedAction: DispatchedAction<ActionType>?
    var dispatchClosure: ((DispatchedAction<ActionType>) -> Void)?

    func dispatch(_ dispatchedAction: DispatchedAction<ActionType>) {
        dispatchCallsCount += 1
        dispatchReceivedDispatchedAction = dispatchedAction
        dispatchClosure?(dispatchedAction)
    }
}
