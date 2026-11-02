import Boundaries
import Foundation
import Testing
@testable import ClaudeIntegration

struct ScriptTests {
    /// 합성 입력만 보내고 프로세스의 HOME을 임시 폴더로 제한한다.
    private func run(_ arguments: [String], input: String, home: URL) throws -> (output: String, status: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = arguments
        process.environment = ["HOME": home.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        try process.run()
        try stdin.fileHandleForWriting.write(contentsOf: Data(input.utf8))
        try stdin.fileHandleForWriting.close()
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (String(decoding: output, as: UTF8.self), process.terminationStatus)
    }

    @Test func hookUsesTranscriptNameThenSessionIDAndSkipsEmptyID() throws {
        let root = try temporaryIntegrationDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let hook = integrationResources().appendingPathComponent("ai-run-hook.sh").path
        let started = Int(Date().timeIntervalSince1970)
        let transcript = try run([hook], input: #"{"transcript_path":"/synthetic/transcript-id.jsonl","session_id":"fallback-id"}"#, home: root)
        #expect(transcript.status == 0)
        let waiting = root.appendingPathComponent(".ai-run/waiting")
        let timestamp = try String(contentsOf: waiting.appendingPathComponent("transcript-id"), encoding: .utf8)
        #expect(try #require(Int(timestamp.trimmingCharacters(in: .whitespacesAndNewlines))) >= started)
        #expect(!FileManager.default.fileExists(atPath: waiting.appendingPathComponent("fallback-id").path))
        #expect(try run([hook], input: #"{"session_id":"fallback-id"}"#, home: root).status == 0)
        #expect(FileManager.default.fileExists(atPath: waiting.appendingPathComponent("fallback-id").path))
        #expect(try run([hook], input: "{}", home: root).status == 0)
        #expect(try FileManager.default.contentsOfDirectory(atPath: waiting.path).count == 2)
    }

    @Test func generatedCommandSavesExactInputAndForwardsItToOriginalCommand() async throws {
        let root = try temporaryIntegrationDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        // 경로와 명령에 작은따옴표가 있어도 실제 셸에서 인자와 입력이 유지되어야 한다.
        let input = #"{"session_id":"synthetic-id","rate_limits":{"five_hour":{"used_percentage":17}}}"#
        let original = "printf '%s\\n' \"user's status\"; cat"
        let files = LiveSettingsFileSystem(homeDirectory: root)
        let settingsURL = root.appendingPathComponent(".claude/settings.json")
        try files.writeAtomically(ClaudeSettings.serialize(["statusLine": ["type": "command", "command": original]]), to: settingsURL)
        let service = ClaudeIntegration(fileSystem: files, resourceDirectory: integrationResources())
        #expect(await service.connect() == .connected)
        let updated = try ClaudeSettings.parse(try #require(try files.read(at: settingsURL)))
        let command = try #require((updated["statusLine"] as? [String: Any])?["command"] as? String)
        let result = try run(["-c", command], input: input, home: root)
        #expect(result.status == 0)
        #expect(result.output == "user's status\n" + input)
        let status = root.appendingPathComponent(".ai-run/status/synthetic-id.json")
        #expect(try String(contentsOf: status, encoding: .utf8) == input)
        #expect(!FileManager.default.fileExists(atPath: status.path + ".tmp"))
    }

    @Test func noSessionStillRunsOriginalAndNoOriginalProducesNoOutput() throws {
        let root = try temporaryIntegrationDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let script = integrationResources().appendingPathComponent("ai-run-statusline.sh").path
        let result = try run([script, "cat"], input: "{}", home: root)
        #expect(result.output == "{}")
        #expect(result.status == 0)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".ai-run/status").path))
        #expect(try run([script], input: #"{"session_id":"simple"}"#, home: root).output.isEmpty)
        #expect(try run([script, "exit 9"], input: "{}", home: root).status == 0)
    }
}
