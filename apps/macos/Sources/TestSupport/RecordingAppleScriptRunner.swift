import Boundaries
import Synchronization

// 받은 스크립트를 기록하고, 스크립트 내용에 따라 정해 둔 결과를 돌려주는 가짜 AppleScriptRunner.
public final class RecordingAppleScriptRunner: AppleScriptRunner {
    private let handler: @Sendable (String) throws -> Bool
    private let recordedSources = Mutex<[String]>([])

    public init(handler: @escaping @Sendable (String) throws -> Bool) {
        self.handler = handler
    }

    public var sources: [String] {
        recordedSources.withLock { $0 }
    }

    public func runReturningBoolean(source: String) throws -> Bool {
        recordedSources.withLock { $0.append(source) }
        return try handler(source)
    }
}
