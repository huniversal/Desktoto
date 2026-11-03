import Foundation
import Synchronization
import Testing
@testable import UpdateCheck

struct GitHubReleaseFetcherTests {
    private func body(tag: String, isPrerelease: Bool = false, isDraft: Bool = false) -> Data {
        Data(#"{"tag_name":"\#(tag)","prerelease":\#(isPrerelease),"draft":\#(isDraft),"html_url":"https://evil.example/x"}"#.utf8)
    }

    // AC-2
    @Test func parsesStableRelease() throws {
        let release = try GitHubReleaseFetcher.parse(statusCode: 200, data: body(tag: "v1.4.0"))

        #expect(release?.version == AppVersion(major: 1, minor: 4, patch: 0))
    }

    // AC-2
    @Test func ignoresResponseURLAndBuildsOwnPageURL() throws {
        let release = try #require(try GitHubReleaseFetcher.parse(statusCode: 200, data: body(tag: "v1.4.0")))

        #expect(release.pageURL.host == "github.com")
    }

    // AC-2
    @Test(arguments: [true, false])
    func skipsPrereleaseAndDraftEvenIfServerReturnsThem(isPrerelease: Bool) throws {
        let data = body(tag: "v1.4.0", isPrerelease: isPrerelease, isDraft: !isPrerelease)

        #expect(try GitHubReleaseFetcher.parse(statusCode: 200, data: data) == nil)
    }

    // AC-2, AC-4
    @Test func treatsMissingReleaseAsNone() throws {
        #expect(try GitHubReleaseFetcher.parse(statusCode: 404, data: Data()) == nil)
    }

    // AC-4
    @Test(arguments: [403, 429])
    func reportsRateLimit(statusCode: Int) {
        #expect(throws: ReleaseFetchFailure.rateLimited) {
            try GitHubReleaseFetcher.parse(statusCode: statusCode, data: Data())
        }
    }

    // AC-4
    @Test func reportsUnexpectedStatus() {
        #expect(throws: ReleaseFetchFailure.unexpectedStatus(500)) {
            try GitHubReleaseFetcher.parse(statusCode: 500, data: Data())
        }
    }

    // AC-2, AC-4
    @Test(arguments: [#"{"tag_name":"v1.2.3-rc.1"}"#, #"{"tag_name":"latest"}"#, #"{"name":"x"}"#, "not json", ""])
    func rejectsMalformedBodies(text: String) {
        #expect(throws: ReleaseFetchFailure.invalidResponse) {
            try GitHubReleaseFetcher.parse(statusCode: 200, data: Data(text.utf8))
        }
    }

    // AC-2
    @Test func sendsOnlyAnAnonymousReadRequest() async throws {
        let captured = Mutex<URLRequest?>(nil)
        let fetcher = GitHubReleaseFetcher { request in
            captured.withLock { $0 = request }
            let response = try #require(HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(#"{"tag_name":"v2.0.0"}"#.utf8), response)
        }

        let release = try await fetcher.fetchLatest()
        let request = try #require(captured.withLock { $0 })

        #expect(release?.version == AppVersion(major: 2, minor: 0, patch: 0))
        #expect(request.url?.absoluteString == "https://api.github.com/repos/huniversal/Desktoto/releases/latest")
        #expect(request.httpMethod == "GET")
        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    // AC-4
    @Test func rejectsNonHTTPResponses() async {
        let fetcher = GitHubReleaseFetcher { request in
            (Data(), URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
        }

        await #expect(throws: ReleaseFetchFailure.invalidResponse) {
            try await fetcher.fetchLatest()
        }
    }
}
