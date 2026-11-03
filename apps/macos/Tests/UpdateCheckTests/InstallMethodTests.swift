import Foundation
import TestSupport
import Testing
@testable import UpdateCheck

struct InstallMethodTests {
    // AC-5
    @Test(arguments: ["/opt/homebrew/Caskroom/desktoto", "/usr/local/Caskroom/desktoto"])
    func detectsHomebrewFromCaskroom(path: String) {
        let fileSystem = InMemoryFileSystem()
        fileSystem.addDirectory(at: URL(fileURLWithPath: path))

        #expect(InstallMethod.detect(fileSystem: fileSystem) == .homebrew)
    }

    // AC-5
    @Test func fallsBackToManualWhenNoCaskroomFolderExists() {
        #expect(InstallMethod.detect(fileSystem: InMemoryFileSystem()) == .manual)
    }

    // AC-5
    @Test func ignoresOtherCasks() {
        let fileSystem = InMemoryFileSystem()
        fileSystem.addDirectory(at: URL(fileURLWithPath: "/opt/homebrew/Caskroom/other"))

        #expect(InstallMethod.detect(fileSystem: fileSystem) == .manual)
    }
}
