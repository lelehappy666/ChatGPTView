import XCTest
@testable import CodexMonitor

final class GitHubGraphQLClientTests: XCTestCase {
    func testDecodeMapsViewerContributionsAndRecentRepositories() throws {
        let data = Data(#"""
        {
          "data": {
            "viewer": {
              "login": "lele",
              "contributionsCollection": {
                "contributionCalendar": {
                  "totalContributions": 1284,
                  "weeks": [
                    {"contributionDays": [
                      {"date": "2026-07-14", "contributionCount": 3},
                      {"date": "2026-07-15", "contributionCount": 9}
                    ]}
                  ]
                }
              },
              "repositories": {
                "nodes": [
                  {"name": "older", "url": "https://github.com/lele/older", "pushedAt": "2026-07-14T10:00:00Z"},
                  {"name": "latest", "url": "https://github.com/lele/latest", "pushedAt": "2026-07-15T10:00:00Z"}
                ]
              }
            }
          }
        }
        """#.utf8)

        let snapshot = try GitHubGraphQLClient.decode(
            data: data,
            statusCode: 200,
            fetchedAt: Date(timeIntervalSince1970: 123)
        )

        XCTAssertEqual(snapshot.username, "lele")
        XCTAssertEqual(snapshot.totalContributions, 1284)
        XCTAssertEqual(snapshot.contributionDays.map(\.contributionCount), [3, 9])
        XCTAssertEqual(snapshot.repositories.map(\.name), ["latest", "older"])
        XCTAssertEqual(snapshot.fetchedAt, Date(timeIntervalSince1970: 123))
    }

    func testDecodeMapsUnauthorizedResponseToInvalidToken() {
        XCTAssertThrowsError(
            try GitHubGraphQLClient.decode(
                data: Data(),
                statusCode: 401,
                fetchedAt: .now
            )
        ) { error in
            XCTAssertEqual(error as? GitHubAPIError, .invalidToken)
        }
    }

    func testDecodeUsesGraphQLErrorMessage() {
        let data = Data(#"{"errors":[{"message":"API rate limit exceeded"}]}"#.utf8)

        XCTAssertThrowsError(
            try GitHubGraphQLClient.decode(
                data: data,
                statusCode: 200,
                fetchedAt: .now
            )
        ) { error in
            XCTAssertEqual(error as? GitHubAPIError, .rateLimited)
        }
    }

    func testRequestNeverPlacesTokenInURLOrBody() throws {
        let request = try GitHubGraphQLClient.makeRequest(token: "secret-token")

        XCTAssertEqual(request.url?.absoluteString, "https://api.github.com/graphql")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
        XCTAssertFalse(String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self).contains("secret-token"))
    }
}
