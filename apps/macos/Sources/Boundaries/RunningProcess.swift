import Foundation

public protocol RunningProcess: Sendable {
    var output: AsyncStream<Data> { get }
    func write(_ data: Data) throws
    func terminate()
}

public protocol ProcessLauncher: Sendable {
    func launch(executable: URL, arguments: [String], environment: [String: String]) throws -> any RunningProcess
}

public struct SystemProcessLauncher: ProcessLauncher {
    public init() {}
    public func launch(executable: URL, arguments: [String], environment: [String: String]) throws -> any RunningProcess {
        try PipeProcess(executable: executable, arguments: arguments, environment: environment)
    }
}

/// Foundation Process와 입력 핸들은 잠금으로 직렬화하고, 출력은 단일 스트림으로 전달한다.
private final class PipeProcess: RunningProcess, @unchecked Sendable {
    let output: AsyncStream<Data>
    private let continuation: AsyncStream<Data>.Continuation
    private let process = Process()
    private let input = Pipe()
    private let stdout = Pipe()
    private let lock = NSLock()
    private var closed = false

    init(executable: URL, arguments: [String], environment: [String: String]) throws {
        (output, continuation) = AsyncStream.makeStream()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.standardInput = input
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        // 원본과 같이 닫힌 파이프 쓰기를 SIGPIPE 종료 대신 오류로 받는다.
        signal(SIGPIPE, SIG_IGN)
        let continuation = continuation
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let bytes = handle.availableData
            if bytes.isEmpty {
                handle.readabilityHandler = nil
                continuation.finish()
            } else { continuation.yield(bytes) }
        }
        do { try process.run() } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            continuation.finish()
            throw error
        }
    }

    func write(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { throw CocoaError(.fileWriteUnknown) }
        try input.fileHandleForWriting.write(contentsOf: data)
    }

    func terminate() {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return }
        closed = true
        stdout.fileHandleForReading.readabilityHandler = nil
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
        continuation.finish()
    }

    deinit { terminate() }
}
