import Foundation
import MacKeyManagerLib

private func makeTempCatalog() -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    return tempDir.appendingPathComponent("expiry_test_\(UUID().uuidString).json")
}

func runExpiryTests() {
    print("\n--- Expiry Tests ---")

    test("ExpiryStatus: no expiry date returns .noExpiry") {
        let entry = CatalogEntry(
            variableKey: "global:/home/.zshrc:FOO",
            name: "FOO",
            scope: "global",
            sourceFilePath: "/home/.zshrc",
            expiryDate: nil
        )
        try assertEqual(entry.expiryStatus, .noExpiry)
    }

    test("ExpiryStatus: future date > 7 days returns .valid") {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        let entry = CatalogEntry(
            variableKey: "global:/home/.zshrc:FOO",
            name: "FOO",
            scope: "global",
            sourceFilePath: "/home/.zshrc",
            expiryDate: futureDate
        )
        try assertEqual(entry.expiryStatus, .valid)
    }

    test("ExpiryStatus: date within 7 days returns .expiringSoon") {
        let soonDate = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        let entry = CatalogEntry(
            variableKey: "global:/home/.zshrc:FOO",
            name: "FOO",
            scope: "global",
            sourceFilePath: "/home/.zshrc",
            expiryDate: soonDate
        )
        try assertEqual(entry.expiryStatus, .expiringSoon)
    }

    test("ExpiryStatus: past date returns .expired") {
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let entry = CatalogEntry(
            variableKey: "global:/home/.zshrc:FOO",
            name: "FOO",
            scope: "global",
            sourceFilePath: "/home/.zshrc",
            expiryDate: pastDate
        )
        try assertEqual(entry.expiryStatus, .expired)
    }

    test("CatalogEntry without expiryDate decodes as nil (backward compat)") {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789ABC",
            "variableKey": "global:/home/.zshrc:FOO",
            "name": "FOO",
            "scope": "global",
            "sourceFilePath": "/home/.zshrc",
            "isPinned": false,
            "lastSeenDate": 0
        }
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(CatalogEntry.self, from: json)
        try assertTrue(entry.expiryDate == nil)
        try assertEqual(entry.expiryStatus, .noExpiry)
    }

    test("setExpiryDate on CatalogService") {
        let url = makeTempCatalog()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = CatalogService(storageURL: url)
        let variables = [
            EnvironmentVariable(name: "FOO", value: "bar", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc"))
        ]
        service.sync(variables: variables)

        let entryID = service.entries[0].id
        let futureDate = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
        service.setExpiryDate(entryID: entryID, date: futureDate)

        try assertTrue(service.entries[0].expiryDate != nil)
        try assertEqual(service.entries[0].expiryStatus, .valid)

        // Clear expiry
        service.setExpiryDate(entryID: entryID, date: nil)
        try assertTrue(service.entries[0].expiryDate == nil)
        try assertEqual(service.entries[0].expiryStatus, .noExpiry)
    }

    test("expiredEntries returns only expired") {
        let url = makeTempCatalog()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = CatalogService(storageURL: url)
        let variables = [
            EnvironmentVariable(name: "EXPIRED_KEY", value: "1", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc")),
            EnvironmentVariable(name: "VALID_KEY", value: "2", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc")),
            EnvironmentVariable(name: "NO_EXPIRY_KEY", value: "3", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc"))
        ]
        service.sync(variables: variables)

        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        service.setExpiryDate(entryID: service.entries[0].id, date: pastDate)
        service.setExpiryDate(entryID: service.entries[1].id, date: futureDate)

        let expired = service.expiredEntries()
        try assertEqual(expired.count, 1)
        try assertEqual(expired[0].name, "EXPIRED_KEY")
    }

    test("expiringSoonEntries returns within range") {
        let url = makeTempCatalog()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = CatalogService(storageURL: url)
        let variables = [
            EnvironmentVariable(name: "SOON_KEY", value: "1", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc")),
            EnvironmentVariable(name: "FAR_KEY", value: "2", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc"))
        ]
        service.sync(variables: variables)

        let soonDate = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        let farDate = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        service.setExpiryDate(entryID: service.entries[0].id, date: soonDate)
        service.setExpiryDate(entryID: service.entries[1].id, date: farDate)

        let expiring = service.expiringSoonEntries(withinDays: 7)
        try assertEqual(expiring.count, 1)
        try assertEqual(expiring[0].name, "SOON_KEY")
    }
}
