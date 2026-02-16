import Foundation
import MacKeyManagerLib

private func makeTempFile(content: String = "") throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent("test_zshrc_\(UUID().uuidString)")
    try content.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL
}

func runZshrcServiceTests() {
    print("\n--- ZshrcService Tests ---")

    test("Load exports from file") {
        let content = "# My config\nexport FOO=bar\nexport BAZ=\"hello world\"\nalias gs='git status'"
        let url = try makeTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ZshrcService(fileURL: url)
        try service.load()

        try assertEqual(service.variables.count, 2)
        try assertEqual(service.variables[0].name, "FOO")
        try assertEqual(service.variables[0].value, "bar")
        try assertEqual(service.variables[1].name, "BAZ")
        try assertEqual(service.variables[1].value, "hello world")
        try assertFalse(service.isDirty)
    }

    test("Load on non-existent file produces empty") {
        let url = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString)")
        let service = ZshrcService(fileURL: url)
        try service.load()
        try assertTrue(service.variables.isEmpty)
    }

    test("Add variable marks dirty") {
        let url = try makeTempFile(content: "export EXISTING=val")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ZshrcService(fileURL: url)
        try service.load()
        try service.add(name: "NEW_VAR", value: "new_value")

        try assertEqual(service.variables.count, 2)
        try assertTrue(service.isDirty)
        try assertEqual(service.variables.last?.name, "NEW_VAR")
    }

    test("Add duplicate throws error") {
        let url = try makeTempFile(content: "export FOO=bar")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ZshrcService(fileURL: url)
        try service.load()
        try assertThrows(try service.add(name: "FOO", value: "other"))
    }

    test("Update variable changes value") {
        let url = try makeTempFile(content: "export KEY=old")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ZshrcService(fileURL: url)
        try service.load()

        let id = service.variables[0].id
        try service.update(variableID: id, name: "KEY", value: "new")

        try assertEqual(service.variables[0].value, "new")
        try assertTrue(service.isDirty)
    }

    test("Remove variable") {
        let url = try makeTempFile(content: "export A=1\nexport B=2")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ZshrcService(fileURL: url)
        try service.load()
        try assertEqual(service.variables.count, 2)

        let id = service.variables[0].id
        try service.remove(variableID: id)

        try assertEqual(service.variables.count, 1)
        try assertEqual(service.variables[0].name, "B")
        try assertTrue(service.isDirty)
    }

    test("Save writes to file") {
        let content = "export FOO=bar"
        let url = try makeTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ZshrcService(fileURL: url)
        try service.load()
        try service.add(name: "NEW", value: "val")
        try service.save()

        try assertFalse(service.isDirty)

        let savedContent = try String(contentsOf: url, encoding: .utf8)
        try assertTrue(savedContent.contains("export NEW=val"))
        try assertTrue(savedContent.contains("export FOO=bar"))
    }

    test("CRUD cycle: add, save, reload") {
        let url = try makeTempFile(content: "# Config\nexport OLD=value")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ZshrcService(fileURL: url)
        try service.load()
        try service.add(name: "NEW_KEY", value: "new_value")
        try service.save()

        let service2 = ZshrcService(fileURL: url)
        try service2.load()

        try assertEqual(service2.variables.count, 2)
        try assertTrue(service2.variables.contains { $0.name == "OLD" })
        try assertTrue(service2.variables.contains { $0.name == "NEW_KEY" })
    }

    test("Diff generation shows changes") {
        let url = try makeTempFile(content: "export FOO=bar")
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ZshrcService(fileURL: url)
        try service.load()
        try service.add(name: "NEW", value: "val")

        let diff = try service.generateDiff()
        try assertTrue(diff.contains("+ export NEW=val"))
    }
}
