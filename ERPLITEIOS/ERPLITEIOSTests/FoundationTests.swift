import Foundation
import Testing
@testable import ERPLITEIOS

@MainActor
struct DashboardViewModelTests {
    @Test func placeholdersStayMockEvenWhenABaseURLExists() {
        let session = Session(accountLabel: "Ada", expiresAt: nil, isMock: true)
        let configuration = AppConfiguration(
            baseURL: URL(string: "https://example.com"),
            apiVersionPrefix: "api/v1",
            requestTimeout: 30,
            loadError: nil
        )
        let viewModel = DashboardViewModel(session: session, configuration: configuration)

        #expect(viewModel.showsMockBanner)
        #expect(viewModel.accountLine == "Ada · mock session")
        #expect(viewModel.modules.allSatisfy { $0.origin == .mock })
        #expect(viewModel.backendDetail.contains("does not call it"))
        #expect(viewModel.configuration.contractIntegrated == false)
    }
}

@MainActor
struct JSONCodingTests {
    @Test func roundTripsISO8601Dates() throws {
        let value = StoredCredential(
            secret: "mock-session-1",
            accountLabel: "Ada",
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000),
            isMock: true
        )
        let data = try JSONCoding.encode(value)
        let decoded = try JSONCoding.makeDecoder().decode(StoredCredential.self, from: data)
        #expect(decoded.accountLabel == value.accountLabel)
        #expect(decoded.isMock)
        #expect(decoded.secret == value.secret)
        #expect(decoded.expiresAt?.timeIntervalSince1970 == 1_700_000_000)
    }
}

@MainActor
struct KeychainTokenStoreTests {
    @Test func savesLoadsAndClears() throws {
        let store = KeychainTokenStore(service: "com.flowmagik.ERPLITEIOS.tests.\(UUID().uuidString)")
        defer { try? store.clear() }

        let credential = StoredCredential(
            secret: "mock-session-keychain",
            accountLabel: "Ada",
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000),
            isMock: true
        )
        try store.save(credential)
        #expect(try store.load() == credential)

        let replacement = StoredCredential(
            secret: "mock-session-replaced",
            accountLabel: "Grace",
            expiresAt: credential.expiresAt,
            isMock: true
        )
        try store.save(replacement)
        #expect(try store.load() == replacement)

        try store.clear()
        #expect(try store.load() == nil)
    }
}
