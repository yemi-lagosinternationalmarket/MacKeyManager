import Foundation
import MacKeyManagerLib

private func makeTempEnvFile(content: String = "") throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent("test_env_\(UUID().uuidString)")
    try content.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL
}

func runDotEnvServiceTests() {
    print("\n--- DotEnvService Tests ---")

    test("Load variables from .env file") {
        let content = "# Database config\nDB_HOST=localhost\nDB_PORT=5432"
        let url = try makeTempEnvFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let service = DotEnvService(fileURL: url, projectName: "TestProject")
        try service.load()

        try assertEqual(service.variables.count, 2)
        try assertEqual(service.variables[0].name, "DB_HOST")
        try assertEqual(service.variables[0].scope, .project)
        try assertFalse(service.isDirty)
    }

    test("Add variable") {
        let url = try makeTempEnvFile(content: "KEY=val")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = DotEnvService(fileURL: url)
        try service.load()
        try service.add(name: "NEW", value: "new_val")

        try assertEqual(service.variables.count, 2)
        try assertTrue(service.isDirty)
    }

    test("Update variable") {
        let url = try makeTempEnvFile(content: "KEY=old")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = DotEnvService(fileURL: url)
        try service.load()

        let id = service.variables[0].id
        try service.update(variableID: id, name: "KEY", value: "new")

        try assertEqual(service.variables[0].value, "new")
    }

    test("Remove variable") {
        let url = try makeTempEnvFile(content: "A=1\nB=2")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = DotEnvService(fileURL: url)
        try service.load()
        let id = service.variables[0].id
        try service.remove(variableID: id)

        try assertEqual(service.variables.count, 1)
        try assertEqual(service.variables[0].name, "B")
    }

    test("Save writes to file") {
        let url = try makeTempEnvFile(content: "FOO=bar")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = DotEnvService(fileURL: url)
        try service.load()
        try service.add(name: "NEW", value: "val")
        try service.save()

        try assertFalse(service.isDirty)

        let content = try String(contentsOf: url, encoding: .utf8)
        try assertTrue(content.contains("NEW=val"))
    }

    test("CRUD cycle: add, save, reload") {
        let url = try makeTempEnvFile(content: "# Config\nOLD=value")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = DotEnvService(fileURL: url)
        try service.load()
        try service.add(name: "NEW_KEY", value: "new_value")
        try service.save()

        let service2 = DotEnvService(fileURL: url)
        try service2.load()

        try assertEqual(service2.variables.count, 2)
        try assertTrue(service2.variables.contains { $0.name == "OLD" })
        try assertTrue(service2.variables.contains { $0.name == "NEW_KEY" })
    }

    test("Add duplicate throws error") {
        let url = try makeTempEnvFile(content: "FOO=bar")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = DotEnvService(fileURL: url)
        try service.load()
        try assertThrows(try service.add(name: "FOO", value: "other"))
    }
}
