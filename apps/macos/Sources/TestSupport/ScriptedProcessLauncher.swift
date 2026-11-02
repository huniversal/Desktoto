import Boundaries
import Foundation
import Synchronization

/// JSON-RPC 입력에 합성 응답 조각을 돌려주는 프로세스. 실제 명령은 실행하지 않는다.
public final class ScriptedProcessLauncher: ProcessLauncher, RunningProcess {
    public let output: AsyncStream<Data>
    private let continuation: AsyncStream<Data>.Continuation
    private let responder: @Sendable (Data) throws -> [Data]
    private struct State {
        var writes: [Data] = []
        var launches = 0
        var terminations = 0
    }
    private let state = Mutex(State())

    public init(responder: @escaping @Sendable (Data) throws -> [Data]) {
        self.responder = responder
        (output, continuation) = AsyncStream.makeStream()
    }

    public var writes: [Data] { state.withLock { $0.writes } }
    public var launchCount: Int { state.withLock { $0.launches } }
    public var terminationCount: Int { state.withLock { $0.terminations } }

    public func launch(executable: URL, arguments: [String], environment: [String: String]) throws -> any RunningProcess {
        state.withLock { $0.launches += 1 }
        return self
    }

    public func write(_ data: Data) throws {
        state.withLock { $0.writes.append(data) }
        for chunk in try responder(data) { continuation.yield(chunk) }
    }

    public func emit(_ data: Data) { continuation.yield(data) }

    public func terminate() {
        state.withLock { $0.terminations += 1 }
        continuation.finish()
    }
}
