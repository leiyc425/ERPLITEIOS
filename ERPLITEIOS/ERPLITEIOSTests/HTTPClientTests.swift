import Foundation
import Testing
@testable import ERPLITEIOS

@MainActor
@Suite(.serialized)
struct HTTPClientTests {
    @Test func doesNotSendWithoutABaseURL() async {
        let flag = RequestFlag()
        StubURLProtocol.setHandler { _ in
            flag.mark()
            return StubURLProtocol.Response(status: 200, body: Data(), headers: [:])
        }
        defer { StubURLProtocol.setHandler(nil) }

        let client = URLSessionHTTPClient(
            configuration: .mockDefault,
            session: StubURLProtocol.makeSession(),
            authorizer: PendingContractAuthorizer()
        )

        await #expect(throws: APIError.backendNotConfigured) {
            try await client.send(HTTPRequest(method: .get, path: "status"))
        }
        #expect(flag.isMarked == false)
    }

    @Test func refusesToInventAnAuthenticationScheme() async {
        let flag = RequestFlag()
        StubURLProtocol.setHandler { _ in
            flag.mark()
            return StubURLProtocol.Response(status: 200, body: Data(), headers: [:])
        }
        defer { StubURLProtocol.setHandler(nil) }

        let configuration = configuredExample()
        let client = URLSessionHTTPClient(
            configuration: configuration,
            session: StubURLProtocol.makeSession(),
            authorizer: PendingContractAuthorizer()
        )

        await #expect(throws: APIError.authenticationSchemeNotConfigured) {
            try await client.send(HTTPRequest(method: .get, path: "status", requiresAuthentication: true))
        }
        #expect(flag.isMarked == false)
    }

    @Test func mapsTimeoutAndUnauthorizedResponses() async throws {
        StubURLProtocol.setHandler { _ in
            throw URLError(.timedOut)
        }
        defer { StubURLProtocol.setHandler(nil) }

        let client = URLSessionHTTPClient(
            configuration: configuredExample(),
            session: StubURLProtocol.makeSession(),
            authorizer: PendingContractAuthorizer()
        )
        await #expect(throws: APIError.timedOut) {
            try await client.send(HTTPRequest(method: .get, path: "status"))
        }

        StubURLProtocol.setHandler { _ in
            StubURLProtocol.Response(status: 401, body: Data("hidden".utf8), headers: [:])
        }
        await #expect(throws: APIError.unauthenticated) {
            try await client.send(HTTPRequest(method: .get, path: "status"))
        }
    }

    @Test func decodesJSONAndAppliesTheCallerPrefix() async throws {
        let flag = RequestFlag()
        StubURLProtocol.setHandler { request in
            if request.url?.absoluteString == "https://example.com/api/v2/probe" {
                flag.mark()
            }
            let body = #"{"name":"probe"}"#.data(using: .utf8) ?? Data()
            return StubURLProtocol.Response(status: 200, body: body, headers: ["Content-Type": "application/json"])
        }
        defer { StubURLProtocol.setHandler(nil) }

        let client = URLSessionHTTPClient(
            configuration: configuredExample(),
            session: StubURLProtocol.makeSession(),
            authorizer: HeaderSpyAuthorizer()
        )
        let probe = try await client.send(
            HTTPRequest(method: .get, path: "probe", versionPrefix: "api/v2"),
            as: ProbeBody.self
        )
        #expect(probe.name == "probe")
        #expect(flag.isMarked)
    }

    @Test func callsTheAuthorizerHookWhenRequested() async throws {
        let header = HeaderBox()
        StubURLProtocol.setHandler { request in
            header.set(request.value(forHTTPHeaderField: "X-Test-Auth"))
            return StubURLProtocol.Response(status: 204, body: Data(), headers: [:])
        }
        defer { StubURLProtocol.setHandler(nil) }

        let client = URLSessionHTTPClient(
            configuration: configuredExample(),
            session: StubURLProtocol.makeSession(),
            authorizer: HeaderSpyAuthorizer()
        )
        let response = try await client.send(
            HTTPRequest(method: .get, path: "probe", requiresAuthentication: true)
        )
        #expect(response.statusCode == 204)
        #expect(header.value == "attached")
    }

    private func configuredExample() -> AppConfiguration {
        AppConfiguration(
            baseURL: URL(string: "https://example.com"),
            apiVersionPrefix: nil,
            requestTimeout: 30,
            loadError: nil
        )
    }
}

private struct ProbeBody: Codable, Equatable {
    var name: String
}

private struct HeaderSpyAuthorizer: RequestAuthorizing {
    func authorize(_ request: inout URLRequest) async throws {
        request.setValue("attached", forHTTPHeaderField: "X-Test-Auth")
    }
}
