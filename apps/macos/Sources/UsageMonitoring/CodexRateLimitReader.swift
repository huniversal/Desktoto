import Boundaries
import Domain
import Foundation

public actor CodexRateLimitReader {
    public private(set) var latest: ToolUsage?
    private let files: any FileSystem
    private let launcher: any ProcessLauncher
    private let time: any TimeSource
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private let onUpdate: @Sendable () async -> Void
    private var enabled = true
    private var requesting = false
    private var lastRequest = Date.distantPast
    private var blockedUntil = Date.distantPast
    private var process: (any RunningProcess)?
    private var outputTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private var pending: [Int: CheckedContinuation<JSONValue?, Never>] = [:]
    private var deadlines: [Int: Task<Void, Never>] = [:]
    private var nextID = 1
    private var generation = 0
    private var initialized = false
    private var buffer = Data()

    public init(
        fileSystem: any FileSystem = LiveFileSystem(),
        launcher: any ProcessLauncher = SystemProcessLauncher(),
        timeSource: any TimeSource = SystemTimeSource(),
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) },
        onUpdate: @escaping @Sendable () async -> Void = {}
    ) {
        files = fileSystem
        self.launcher = launcher
        time = timeSource
        self.sleep = sleep
        self.onUpdate = onUpdate
    }

    public func setEnabled(_ value: Bool) {
        enabled = value
        if !value { stop() }
    }

    public func stop() {
        generation += 1
        idleTask?.cancel()
        idleTask = nil
        outputTask?.cancel()
        outputTask = nil
        process?.terminate()
        process = nil
        initialized = false
        buffer = Data()
        let handlers = pending.values
        pending = [:]
        deadlines.values.forEach { $0.cancel() }
        deadlines = [:]
        handlers.forEach { $0.resume(returning: nil) }
        requesting = false
    }

    public func refresh(minInterval: TimeInterval) async {
        let now = time.now
        guard !Task.isCancelled, enabled, !requesting, now >= blockedUntil, now.timeIntervalSince(lastRequest) >= minInterval else { return }
        requesting = true
        lastRequest = now
        idleTask?.cancel()
        guard process != nil || launch() else {
            requesting = false
            blockedUntil = now.addingTimeInterval(findBinary() == nil ? 600 : 120)
            return
        }
        let current = generation
        if !initialized {
            let response = await request(method: "initialize", params: ["clientInfo": ["name": "ai-run", "version": "1"]])
            guard generation == current else { return }
            guard response != nil, send(["method": "initialized"]) else { fail(); return }
            initialized = true
        }
        let result = await request(method: "account/rateLimits/read", params: nil)
        guard generation == current else { return }
        guard let limits = result?["rateLimits"], let usage = UsageParser.codex(limits, live: true, updatedAt: time.now) else { fail(); return }
        latest = usage
        requesting = false
        let sleep = sleep
        idleTask = Task { [weak self] in
            do { try await sleep(60) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.idleShutdown(generation: current)
        }
        await onUpdate()
    }

    private func idleShutdown(generation expected: Int) {
        if generation == expected, !requesting { stop() }
    }

    private func fail() {
        blockedUntil = time.now.addingTimeInterval(120)
        stop()
    }

    private func findBinary() -> URL? {
        let relative = ["Applications/Codex.app/Contents/Resources/codex-cli/bin/codex", ".local/bin/codex", ".npm-global/bin/codex", ".bun/bin/codex"]
        let absolute = ["/Applications/Codex.app/Contents/Resources/codex-cli/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
        return (relative.map { files.homeDirectory.appendingPathComponent($0) } + absolute.map { URL(fileURLWithPath: $0) }).first { files.isExecutable(at: $0) }
    }

    private func launch() -> Bool {
        guard let binary = findBinary() else { return false }
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = [environment["PATH"], "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"].compactMap { $0 }.joined(separator: ":")
        do { process = try launcher.launch(executable: binary, arguments: ["app-server"], environment: environment) } catch { return false }
        generation += 1
        let current = generation
        guard let stream = process?.output else { return false }
        outputTask = Task { [weak self] in
            for await data in stream {
                guard !Task.isCancelled else { return }
                await self?.receive(data, generation: current)
            }
            await self?.exited(generation: current)
        }
        return true
    }

    private func exited(generation expected: Int) {
        guard generation == expected else { return }
        if requesting { fail() } else { stop() }
    }

    private func request(method: String, params: [String: Any]?) async -> JSONValue? {
        let id = nextID
        nextID += 1
        let expected = generation
        return await withTaskCancellationHandler {
            await enqueueRequest(id: id, method: method, params: params)
        } onCancel: {
            Task { await self.cancelRequest(id: id, generation: expected) }
        }
    }

    private func cancelRequest(id: Int, generation expected: Int) {
        if generation == expected, pending[id] != nil { stop() }
    }

    private func enqueueRequest(id: Int, method: String, params: [String: Any]?) async -> JSONValue? {
        guard !Task.isCancelled else { stop(); return nil }
        return await withCheckedContinuation { continuation in
            pending[id] = continuation
            var message: [String: Any] = ["id": id, "method": method]
            if let params { message["params"] = params }
            guard send(message) else { fail(); return }
            let sleep = sleep
            let current = generation
            deadlines[id] = Task { [weak self] in
                do { try await sleep(15) } catch { return }
                guard !Task.isCancelled else { return }
                await self?.timeout(id: id, generation: current)
            }
        }
    }

    private func timeout(id: Int, generation expected: Int) {
        guard generation == expected, pending[id] != nil else { return }
        fail()
    }

    private func send(_ message: [String: Any]) -> Bool {
        guard let process, var bytes = try? JSONSerialization.data(withJSONObject: message, options: [.withoutEscapingSlashes]) else { return false }
        bytes.append(10)
        do { try process.write(bytes); return true } catch { return false }
    }

    private func receive(_ data: Data, generation expected: Int) async {
        guard generation == expected else { return }
        buffer.append(data)
        for line in UsageParser.takeCompleteLines(from: &buffer) {
            guard let message = JSONValue.parseObject(from: line) else { continue }
            if let id = message["id"]?.intValue, let handler = pending.removeValue(forKey: id) {
                deadlines.removeValue(forKey: id)?.cancel()
                handler.resume(returning: message["error"] == nil ? message["result"] : nil)
            } else if message["method"]?.stringValue == "account/rateLimits/updated",
                      let limits = message["params"]?["rateLimits"],
                      let usage = UsageParser.codex(limits, live: true, updatedAt: time.now) {
                latest = usage
                await onUpdate()
                guard generation == expected else { return }
            }
        }
    }
}
