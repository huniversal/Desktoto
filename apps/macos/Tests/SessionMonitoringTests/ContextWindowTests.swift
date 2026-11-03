import Boundaries
import Foundation
import Testing
import TestSupport
@testable import SessionMonitoring

private func makeResolver(_ fileSystem: InMemoryFileSystem, environment: [String: String] = [:]) -> ContextWindowResolver {
    ContextWindowResolver(fileSystem: fileSystem, environment: environment)
}

private func addFile(_ fileSystem: InMemoryFileSystem, _ relativePath: String, _ json: String) {
    fileSystem.addFile(at: fileSystem.homeDirectory.appendingPathComponent(relativePath), text: json, modifiedAt: referenceNow)
}

// MARK: - 1. statusLine 파일

@Test func statusLineWindowWinsOverEverything() {
    let fileSystem = InMemoryFileSystem()
    addFile(fileSystem, ".ai-run/status/s1.json", #"{"context_window":{"context_window_size":500000},"model":{"id":"claude-opus-4-7"}}"#)
    addFile(fileSystem, ".ai-run/config.json", #"{"windows":{"claude-opus":123}}"#)

    let resolution = makeResolver(fileSystem).resolve(sessionID: "s1", modelName: "claude-opus-4-7", usedTokens: 10, workingDirectory: nil)

    #expect(resolution == WindowResolution(tokens: 500_000, isEstimated: false))
}

@Test func statusLineWindowIsIgnoredWhenSavedModelDiffers() {
    let fileSystem = InMemoryFileSystem()
    addFile(fileSystem, ".ai-run/status/s1.json", #"{"context_window":{"context_window_size":500000},"model":{"id":"claude-sonnet-4-5"}}"#)

    let resolution = makeResolver(fileSystem).resolve(sessionID: "s1", modelName: "claude-opus-4-6", usedTokens: nil, workingDirectory: nil)

    #expect(resolution == WindowResolution(tokens: 200_000, isEstimated: true))
}

@Test func statusLineWindowWithZeroSizeIsIgnored() {
    let fileSystem = InMemoryFileSystem()
    addFile(fileSystem, ".ai-run/status/s1.json", #"{"context_window":{"context_window_size":0}}"#)

    let resolution = makeResolver(fileSystem).resolve(sessionID: "s1", modelName: "claude-opus-4-6", usedTokens: nil, workingDirectory: nil)

    #expect(resolution.tokens == 200_000)
}

// MARK: - 2. config.json

@Test func configWindowUsesLongestMatchingPrefix() {
    let fileSystem = InMemoryFileSystem()
    addFile(fileSystem, ".ai-run/config.json", #"{"windows":{"claude-opus":300000,"claude-opus-4-6":1000000,"claude-sonnet":150000}}"#)

    let resolution = makeResolver(fileSystem).resolve(sessionID: "s1", modelName: "claude-opus-4-6-20260101", usedTokens: nil, workingDirectory: nil)

    #expect(resolution == WindowResolution(tokens: 1_000_000, isEstimated: false))
}

@Test func configWindowWithoutMatchingPrefixFallsThrough() {
    let fileSystem = InMemoryFileSystem()
    addFile(fileSystem, ".ai-run/config.json", #"{"windows":{"gpt":128000}}"#)

    let resolution = makeResolver(fileSystem).resolve(sessionID: "s1", modelName: "claude-opus-4-6", usedTokens: nil, workingDirectory: nil)

    #expect(resolution == WindowResolution(tokens: 200_000, isEstimated: true))
}

// MARK: - 3. 모델 이름 규칙과 설정

@Test(arguments: [
    ("claude-opus-4-6", 200_000, true),
    ("claude-opus-4-7", 1_000_000, false),
    ("claude-opus-4-7-20260101", 1_000_000, false),
    ("claude-opus-5-0", 1_000_000, false),
    ("claude-sonnet-4-6", 200_000, true),
    ("claude-sonnet-5", 1_000_000, false),
    ("claude-sonnet-5-5", 1_000_000, false),
    ("claude-haiku-5-4", 200_000, true),
    ("claude-haiku-5-5", 1_000_000, false),
    ("claude-haiku-4-5-20251001", 200_000, true),
    ("claude-fable-5-1", 1_000_000, false),
    ("gpt-5", 200_000, true)
])
func infersWindowFromModelName(modelName: String, tokens: Int, isEstimated: Bool) {
    let resolution = makeResolver(InMemoryFileSystem()).resolve(sessionID: "s1", modelName: modelName, usedTokens: nil, workingDirectory: nil)

    #expect(resolution == WindowResolution(tokens: tokens, isEstimated: isEstimated))
}

@Test func missingModelNameIsEstimatedDefault() {
    let resolution = makeResolver(InMemoryFileSystem()).resolve(sessionID: "s1", modelName: nil, usedTokens: nil, workingDirectory: nil)

    #expect(resolution == WindowResolution(tokens: 200_000, isEstimated: true))
}

@Test func extendedVariantSettingMakesOlderModelsOneMillion() {
    let fileSystem = InMemoryFileSystem()
    addFile(fileSystem, ".claude/settings.json", #"{"model":"opus[1m]"}"#)

    let resolution = makeResolver(fileSystem).resolve(sessionID: "s1", modelName: "claude-opus-4-6", usedTokens: nil, workingDirectory: nil)

    #expect(resolution == WindowResolution(tokens: 1_000_000, isEstimated: false))
}

@Test func opusPlanExtendedVariantCoversOpusAndSonnetButNotHaiku() {
    let fileSystem = InMemoryFileSystem()
    addFile(fileSystem, ".claude/settings.json", #"{"model":"opusplan[1m]"}"#)
    let resolver = makeResolver(fileSystem)

    #expect(resolver.resolve(sessionID: "s", modelName: "claude-sonnet-4-6", usedTokens: nil, workingDirectory: nil).tokens == 1_000_000)
    #expect(resolver.resolve(sessionID: "s", modelName: "claude-haiku-4-5", usedTokens: nil, workingDirectory: nil).tokens == 200_000)
}

@Test func projectSettingsOverrideUserSettings() {
    let fileSystem = InMemoryFileSystem()
    addFile(fileSystem, ".claude/settings.json", #"{"model":"opus[1m]"}"#)
    fileSystem.addFile(at: URL(fileURLWithPath: "/Users/test/work/app/.claude/settings.local.json"), text: #"{"model":"sonnet"}"#, modifiedAt: referenceNow)

    let resolution = makeResolver(fileSystem).resolve(sessionID: "s1", modelName: "claude-opus-4-6", usedTokens: nil, workingDirectory: "/Users/test/work/app")

    #expect(resolution == WindowResolution(tokens: 200_000, isEstimated: true))
}

@Test func disableOneMillionSettingForcesDefaultWindowEvenForOneMillionModels() {
    let byFile = InMemoryFileSystem()
    addFile(byFile, ".claude/settings.json", #"{"env":{"CLAUDE_CODE_DISABLE_1M_CONTEXT":"1"}}"#)
    let byBoolean = InMemoryFileSystem()
    addFile(byBoolean, ".claude/settings.json", #"{"env":{"CLAUDE_CODE_DISABLE_1M_CONTEXT":true}}"#)

    let expected = WindowResolution(tokens: 200_000, isEstimated: false)
    #expect(makeResolver(byFile).resolve(sessionID: "s", modelName: "claude-opus-4-7", usedTokens: nil, workingDirectory: nil) == expected)
    #expect(makeResolver(byBoolean).resolve(sessionID: "s", modelName: "claude-opus-4-7", usedTokens: nil, workingDirectory: nil) == expected)
    #expect(makeResolver(InMemoryFileSystem(), environment: ["CLAUDE_CODE_DISABLE_1M_CONTEXT": "TRUE"])
        .resolve(sessionID: "s", modelName: "claude-opus-4-7", usedTokens: nil, workingDirectory: nil) == expected)
    #expect(makeResolver(InMemoryFileSystem(), environment: ["CLAUDE_CODE_DISABLE_1M_CONTEXT": "0"])
        .resolve(sessionID: "s", modelName: "claude-opus-4-7", usedTokens: nil, workingDirectory: nil).tokens == 1_000_000)
}

// MARK: - 4. 사용량 보정

@Test func usageAboveEstimatedWindowMeansOneMillion() {
    let resolver = makeResolver(InMemoryFileSystem())

    let over = resolver.resolve(sessionID: "s", modelName: "claude-opus-4-6", usedTokens: 200_001, workingDirectory: nil)
    let atLimit = resolver.resolve(sessionID: "s", modelName: "claude-opus-4-6", usedTokens: 200_000, workingDirectory: nil)

    #expect(over == WindowResolution(tokens: 1_000_000, isEstimated: false))
    #expect(atLimit == WindowResolution(tokens: 200_000, isEstimated: true))
}

@Test func sessionInfoCarriesResolvedWindowOnlyWhenTokensExist() async {
    let harness = Harness()
    addFile(harness.fileSystem, ".ai-run/status/s1.json", #"{"context_window":{"context_window_size":400000}}"#)
    harness.addClaudeLog(id: "s1", lines: [
        ClaudeLine.assistant(at: harness.ago(20), stopReason: "tool_use", model: "claude-opus-4-6", usage: (input: 7, cacheCreation: 0, cacheRead: 0))
    ])
    let monitor = harness.makeMonitor()

    _ = await monitor.sessionStates()
    let info = await monitor.sessionInfo(id: "s1")

    #expect(info?.windowTokens == 400_000)
    #expect(info?.isWindowEstimated == false)
}
