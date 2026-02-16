import Foundation
import MacKeyManagerLib

private func makeTempVault() -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    return tempDir.appendingPathComponent("vault_test_\(UUID().uuidString).json")
}

private func makeTempEnvFile() -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    return tempDir.appendingPathComponent("vault_env_test_\(UUID().uuidString).env")
}

func runKeyVaultServiceTests() {
    print("\n--- KeyVaultService Tests ---")

    test("Starts empty") {
        let url = makeTempVault()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = KeyVaultService(storageURL: url)
        service.load()
        try assertTrue(service.storedKeys.isEmpty)
    }

    test("Add key") {
        let url = makeTempVault()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = KeyVaultService(storageURL: url)
        service.load()
        service.addKey(name: "Stripe Key", key: "STRIPE_API_KEY", value: "sk_test_123", tags: ["api", "payments"])

        try assertEqual(service.storedKeys.count, 1)
        try assertEqual(service.storedKeys[0].name, "Stripe Key")
        try assertEqual(service.storedKeys[0].key, "STRIPE_API_KEY")
        try assertEqual(service.storedKeys[0].value, "sk_test_123")
        try assertEqual(service.storedKeys[0].tags, ["api", "payments"])
    }

    test("Update key") {
        let url = makeTempVault()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = KeyVaultService(storageURL: url)
        service.load()
        service.addKey(name: "Old Name", key: "MY_KEY", value: "old_value")

        let id = service.storedKeys[0].id
        service.updateKey(id: id, name: "New Name", value: "new_value")

        try assertEqual(service.storedKeys[0].name, "New Name")
        try assertEqual(service.storedKeys[0].value, "new_value")
        try assertEqual(service.storedKeys[0].key, "MY_KEY") // unchanged
    }

    test("Remove key") {
        let url = makeTempVault()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = KeyVaultService(storageURL: url)
        service.load()
        service.addKey(name: "Key1", key: "K1", value: "v1")
        service.addKey(name: "Key2", key: "K2", value: "v2")

        let id = service.storedKeys[0].id
        service.removeKey(id: id)

        try assertEqual(service.storedKeys.count, 1)
        try assertEqual(service.storedKeys[0].name, "Key2")
    }

    test("Search by name") {
        let url = makeTempVault()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = KeyVaultService(storageURL: url)
        service.load()
        service.addKey(name: "Stripe Key", key: "STRIPE_KEY", value: "sk_123", tags: ["api"])
        service.addKey(name: "Database URL", key: "DATABASE_URL", value: "postgres://", tags: ["db"])
        service.addKey(name: "AWS Secret", key: "AWS_SECRET", value: "aws123", tags: ["api"])

        let results = service.search(query: "stripe")
        try assertEqual(results.count, 1)
        try assertEqual(results[0].name, "Stripe Key")
    }

    test("Search by key") {
        let url = makeTempVault()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = KeyVaultService(storageURL: url)
        service.load()
        service.addKey(name: "DB", key: "DATABASE_URL", value: "postgres://")
        service.addKey(name: "Redis", key: "REDIS_URL", value: "redis://")

        let results = service.search(query: "DATABASE")
        try assertEqual(results.count, 1)
        try assertEqual(results[0].key, "DATABASE_URL")
    }

    test("Search by tag") {
        let url = makeTempVault()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = KeyVaultService(storageURL: url)
        service.load()
        service.addKey(name: "Key1", key: "K1", value: "v1", tags: ["production"])
        service.addKey(name: "Key2", key: "K2", value: "v2", tags: ["staging"])

        let results = service.search(query: "production")
        try assertEqual(results.count, 1)
        try assertEqual(results[0].name, "Key1")
    }

    test("Import key into DotEnvService") {
        let vaultURL = makeTempVault()
        let envURL = makeTempEnvFile()
        defer {
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: envURL)
        }

        // Create an empty .env file
        try! "".write(to: envURL, atomically: true, encoding: .utf8)

        let vault = KeyVaultService(storageURL: vaultURL)
        vault.load()
        vault.addKey(name: "Test Key", key: "TEST_KEY", value: "test_value_123")

        let envService = DotEnvService(fileURL: envURL, projectName: "TestProject")
        try envService.load()

        vault.importKey(storedKeyID: vault.storedKeys[0].id, into: envService)

        try assertEqual(envService.variables.count, 1)
        try assertEqual(envService.variables[0].name, "TEST_KEY")
        try assertEqual(envService.variables[0].value, "test_value_123")
        try assertTrue(vault.storedKeys[0].lastUsedDate != nil)
    }

    test("Store from variable") {
        let url = makeTempVault()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = KeyVaultService(storageURL: url)
        service.load()

        let variable = EnvironmentVariable(
            name: "API_KEY",
            value: "my_secret_value",
            scope: .global,
            sourceFile: URL(fileURLWithPath: "/home/.zshrc")
        )
        service.storeFromVariable(variable, name: "My API Key", tags: ["api"])

        try assertEqual(service.storedKeys.count, 1)
        try assertEqual(service.storedKeys[0].name, "My API Key")
        try assertEqual(service.storedKeys[0].key, "API_KEY")
        try assertEqual(service.storedKeys[0].value, "my_secret_value")
        try assertEqual(service.storedKeys[0].tags, ["api"])
    }

    test("Vault persistence survives reload") {
        let url = makeTempVault()
        defer { try? FileManager.default.removeItem(at: url) }

        let service1 = KeyVaultService(storageURL: url)
        service1.load()
        service1.addKey(name: "Persistent Key", key: "PERSIST_KEY", value: "persist_val", tags: ["test"])

        let service2 = KeyVaultService(storageURL: url)
        service2.load()
        try assertEqual(service2.storedKeys.count, 1)
        try assertEqual(service2.storedKeys[0].name, "Persistent Key")
        try assertEqual(service2.storedKeys[0].key, "PERSIST_KEY")
        try assertEqual(service2.storedKeys[0].value, "persist_val")
        try assertEqual(service2.storedKeys[0].tags, ["test"])
    }

    test("allKeys returns sorted by name") {
        let url = makeTempVault()
        defer { try? FileManager.default.removeItem(at: url) }

        let service = KeyVaultService(storageURL: url)
        service.load()
        service.addKey(name: "Zebra", key: "Z", value: "z")
        service.addKey(name: "Alpha", key: "A", value: "a")
        service.addKey(name: "Middle", key: "M", value: "m")

        let keys = service.allKeys()
        try assertEqual(keys[0].name, "Alpha")
        try assertEqual(keys[1].name, "Middle")
        try assertEqual(keys[2].name, "Zebra")
    }
}
