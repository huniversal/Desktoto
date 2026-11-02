import Boundaries
import Foundation
import TestSupport
import Testing
@testable import UsageMonitoring

private struct FinalResponseProcess: ProcessLauncher, RunningProcess {
    let output: AsyncStream<Data>
    private let continuation: AsyncStream<Data>.Continuation
    let closesAfterResponse: Bool

    init(closesAfterResponse: Bool) {
        self.closesAfterResponse = closesAfterResponse
        (output, continuation) = AsyncStream.makeStream()
    }

    func launch(executable: URL, arguments: [String], environment: [String: String]) throws -> any RunningProcess { self }

    func write(_ bytes: Data) throws {
        guard let message = JSONValue.parseObject(from: bytes), let id = message["id"]?.intValue else { return }
        if message["method"]?.stringValue == "initialize" {
            continuation.yield(Data("{\"id\":\(id),\"result\":{}}\n".utf8))
            return
        }
        var response = "{\"id\":\(id),\"result\":{\"rateLimits\":{\"primary\":{\"usedPercent\":10,\"windowDurationMins\":300}}}}\n"
        if !closesAfterResponse {
            response += #"{"method":"account/rateLimits/updated","params":{"rateLimits":{"primary":{"usedPercent":60,"windowDurationMins":300}}}}"# + "\n"
        }
        continuation.yield(Data(response.utf8))
        if closesAfterResponse { continuation.finish() }
    }

    func terminate() { continuation.finish() }
}

struct ResponseOrderingTests {
    private func reader(closesAfterResponse: Bool) -> CodexRateLimitReader {
        let files = InMemoryFileSystem()
        files.addFile(at: files.homeDirectory.appendingPathComponent(".local/bin/codex"), text: "", modifiedAt: Date())
        return CodexRateLimitReader(fileSystem: files, launcher: FinalResponseProcess(closesAfterResponse: closesAfterResponse))
    }

    @Test func laterNotificationInSameChunkWinsOverResponse() async {
        let reader = reader(closesAfterResponse: false)
        await reader.refresh(minInterval: 0)
        #expect(await reader.latest?.fiveHour?.usedRatio == 0.6)
        await reader.stop()
    }

    @Test func successfulResponseImmediatelyBeforeEOFSurvives() async {
        let reader = reader(closesAfterResponse: true)
        await reader.refresh(minInterval: 0)
        #expect(await reader.latest?.fiveHour?.usedRatio == 0.1)
        await reader.stop()
    }
}
