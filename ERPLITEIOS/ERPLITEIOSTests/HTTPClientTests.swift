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
            protocolClasses: [StubURLProtocol.self],
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
            protocolClasses: [StubURLProtocol.self],
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
            protocolClasses: [StubURLProtocol.self],
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

    @Test func getRetriesOnceAfterATimeoutAndPostDoesNot() async throws {
        let hits = RequestFlag()
        StubURLProtocol.setHandler { _ in
            hits.mark()
            if hits.count == 1 {
                throw URLError(.timedOut)
            }
            return StubURLProtocol.Response(status: 200, body: Data("{}".utf8), headers: [:])
        }
        defer { StubURLProtocol.setHandler(nil) }

        let client = URLSessionHTTPClient(
            configuration: configuredExample(),
            protocolClasses: [StubURLProtocol.self],
            authorizer: PendingContractAuthorizer()
        )
        let response = try await client.send(HTTPRequest(method: .get, path: "status"))
        #expect(response.statusCode == 200)
        #expect(hits.count == 2)

        let postHits = RequestFlag()
        StubURLProtocol.setHandler { _ in
            postHits.mark()
            throw URLError(.timedOut)
        }
        await #expect(throws: APIError.timedOut) {
            try await client.send(HTTPRequest(method: .post, path: "status"))
        }
        #expect(postHits.count == 1)
        #expect(APIError.classified(URLError(.appTransportSecurityRequiresSecureConnection)) == .secureConnectionFailed)
        #expect(APIError.cancelled.retriesGET == false)
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
            protocolClasses: [StubURLProtocol.self],
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
            protocolClasses: [StubURLProtocol.self],
            authorizer: HeaderSpyAuthorizer()
        )
        let response = try await client.send(
            HTTPRequest(method: .get, path: "probe", requiresAuthentication: true)
        )
        #expect(response.statusCode == 204)
        #expect(header.value == "attached")
    }

    @Test func reportsRedirectsAndDropsSensitiveHeaders() async throws {
        StubURLProtocol.setHandler { _ in
            StubURLProtocol.Response(
                status: 302,
                body: Data(),
                headers: ["Location": "https://elsewhere.example/login", "Set-Cookie": "session=hidden"]
            )
        }
        defer { StubURLProtocol.setHandler(nil) }

        let client = URLSessionHTTPClient(
            configuration: configuredExample(),
            protocolClasses: [StubURLProtocol.self],
            authorizer: PendingContractAuthorizer()
        )
        await #expect(throws: APIError.unacceptableStatus(code: 302)) {
            try await client.send(HTTPRequest(method: .get, path: "probe"))
        }

        StubURLProtocol.setHandler { _ in
            StubURLProtocol.Response(
                status: 200,
                body: Data(),
                headers: ["Set-Cookie": "session=hidden", "X-Request-Id": "abc"]
            )
        }
        let response = try await client.send(HTTPRequest(method: .get, path: "probe"))
        #expect(response.headers["X-Request-Id"] == "abc")
        #expect(response.headers.keys.contains { $0.caseInsensitiveCompare("Set-Cookie") == .orderedSame } == false)
    }

    @Test func healthCheckDoesNotSendWithoutABaseURL() async {
        let flag = RequestFlag()
        StubURLProtocol.setHandler { _ in
            flag.mark()
            return StubURLProtocol.Response(status: 200, body: Data(), headers: [:])
        }
        defer { StubURLProtocol.setHandler(nil) }

        let checker = LiveHealthCheck(
            configuration: .mockDefault,
            client: URLSessionHTTPClient(
                configuration: .mockDefault,
                protocolClasses: [StubURLProtocol.self],
                authorizer: PendingContractAuthorizer()
            )
        )
        await #expect(throws: APIError.backendNotConfigured) {
            try await checker.check()
        }
        #expect(flag.isMarked == false)
    }

    @Test func healthCheckUsesTheSiteRootPath() async throws {
        let body = #"{"status":"ok","database":"ok"}"#.data(using: .utf8) ?? Data()
        let requestedURL = URLBox()
        StubURLProtocol.setHandler { request in
            requestedURL.set(request.url?.absoluteString)
            return StubURLProtocol.Response(status: 200, body: body, headers: [:])
        }
        defer { StubURLProtocol.setHandler(nil) }

        var configuration = configuredExample()
        configuration.apiVersionPrefix = "api/v1"
        let checker = LiveHealthCheck(
            configuration: configuration,
            client: URLSessionHTTPClient(
                configuration: configuration,
                protocolClasses: [StubURLProtocol.self],
                authorizer: PendingContractAuthorizer()
            )
        )
        let report = try await checker.check()
        #expect(report.origin == .backend)
        #expect(report.status == HealthStatus(status: "ok", database: "ok"))
        #expect(requestedURL.value == "https://example.com/health/")
    }

    @Test func healthCheckCanUseASavedBaseURLWhenTheClientHasNone() async throws {
        let body = #"{"status":"ok","database":"ok"}"#.data(using: .utf8) ?? Data()
        let requestedURL = URLBox()
        StubURLProtocol.setHandler { request in
            requestedURL.set(request.url?.absoluteString)
            return StubURLProtocol.Response(status: 200, body: body, headers: [:])
        }
        defer { StubURLProtocol.setHandler(nil) }

        let store = MemoryEndpointStore()
        let settings = ConnectionSettings(bundled: .mockDefault, store: store)
        settings.draft = "https://example.com"
        settings.saveDraft()
        let checker = LiveHealthCheck(
            configuration: .mockDefault,
            client: URLSessionHTTPClient(
                configuration: .mockDefault,
                protocolClasses: [StubURLProtocol.self],
                authorizer: PendingContractAuthorizer()
            ),
            endpoint: settings
        )
        let report = try await checker.check()
        #expect(report.origin == .backend)
        #expect(requestedURL.value == "https://example.com/health/")
        #expect(settings.bundled.contractIntegrated == false)
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
