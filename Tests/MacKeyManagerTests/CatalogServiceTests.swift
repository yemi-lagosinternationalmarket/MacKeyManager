import Foundation
import MacKeyManagerLib

private func makeTempCatalog() -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    return tempDir.appendingPathComponent("catalog_test_\(UUID().uuidString).json")
}

func runCatalogServiceTests() {
    print("\n--- CatalogService Tests ---")

    test("Starts empty") {
        let url = makeTempCatalog()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = CatalogService(storageURL: url)
        try assertTrue(service.entries.isEmpty)
    }

    test("Sync adds new entries") {
        let url = makeTempCatalog()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = CatalogService(storageURL: url)
        let variables = [
            EnvironmentVariable(name: "FOO", value: "bar", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc")),
            EnvironmentVariable(name: "BAZ", value: "qux", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc"))
        ]
        service.sync(variables: variables)
        try assertEqual(service.entries.count, 2)
    }

    test("Sync updates existing (no duplicates)") {
        let url = makeTempCatalog()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = CatalogService(storageURL: url)
        let variables = [
            EnvironmentVariable(name: "FOO", value: "bar", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc"))
        ]
        service.sync(variables: variables)
        let firstSeen = service.entries[0].lastSeenDate

        Thread.sleep(forTimeInterval: 0.01)
        service.sync(variables: variables)

        try assertEqual(service.entries.count, 1)
        try assertTrue(service.entries[0].lastSeenDate >= firstSeen)
    }

    test("Search by name") {
        let url = makeTempCatalog()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = CatalogService(storageURL: url)
        let variables = [
            EnvironmentVariable(name: "API_KEY", value: "123", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc")),
            EnvironmentVariable(name: "DB_HOST", value: "localhost", scope: .project,
                              sourceFile: URL(fileURLWithPath: "/project/.env"))
        ]
        service.sync(variables: variables)

        let results = service.search(query: "API")
        try assertEqual(results.count, 1)
        try assertEqual(results[0].name, "API_KEY")
    }

    test("Search with empty query returns all") {
        let url = makeTempCatalog()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = CatalogService(storageURL: url)
        let variables = [
            EnvironmentVariable(name: "A", value: "1", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc")),
            EnvironmentVariable(name: "B", value: "2", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc"))
        ]
        service.sync(variables: variables)

        let results = service.search(query: "")
        try assertEqual(results.count, 2)
    }

    test("Pin and unpin entries") {
        let url = makeTempCatalog()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = CatalogService(storageURL: url)
        let variables = [
            EnvironmentVariable(name: "FOO", value: "bar", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc"))
        ]
        service.sync(variables: variables)
        try assertTrue(service.pinnedEntries().isEmpty)

        let entryID = service.entries[0].id
        service.togglePin(entryID: entryID)
        try assertEqual(service.pinnedEntries().count, 1)

        service.togglePin(entryID: entryID)
        try assertTrue(service.pinnedEntries().isEmpty)
    }

    test("Prune removes stale unpinned entries") {
        let url = makeTempCatalog()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = CatalogService(storageURL: url)
        let variables = [
            EnvironmentVariable(name: "OLD", value: "1", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc")),
            EnvironmentVariable(name: "PINNED", value: "2", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc"))
        ]
        service.sync(variables: variables)

        let pinnedID = service.entries[1].id
        service.togglePin(entryID: pinnedID)

        service.pruneStale(olderThanDays: 0)

        try assertEqual(service.entries.count, 1)
        try assertEqual(service.entries[0].name, "PINNED")
    }

    test("Persistence survives reload") {
        let url = makeTempCatalog()
        defer { try? FileManager.default.removeItem(at: url) }

        let service1 = CatalogService(storageURL: url)
        let variables = [
            EnvironmentVariable(name: "FOO", value: "bar", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc"))
        ]
        service1.sync(variables: variables)
        service1.togglePin(entryID: service1.entries[0].id)

        let service2 = CatalogService(storageURL: url)
        try assertEqual(service2.entries.count, 1)
        try assertEqual(service2.entries[0].name, "FOO")
        try assertTrue(service2.entries[0].isPinned)
    }

    test("Recent entries limited") {
        let url = makeTempCatalog()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = CatalogService(storageURL: url)
        let variables = [
            EnvironmentVariable(name: "A", value: "1", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc")),
            EnvironmentVariable(name: "B", value: "2", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc")),
            EnvironmentVariable(name: "C", value: "3", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/home/.zshrc"))
        ]
        service.sync(variables: variables)

        let recent = service.recentEntries(limit: 2)
        try assertEqual(recent.count, 2)
    }
}
