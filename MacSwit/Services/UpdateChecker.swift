import Foundation

actor UpdateChecker {
    struct ReleaseInfo: Decodable {
        let tagName: String
        let htmlUrl: String
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
        }
    }

    struct CheckResult {
        let latestVersion: String
        let releaseURL: URL
        let isNewer: Bool
    }

    private let repoURL = "https://api.github.com/repos/hkilimci/MacSwit/releases/latest"

    /// Fetches the latest release. Always returns a result on success (nil only on network/decode error).
    /// `result.isNewer` is true when the remote version is newer than the running app.
    func check() async throws -> CheckResult? {
        guard let apiURL = URL(string: repoURL) else { return nil }

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let release = try JSONDecoder().decode(ReleaseInfo.self, from: data)
        let latestTag =
            release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
        guard let releaseURL = URL(string: release.htmlUrl) else { return nil }

        guard
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                as? String
        else {
            return nil
        }

        return CheckResult(
            latestVersion: latestTag,
            releaseURL: releaseURL,
            isNewer: isNewer(latestTag, than: currentVersion)
        )
    }

    private func isNewer(_ latest: String, than current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        let maxLen = max(latestParts.count, currentParts.count)
        for i in 0..<maxLen {
            let l = i < latestParts.count ? latestParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }
}
