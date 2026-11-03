import Foundation

public enum ReleaseFetchFailure: Error, Equatable, Sendable {
    case rateLimited
    case unexpectedStatus(Int)
    case invalidResponse
}

// 최신 정식 릴리스를 읽는 경계. 릴리스가 아직 없으면 nil을 돌려주고, 읽지 못하면 던진다.
public protocol ReleaseFetching: Sendable {
    func fetchLatest() async throws -> LatestRelease?
}

// GitHub API의 `releases/latest`는 프리릴리스와 초안을 제외한 가장 최근 릴리스를 준다. 인증 없이 읽고 아무것도 보내지 않는다.
public struct GitHubReleaseFetcher: ReleaseFetching {
    public typealias Load = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private static let endpoint = "https://api.github.com/repos/huniversal/Desktoto/releases/latest"
    private static let timeout: TimeInterval = 10

    private let load: Load

    public init(load: @escaping Load = { try await URLSession.shared.data(for: $0) }) {
        self.load = load
    }

    public func fetchLatest() async throws -> LatestRelease? {
        guard let url = URL(string: Self.endpoint) else { throw ReleaseFetchFailure.invalidResponse }
        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Desktoto", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await load(request)
        guard let httpResponse = response as? HTTPURLResponse else { throw ReleaseFetchFailure.invalidResponse }
        return try Self.parse(statusCode: httpResponse.statusCode, data: data)
    }

    private struct Payload: Decodable {
        let tagName: String
        let isPrerelease: Bool?
        let isDraft: Bool?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case isPrerelease = "prerelease"
            case isDraft = "draft"
        }
    }

    // 상태 코드와 본문만 보고 판정하는 순수 함수. 404는 릴리스가 없다는 뜻이라 오류가 아니다.
    static func parse(statusCode: Int, data: Data) throws -> LatestRelease? {
        switch statusCode {
        case 200:
            guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
                  let release = LatestRelease(tagName: payload.tagName) else {
                throw ReleaseFetchFailure.invalidResponse
            }
            if payload.isPrerelease == true || payload.isDraft == true { return nil }
            return release
        case 404:
            return nil
        case 403, 429:
            throw ReleaseFetchFailure.rateLimited
        default:
            throw ReleaseFetchFailure.unexpectedStatus(statusCode)
        }
    }
}
