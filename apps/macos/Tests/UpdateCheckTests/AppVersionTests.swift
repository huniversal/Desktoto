import Testing
@testable import UpdateCheck

struct AppVersionTests {
    // AC-1
    @Test(arguments: [
        ("1.2.3", 1, 2, 3), ("v1.2.3", 1, 2, 3), ("0.0.0", 0, 0, 0), ("10.20.30", 10, 20, 30)
    ])
    func parsesVersionWithOrWithoutPrefix(text: String, major: Int, minor: Int, patch: Int) {
        #expect(AppVersion(text) == AppVersion(major: major, minor: minor, patch: patch))
    }

    // AC-1
    @Test(arguments: ["", "v", "1", "1.2", "1.2.3.4", "1.2.x", "1..3", "a.b.c", "1.2.3-rc.1", "V1.2.3", "1.2.-3", "1.2.3 ", "+1.2.3", "99999999999999999999.0.0"])
    func rejectsMalformedVersion(text: String) {
        #expect(AppVersion(text) == nil)
    }

    // AC-1
    @Test func comparesNumbersInsteadOfText() throws {
        let nine = try #require(AppVersion("1.9.0"))
        let ten = try #require(AppVersion("1.10.0"))

        #expect(nine < ten)
        #expect(!(ten < nine))
    }

    // AC-1
    @Test func ordersByMajorThenMinorThenPatch() throws {
        let versions = try ["0.1.0", "0.0.9", "2.0.0", "1.99.99", "1.0.0"].map { try #require(AppVersion($0)) }

        #expect(versions.sorted().map(\.description) == ["0.0.9", "0.1.0", "1.0.0", "1.99.99", "2.0.0"])
    }

    // AC-1
    @Test func equalVersionsAreNotNewer() throws {
        let current = try #require(AppVersion("1.2.3"))
        let same = try #require(AppVersion("v1.2.3"))

        #expect(current == same)
        #expect(!(same > current))
    }

    // AC-1
    @Test func descriptionHasNoPrefix() throws {
        #expect(try #require(AppVersion("v1.2.3")).description == "1.2.3")
    }
}
