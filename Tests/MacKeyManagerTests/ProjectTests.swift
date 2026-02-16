import Foundation
import MacKeyManagerLib

func runProjectTests() {
    print("\n--- Project Tests ---")

    test("detectEnvFiles finds .env files and sorts correctly") {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Create test env files
        let files = [".env", ".env.local", ".env.production", ".env.development"]
        for file in files {
            FileManager.default.createFile(atPath: tmp.appendingPathComponent(file).path, contents: Data())
        }

        let detected = Project.detectEnvFiles(in: tmp)
        try assertEqual(detected.count, 4)
        // .env should be first
        try assertEqual(detected[0].lastPathComponent, ".env")
        // Rest alphabetical: .env.development, .env.local, .env.production
        try assertEqual(detected[1].lastPathComponent, ".env.development")
        try assertEqual(detected[2].lastPathComponent, ".env.local")
        try assertEqual(detected[3].lastPathComponent, ".env.production")
    }

    test("detectEnvFiles returns empty for directory with no env files") {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Create a non-env file
        FileManager.default.createFile(atPath: tmp.appendingPathComponent("README.md").path, contents: Data())

        let detected = Project.detectEnvFiles(in: tmp)
        try assertEqual(detected.count, 0)
    }

    test("detectEnvFiles returns empty for nonexistent directory") {
        let fake = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString)")
        let detected = Project.detectEnvFiles(in: fake)
        try assertEqual(detected.count, 0)
    }

    test("envDisplayName returns Default for .env") {
        let url = URL(fileURLWithPath: "/project/.env")
        try assertEqual(Project.envDisplayName(for: url), "Default")
    }

    test("envDisplayName returns Local for .env.local") {
        let url = URL(fileURLWithPath: "/project/.env.local")
        try assertEqual(Project.envDisplayName(for: url), "Local")
    }

    test("envDisplayName returns Production for .env.production") {
        let url = URL(fileURLWithPath: "/project/.env.production")
        try assertEqual(Project.envDisplayName(for: url), "Production")
    }

    test("envDisplayName returns Development for .env.development") {
        let url = URL(fileURLWithPath: "/project/.env.development")
        try assertEqual(Project.envDisplayName(for: url), "Development")
    }

    test("Codable backward compat: old envFilePath decodes into envFiles") {
        let projectID = UUID()
        let pathURL = URL(fileURLWithPath: "/projects/myapp")
        let envURL = URL(fileURLWithPath: "/projects/myapp/.env")

        // Simulate old format JSON
        let oldJSON: [String: Any] = [
            "id": projectID.uuidString,
            "name": "MyApp",
            "path": pathURL.absoluteString,
            "envFilePath": envURL.absoluteString,
        ]
        let data = try JSONSerialization.data(withJSONObject: oldJSON)
        let project = try JSONDecoder().decode(Project.self, from: data)

        try assertEqual(project.id, projectID)
        try assertEqual(project.name, "MyApp")
        try assertEqual(project.envFiles.count, 1)
        try assertEqual(project.envFiles[0], envURL)
    }

    test("Codable: new envFiles format round-trips") {
        let path = URL(fileURLWithPath: "/projects/myapp")
        let envFiles = [
            URL(fileURLWithPath: "/projects/myapp/.env"),
            URL(fileURLWithPath: "/projects/myapp/.env.local"),
        ]
        let original = Project(name: "MyApp", path: path, envFiles: envFiles)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        try assertEqual(decoded.id, original.id)
        try assertEqual(decoded.name, "MyApp")
        try assertEqual(decoded.envFiles.count, 2)
        try assertEqual(decoded.envFiles[0], envFiles[0])
        try assertEqual(decoded.envFiles[1], envFiles[1])
    }

    test("Project init defaults to single .env when no envFiles provided") {
        let path = URL(fileURLWithPath: "/projects/myapp")
        let project = Project(name: "MyApp", path: path)
        try assertEqual(project.envFiles.count, 1)
        try assertEqual(project.envFiles[0].lastPathComponent, ".env")
    }

    test("refreshEnvFiles re-scans directory") {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Start with just .env
        FileManager.default.createFile(atPath: tmp.appendingPathComponent(".env").path, contents: Data())
        var project = Project(name: "Test", path: tmp, envFiles: Project.detectEnvFiles(in: tmp))
        try assertEqual(project.envFiles.count, 1)

        // Add another env file
        FileManager.default.createFile(atPath: tmp.appendingPathComponent(".env.staging").path, contents: Data())
        project.refreshEnvFiles()
        try assertEqual(project.envFiles.count, 2)
    }
}
