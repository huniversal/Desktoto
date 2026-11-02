import Boundaries
import Foundation

struct WindowResolution: Sendable, Equatable {
    let tokens: Int
    let isEstimated: Bool
}

private struct ClaudeSettings {
    var isOneMillionDisabled = false
    var modelSetting: String?
}

/// Claude 기록에는 컨텍스트 창 크기가 없어서 여러 출처에서 순서대로 찾는다.
struct ContextWindowResolver: Sendable {
    let fileSystem: any FileSystem
    let environment: [String: String]

    func resolve(sessionID: String, modelName: String?, usedTokens: Int?, workingDirectory: String?) -> WindowResolution {
        // 1. Claude Code가 상태 표시줄 스크립트로 직접 알려준 값 (가장 정확)
        if let tokens = statusLineWindow(sessionID: sessionID, modelName: modelName) {
            return WindowResolution(tokens: tokens, isEstimated: false)
        }
        // 2. 사용자가 ~/.ai-run/config.json에 직접 지정한 값
        if let tokens = configWindow(modelName: modelName) {
            return WindowResolution(tokens: tokens, isEstimated: false)
        }
        // 3. 공식 문서 규칙 + Claude 설정 파일
        let inferred = inferWindow(modelName: modelName, settings: claudeSettings(workingDirectory: workingDirectory))
        // 4. 사용량이 이미 추정한 창을 넘었다면 더 큰 창이 확실하다.
        if let usedTokens, usedTokens > inferred.tokens {
            return WindowResolution(tokens: SessionMonitoringPolicy.claudeExtendedWindow, isEstimated: false)
        }
        return inferred
    }

    private func inferWindow(modelName: String?, settings: ClaudeSettings) -> WindowResolution {
        // CLAUDE_CODE_DISABLE_1M_CONTEXT가 켜져 있으면 1M 기본 모델도 200K로 취급된다.
        if settings.isOneMillionDisabled {
            return WindowResolution(tokens: SessionMonitoringPolicy.claudeDefaultWindow, isEstimated: false)
        }
        guard let modelName else {
            return WindowResolution(tokens: SessionMonitoringPolicy.claudeDefaultWindow, isEstimated: true)
        }
        if hasOneMillionByDefault(modelName: modelName) {
            return WindowResolution(tokens: SessionMonitoringPolicy.claudeExtendedWindow, isEstimated: false)
        }
        // Opus 4.6, Sonnet 4.6 등은 model 설정의 [1m] 변형을 골랐을 때만 1M이다.
        if hasExtendedVariantSetting(modelSetting: settings.modelSetting, modelName: modelName) {
            return WindowResolution(tokens: SessionMonitoringPolicy.claudeExtendedWindow, isEstimated: false)
        }
        return WindowResolution(tokens: SessionMonitoringPolicy.claudeDefaultWindow, isEstimated: true)
    }

    /// 공식 문서: Fable 전체, Sonnet 5 이상, Haiku 5.5 이상, Opus 4.7 이상은 1M이 기본이다.
    private func hasOneMillionByDefault(modelName: String) -> Bool {
        let pattern = "claude-(opus|sonnet|haiku|fable)-(\\d+)(?:-(\\d{1,2}))?(?!\\d)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: modelName, range: NSRange(modelName.startIndex..., in: modelName)),
              let familyRange = Range(match.range(at: 1), in: modelName),
              let majorRange = Range(match.range(at: 2), in: modelName),
              let major = Int(modelName[majorRange]) else { return false }

        var minor = 0
        if match.range(at: 3).location != NSNotFound, let minorRange = Range(match.range(at: 3), in: modelName) {
            minor = Int(modelName[minorRange]) ?? 0
        }
        switch modelName[familyRange] {
        case "fable": return true
        case "sonnet": return major >= 5
        case "haiku": return major > 5 || (major == 5 && minor >= 5)
        case "opus": return major > 4 || (major == 4 && minor >= 7)
        default: return false
        }
    }

    private func hasExtendedVariantSetting(modelSetting: String?, modelName: String) -> Bool {
        guard let modelSetting = modelSetting?.lowercased(), modelSetting.contains("[1m]"),
              let baseName = modelSetting.components(separatedBy: "[").first, !baseName.isEmpty else { return false }
        let lowercasedModelName = modelName.lowercased()
        if baseName == "opusplan" {
            return lowercasedModelName.contains("opus") || lowercasedModelName.contains("sonnet")
        }
        return lowercasedModelName.contains(baseName) || baseName.contains(lowercasedModelName)
    }

    private func readJSON(at url: URL) -> JSONValue? {
        fileSystem.readAll(of: url).flatMap { JSONValue.parseObject(from: $0) }
    }

    /// statusline 스크립트가 저장한 파일에서 창 크기를 읽는다. 저장된 모델이 다르면 무시한다.
    private func statusLineWindow(sessionID: String, modelName: String?) -> Int? {
        let url = fileSystem.homeDirectory.appendingPathComponent(".ai-run/status/\(sessionID).json")
        guard let json = readJSON(at: url),
              let windowSize = json["context_window"]?["context_window_size"]?.intValue,
              windowSize > 0 else { return nil }
        if let savedModelID = json["model"]?["id"]?.stringValue, let modelName,
           !savedModelID.contains(modelName), !modelName.contains(savedModelID) {
            return nil
        }
        return windowSize
    }

    /// ~/.ai-run/config.json 예: {"windows": {"claude-opus-4-6": 1000000}}. 가장 긴 접두어가 일치하는 항목을 쓴다.
    private func configWindow(modelName: String?) -> Int? {
        guard let modelName,
              let json = readJSON(at: fileSystem.homeDirectory.appendingPathComponent(".ai-run/config.json")),
              let windows = json["windows"]?.objectValue else { return nil }
        let bestKey = windows.keys.filter { modelName.hasPrefix($0) }.max { $0.count < $1.count }
        return bestKey.flatMap { windows[$0]?.intValue }
    }

    /// 사용자 설정, 프로젝트 설정, 로컬 설정 순으로 읽고 뒤에 읽은 값이 앞의 값을 덮어쓴다.
    private func claudeSettings(workingDirectory: String?) -> ClaudeSettings {
        var urls = [fileSystem.homeDirectory.appendingPathComponent(".claude/settings.json")]
        if let workingDirectory {
            let projectDirectory = URL(fileURLWithPath: workingDirectory).appendingPathComponent(".claude")
            urls += [
                projectDirectory.appendingPathComponent("settings.json"),
                projectDirectory.appendingPathComponent("settings.local.json")
            ]
        }
        var settings = ClaudeSettings()
        for url in urls {
            guard let json = readJSON(at: url) else { continue }
            if let modelSetting = json["model"]?.stringValue { settings.modelSetting = modelSetting }
            if let value = json["env"]?["CLAUDE_CODE_DISABLE_1M_CONTEXT"], hasTruthyValue(value) {
                settings.isOneMillionDisabled = true
            }
        }
        if let value = environment["CLAUDE_CODE_DISABLE_1M_CONTEXT"], hasTruthyText(value) {
            settings.isOneMillionDisabled = true
        }
        return settings
    }

    private func hasTruthyValue(_ value: JSONValue) -> Bool {
        switch value {
        case .bool(let isOn): isOn
        case .number(let number): number == 1
        case .string(let text): hasTruthyText(text)
        default: false
        }
    }

    private func hasTruthyText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased == "1" || lowercased == "true"
    }
}
