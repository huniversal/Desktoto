import Foundation

// cmux 터미널 안에서 도는 프로세스의 환경에서 패널 식별자를 읽고, cmux CLI의 응답을 판정하는 순수 함수.
// cmux는 자기 터미널 안의 프로세스에 CMUX_SURFACE_ID(패널 UUID)를 넣어 주고, `cmux focus-panel --panel <UUID>`로 그 패널을 앞으로 가져올 수 있다.
enum CmuxTerminalSelector {
    private static let surfaceIDPrefix = "CMUX_SURFACE_ID="

    // `ps eww -p <pid>` 출력은 명령줄 뒤에 `KEY=VALUE`가 공백으로 이어진다. 외부 출력은 미검증 입력이므로
    // UUID 형식인 값만 돌려주고, 없거나 형식이 틀리면 nil이다(명령 인자로 쓰기 전에 걸러낸다).
    // 환경 변수는 출력 맨 끝에 오므로, 명령 인자에 같은 모양의 토큰이 섞여 있어도 마지막 값을 쓴다.
    static func parseSurfaceID(fromEnvironmentOutput output: String) -> String? {
        output
            .split(whereSeparator: { $0.isWhitespace })
            .filter { $0.hasPrefix(surfaceIDPrefix) }
            .map { String($0.dropFirst(surfaceIDPrefix.count)) }
            .last { UUID(uuidString: $0) != nil }
    }

    // 성공하면 표준 출력이 `OK ...`로 시작한다. 실패(소켓 거부 등)는 오류 출력으로 나와서 표준 출력이 비므로,
    // OK로 시작하지 않으면 모두 실패로 본다.
    static func hasSucceeded(_ output: String) -> Bool {
        output.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("OK")
    }
}
