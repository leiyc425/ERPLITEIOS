import Foundation
import Testing
@testable import ERPLITEIOS

@MainActor
struct RequestURLBuilderTests {
    private let base = URL(string: "https://example.com/erp")!

    @Test func joinsPrefixAndPath() throws {
        let url = try RequestURLBuilder.url(
            baseURL: base,
            path: "/status/",
            versionPrefix: "api/v1",
            query: [URLQueryItem(name: "q", value: "a b")]
        )
        #expect(url.absoluteString == "https://example.com/erp/api/v1/status?q=a%20b")
    }

    @Test func omitsPrefixWhenUnset() throws {
        let url = try RequestURLBuilder.url(
            baseURL: base,
            path: "status",
            versionPrefix: nil,
            query: []
        )
        #expect(url.absoluteString == "https://example.com/erp/status")
    }

    @Test func rejectsParentSegments() {
        #expect(throws: APIError.invalidRequestURL) {
            try RequestURLBuilder.url(
                baseURL: base,
                path: "reports/../admin",
                versionPrefix: nil,
                query: []
            )
        }
    }
}
