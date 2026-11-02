import Foundation

// ps와 lsof 출력을 해석하는 순수 함수 모음. 외부 출력은 미검증 입력이므로 형식이 틀리면 건너뛰거나 nil을 돌려준다.
enum ProcessListParser {
    // 터미널이 없는 프로세스(데스크탑 앱이 띄운 것)의 tty 표기
    static let noTTY = "??"

    struct ProcessRow: Equatable {
        let pid: Int
        let tty: String
        let elapsedSeconds: TimeInterval
        let commandName: String
    }

    // `ps -axo pid=,tty=,etime=,comm=` 출력. tty가 없는 줄과 형식이 틀린 줄은 제외한다.
    static func parseProcessRows(_ output: String) -> [ProcessRow] {
        output.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard fields.count == 4,
                  let pid = Int(fields[0]),
                  String(fields[1]) != noTTY,
                  let elapsedSeconds = convertElapsedTimeToSeconds(String(fields[2])) else { return nil }
            return ProcessRow(
                pid: pid,
                tty: String(fields[1]),
                elapsedSeconds: elapsedSeconds,
                commandName: URL(fileURLWithPath: String(fields[3])).lastPathComponent
            )
        }
    }

    // ps의 etime 형식: [[일-]시:]분:초
    static func convertElapsedTimeToSeconds(_ text: String) -> TimeInterval? {
        let dayAndRest = text.split(separator: "-", maxSplits: 1).map(String.init)
        let days = dayAndRest.count == 2 ? Double(dayAndRest[0]) ?? 0 : 0
        let clock = (dayAndRest.last ?? "").split(separator: ":").compactMap { Double($0) }
        guard !clock.isEmpty, clock.count <= 3 else { return nil }
        let seconds = clock.reduce(0) { $0 * 60 + $1 }
        return days * 86_400 + seconds
    }

    // `lsof -a -p <pid> -d cwd -Fn` 출력에서 작업 폴더(`n`으로 시작하는 첫 줄)를 꺼낸다.
    static func parseWorkingDirectory(_ output: String) -> String? {
        output.split(separator: "\n").first { $0.hasPrefix("n") }.map { String($0.dropFirst()) }
    }

    struct ProcessTree: Equatable {
        var parentOf: [Int: Int] = [:]
        var pathOf: [Int: String] = [:]
    }

    // `ps -axo pid=,ppid=,comm=` 출력. 실행 파일 경로에 공백이 있을 수 있어 세 번째 필드는 나머지 전체로 둔다.
    static func parseProcessTree(_ output: String) -> ProcessTree {
        var tree = ProcessTree()
        output.split(separator: "\n").forEach { line in
            let fields = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard fields.count == 3, let processID = Int(fields[0]), let parentID = Int(fields[1]) else { return }
            tree.parentOf[processID] = parentID
            tree.pathOf[processID] = String(fields[2])
        }
        return tree
    }

    // pid에서 부모를 따라 올라가며 실행 파일 경로에 appName이 들어 있는 첫 조상을 찾아 그 앱 경로를 돌려준다.
    static func findAncestorAppPath(of pid: Int, appName: String, in tree: ProcessTree) -> String? {
        var current = pid
        var visited: Set<Int> = []
        while visited.insert(current).inserted {
            if let path = tree.pathOf[current], let range = path.range(of: "/\(appName)/") {
                return "\(path[..<range.lowerBound])/\(appName)"
            }
            guard let parent = tree.parentOf[current], parent > 1 else { return nil }
            current = parent
        }
        return nil
    }
}
