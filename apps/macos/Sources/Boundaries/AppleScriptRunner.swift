import Foundation

public protocol AppleScriptRunner: Sendable {
    // 스크립트가 true를 돌려주면 true. 컴파일이나 실행 오류(자동화 권한 거부 포함)는 throw한다.
    func runReturningBoolean(source: String) throws -> Bool
}

public struct AppleScriptError: Error, Sendable {
    public let message: String
}

public struct SystemAppleScriptRunner: AppleScriptRunner {
    public init() {}

    public func runReturningBoolean(source: String) throws -> Bool {
        guard let script = NSAppleScript(source: source) else {
            throw AppleScriptError(message: "스크립트를 만들 수 없다")
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            throw AppleScriptError(message: errorInfo[NSAppleScript.errorMessage] as? String ?? "알 수 없는 오류")
        }
        return result.booleanValue
    }
}
