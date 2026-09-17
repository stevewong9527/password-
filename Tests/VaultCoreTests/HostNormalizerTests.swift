import Testing
@testable import VaultCore

@Test func hostNormalizerLowercasesAndRemovesWWW() throws {
    #expect(try HostNormalizer.normalize("HTTPS://WWW.Example.COM/login") == "example.com")
}

@Test func hostNormalizerDropsPathQueryAndFragment() throws {
    #expect(try HostNormalizer.normalize("https://accounts.example.com/path?q=secret#fragment") == "accounts.example.com")
}

@Test func hostNormalizerAcceptsBareHost() throws {
    #expect(try HostNormalizer.normalize("Example.com/login") == "example.com")
}

@Test func hostNormalizerRejectsMissingHost() {
    #expect(throws: HostNormalizerError.self) {
        try HostNormalizer.normalize("not a host value")
    }
}
