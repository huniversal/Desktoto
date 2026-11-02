// iTerm2와 Terminal.app에서 tty가 같은 탭을 찾아 앞으로 가져오는 AppleScript. 찾아서 이동하면 true를 돌려준다.
enum TerminalScripts {
    static func makeITermScript(tty: String) -> String {
        let escapedTTY = escape(tty)
        return """
        tell application "iTerm2"
            repeat with theWindow in windows
                repeat with theTab in tabs of theWindow
                    repeat with theSession in sessions of theTab
                        if tty of theSession is "\(escapedTTY)" then
                            activate
                            select theWindow
                            tell theTab to select
                            tell theSession to select
                            return true
                        end if
                    end repeat
                end repeat
            end repeat
            return false
        end tell
        """
    }

    static func makeTerminalScript(tty: String) -> String {
        let escapedTTY = escape(tty)
        return """
        tell application "Terminal"
            repeat with theWindow in windows
                repeat with theTab in tabs of theWindow
                    if tty of theTab is "\(escapedTTY)" then
                        activate
                        set selected of theTab to true
                        set index of theWindow to 1
                        return true
                    end if
                end repeat
            end repeat
            return false
        end tell
        """
    }

    // AppleScript 문자열 리터럴 안에서 역슬래시와 따옴표가 스크립트 구조를 바꾸지 못하게 한다.
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
