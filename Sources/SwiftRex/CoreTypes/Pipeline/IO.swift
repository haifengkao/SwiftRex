import Foundation

public struct IO<OutputActionType: Sendable> {
    // Store an array of runIO to be executed
    fileprivate let runIOs: [(AnyMainActorActionHandler<OutputActionType>) -> Void]

    public init(_ run: @escaping (AnyMainActorActionHandler<OutputActionType>) -> Void) {
        self.runIOs = [run]
    }
    
    // Internal initializer with an array of actions
    fileprivate init(runIOs: [(AnyMainActorActionHandler<OutputActionType>) -> Void]) {
        self.runIOs = runIOs
    }

    public static func pure() -> IO {
        IO(runIOs: [])
    }

    public func run(_ output: AnyMainActorActionHandler<OutputActionType>) {
        // Execute all runIO sequentially with the same output handler
        for runIO in runIOs {
            runIO(output)
        }
    }

    public func run(_ output: @MainActor @escaping (DispatchedAction<OutputActionType>) -> Void) {
        run(.init(output))
    }
}

extension IO: Monoid {
    public static var identity: IO { .pure() }
}

public func <> <OutputActionType>(lhs: IO<OutputActionType>, rhs: IO<OutputActionType>) -> IO<OutputActionType> {
    // Combine arrays of runIO instead of nesting calls
    .init(runIOs: lhs.runIOs + rhs.runIOs)
}

extension IO {
    public func map<B>(_ transform: @Sendable @escaping (OutputActionType) -> B) -> IO<B> {
        IO<B> { output in
            self.run(output.contramap(transform))
        }
    }
}

extension IO {
    public func flatMap<B>(_ transform: @Sendable @escaping (DispatchedAction<OutputActionType>) -> IO<B>) -> IO<B> {
        IO<B> { actionHandlerB in
            self.run(.init { outputActionType in
                transform(outputActionType).run(actionHandlerB)
            })
        }
    }
}
