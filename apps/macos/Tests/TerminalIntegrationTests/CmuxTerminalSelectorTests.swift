import Testing
@testable import TerminalIntegration

struct CmuxTerminalSelectorTests {
    private let surfaceID = "02C0DC0F-BA32-4C64-A63E-E94D7E120983"

    // AC-4
    @Test func readsSurfaceIDFromEnvironmentOutput() {
        let output = """
        PID TTY STAT TIME COMMAND
        1332 s004 S+ 0:01.20 /Users/me/.local/bin/claude --session-id abc HOME=/Users/me CMUX_WORKSPACE_ID=44B49DE4-E55F-4C60-AD63-A8FB704F47A8 CMUX_SURFACE_ID=\(surfaceID) TERM=xterm-ghostty
        """
        #expect(CmuxTerminalSelector.parseSurfaceID(fromEnvironmentOutput: output) == surfaceID)
    }

    // AC-5
    @Test func rejectsMissingOrMalformedSurfaceID() {
        #expect(CmuxTerminalSelector.parseSurfaceID(fromEnvironmentOutput: "") == nil)
        #expect(CmuxTerminalSelector.parseSurfaceID(fromEnvironmentOutput: "claude HOME=/Users/me") == nil)
        #expect(CmuxTerminalSelector.parseSurfaceID(fromEnvironmentOutput: "claude CMUX_SURFACE_ID=") == nil)
        #expect(CmuxTerminalSelector.parseSurfaceID(fromEnvironmentOutput: "claude CMUX_SURFACE_ID=not-a-uuid") == nil)
        // 명령 인자로 쓰이므로 UUID 뒤에 붙은 값은 UUID가 아니라서 걸러진다.
        #expect(CmuxTerminalSelector.parseSurfaceID(fromEnvironmentOutput: "claude CMUX_SURFACE_ID=\(surfaceID);rm") == nil)
        // 접두어만 비슷한 다른 변수는 읽지 않는다.
        #expect(CmuxTerminalSelector.parseSurfaceID(fromEnvironmentOutput: "claude XCMUX_SURFACE_ID=\(surfaceID)") == nil)
    }

    // AC-5
    @Test func judgesFocusOutput() {
        #expect(CmuxTerminalSelector.hasSucceeded("OK surface:1 workspace:1\n"))
        #expect(!CmuxTerminalSelector.hasSucceeded(""))
        #expect(!CmuxTerminalSelector.hasSucceeded("\n"))
        #expect(!CmuxTerminalSelector.hasSucceeded("Error: Access denied"))
    }
}
