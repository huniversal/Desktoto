import Boundaries
import Foundation

/// 같은 인스턴스의 연결과 해제를 직렬화한다. 영속 설정과 UI 조립은 앱의 책임이다.
public actor ClaudeIntegration {
    public enum Failure: Error, Sendable, Equatable {
        case invalidSettings
        case unsupportedHooks
        case unsupportedStatusLine
        case cannotRestoreStatusLine
        case missingScript(String)
        case fileOperation(String)
    }

    public enum Result: Sendable, Equatable {
        case connected
        case alreadyConnected
        case disconnected
        case alreadyDisconnected
        case skipped
        case failed(Failure)
    }

    public enum ConnectionState: Sendable, Equatable {
        case disconnected
        case partial(hook: Bool, statusLine: Bool)
        case connected
        case failed(Failure)
    }

    private let files: any SettingsFileSystem
    private let clock: any TimeSource
    private let settingsURL: URL
    private let resourceDirectory: URL
    private let binDirectory: URL

    public init(
        fileSystem: any SettingsFileSystem,
        resourceDirectory: URL,
        settingsURL: URL? = nil,
        binDirectory: URL? = nil,
        timeSource: any TimeSource = SystemTimeSource()
    ) {
        files = fileSystem
        clock = timeSource
        self.resourceDirectory = resourceDirectory
        self.settingsURL = settingsURL ?? fileSystem.homeDirectory.appendingPathComponent(".claude/settings.json")
        self.binDirectory = binDirectory ?? fileSystem.homeDirectory.appendingPathComponent(".ai-run/bin")
    }

    public func connectionState() -> ConnectionState {
        do {
            let url = files.resolvingSymlinks(at: settingsURL)
            guard let data = try files.read(at: url) else { return .disconnected }
            let settings = try ClaudeSettings.parse(data)
            let hook = ClaudeSettings.hasHook(settings)
            let status = ClaudeSettings.hasStatusLine(settings, hasStatusSaver: hasStatusSaver)
            if hook && status { return .connected }
            if hook || status { return .partial(hook: hook, statusLine: status) }
            return .disconnected
        } catch { return .failed(failure(from: error)) }
    }

    /// false이면 파일 조회와 쓰기 모두 건너뛴다. 최초 실행 기본값은 여기서 정하지 않는다.
    public func connectOnStartup(ifAllowed isAllowed: Bool) -> Result {
        guard isAllowed, files.directoryExists(at: files.homeDirectory.appendingPathComponent(".claude")) else { return .skipped }
        return connect()
    }

    public func connect() -> Result {
        do {
            let url = files.resolvingSymlinks(at: settingsURL)
            let original = try files.read(at: url)
            let settings = try ClaudeSettings.parse(original ?? Data())
            let updated = try ClaudeSettings.connecting(
                settings,
                hookPath: binDirectory.appendingPathComponent(ClaudeSettings.hookScript).path,
                statusPath: binDirectory.appendingPathComponent(ClaudeSettings.statusScript).path,
                hasStatusSaver: hasStatusSaver
            )
            guard !NSDictionary(dictionary: settings).isEqual(to: updated) else {
                try refreshInstalledScripts()
                return .alreadyConnected
            }
            // 두 리소스를 먼저 읽어 누락 시 한쪽만 설치되는 일을 피한다.
            let scripts = try [ClaudeSettings.hookScript, ClaudeSettings.statusScript].map { name in
                guard let data = try files.read(at: resourceDirectory.appendingPathComponent(name)) else {
                    throw Failure.missingScript(name)
                }
                return (name, data)
            }
            let output = try ClaudeSettings.serialize(updated)
            for (name, data) in scripts {
                try files.writeAtomically(data, to: binDirectory.appendingPathComponent(name))
            }
            if original != nil { try backup(at: url) }
            try files.writeAtomically(output, to: url)
            return .connected
        } catch { return .failed(failure(from: error)) }
    }

    /// 이미 연결된 유저도 앱을 업데이트하면 새 스크립트를 쓰게 한다. 설치된 적 있는 스크립트만 번들 내용으로 교체하고 settings는 건드리지 않는다.
    private func refreshInstalledScripts() throws {
        for name in [ClaudeSettings.hookScript, ClaudeSettings.statusScript] {
            let installedURL = binDirectory.appendingPathComponent(name)
            guard let installed = try files.read(at: installedURL),
                  let bundled = try files.read(at: resourceDirectory.appendingPathComponent(name)),
                  installed != bundled else { continue }
            try files.writeAtomically(bundled, to: installedURL)
        }
    }

    public func disconnect() -> Result {
        do {
            let url = files.resolvingSymlinks(at: settingsURL)
            guard let original = try files.read(at: url) else { return .alreadyDisconnected }
            let settings = try ClaudeSettings.parse(original)
            let updated = try ClaudeSettings.disconnecting(settings)
            guard !NSDictionary(dictionary: settings).isEqual(to: updated) else { return .alreadyDisconnected }
            let output = try ClaudeSettings.serialize(updated)
            try backup(at: url)
            try files.writeAtomically(output, to: url)
            return .disconnected
        } catch { return .failed(failure(from: error)) }
    }

    private func backup(at url: URL) throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let base = "\(url.lastPathComponent).ai-run-backup-\(formatter.string(from: clock.now))"
        var number = 1
        while true {
            let name = number == 1 ? base : "\(base)-\(number)"
            do {
                try files.copyFile(at: url, to: url.deletingLastPathComponent().appendingPathComponent(name))
                return
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                number += 1
            }
        }
    }

    private func hasStatusSaver(_ command: String) -> Bool {
        if command.contains(".ai-run/status") { return true }
        var candidates = command.split(whereSeparator: { $0.isWhitespace || $0 == "'" || $0 == "\"" }).map(String.init)
        if command.hasPrefix("sh "), let quoted = ShellQuote.decodePrefix(command.dropFirst(3)) { candidates.append(quoted.value) }
        return candidates.contains { candidate in
            let path = candidate.hasPrefix("~/")
                ? files.homeDirectory.appendingPathComponent(String(candidate.dropFirst(2))).path : candidate
            guard path.hasPrefix("/") else { return false }
            // 검사할 수 없는 사용자 스크립트는 연결의 근거로 사용하지 않는다.
            guard let data = try? files.readPrefix(at: URL(fileURLWithPath: path), maxBytes: 65_536) else { return false }
            return String(decoding: data, as: UTF8.self).contains(".ai-run/status")
        }
    }

    private func failure(from error: Error) -> Failure {
        (error as? Failure) ?? .fileOperation(error.localizedDescription)
    }
}
