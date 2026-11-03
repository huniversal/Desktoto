import Foundation
import Testing
@testable import UpdateCheck

struct LatestReleaseTests {
    // AC-2
    @Test func buildsPageURLFromValidatedTag() throws {
        let release = try #require(LatestRelease(tagName: "v1.2.3"))

        #expect(release.version == AppVersion(major: 1, minor: 2, patch: 3))
        #expect(release.pageURL.absoluteString == "https://github.com/huniversal/Desktoto/releases/tag/v1.2.3")
    }

    // AC-2
    @Test(arguments: ["", "1.2.3", "v1.2", "v1.2.3-rc.1", "v1.2.3/../../evil", "vx.y.z", "v1.2.3?x=1", "latest"])
    func rejectsTagsThatAreNotStableVersions(tag: String) {
        #expect(LatestRelease(tagName: tag) == nil)
    }
}
