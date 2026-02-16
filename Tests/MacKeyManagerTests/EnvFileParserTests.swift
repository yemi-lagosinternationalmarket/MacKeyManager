import Foundation
import MacKeyManagerLib

func runEnvFileParserTests() {
    print("\n--- EnvFileParser Tests ---")

    test("Parse simple KEY=VALUE") {
        let lines = EnvFileParser.parse("DATABASE_URL=postgres://localhost/mydb")
        if case .export(let name, let value, _) = lines[0] {
            try assertEqual(name, "DATABASE_URL")
            try assertEqual(value, "postgres://localhost/mydb")
        } else {
            throw TestError.assertionFailed("Expected .export")
        }
    }

    test("Parse with export prefix") {
        let lines = EnvFileParser.parse("export API_KEY=abc123")
        if case .export(let name, let value, _) = lines[0] {
            try assertEqual(name, "API_KEY")
            try assertEqual(value, "abc123")
        } else {
            throw TestError.assertionFailed("Expected .export")
        }
    }

    test("Parse double-quoted value") {
        let lines = EnvFileParser.parse("SECRET=\"my secret\"")
        if case .export(_, let value, _) = lines[0] {
            try assertEqual(value, "my secret")
        } else {
            throw TestError.assertionFailed("Expected .export")
        }
    }

    test("Parse single-quoted value") {
        let lines = EnvFileParser.parse("TOKEN='abc-123-def'")
        if case .export(_, let value, _) = lines[0] {
            try assertEqual(value, "abc-123-def")
        } else {
            throw TestError.assertionFailed("Expected .export")
        }
    }

    test("Comment lines preserved") {
        let lines = EnvFileParser.parse("# Database settings")
        if case .other(let text) = lines[0] {
            try assertEqual(text, "# Database settings")
        } else {
            throw TestError.assertionFailed("Expected .other")
        }
    }

    test("Blank lines preserved") {
        let lines = EnvFileParser.parse("")
        if case .other(let text) = lines[0] {
            try assertEqual(text, "")
        } else {
            throw TestError.assertionFailed("Expected .other")
        }
    }

    test("Complete .env file") {
        let content = "# Database\nDB_HOST=localhost\nDB_PORT=5432\nDB_NAME=\"my_database\"\n\n# API\nAPI_KEY=secret123\nAPI_URL=\"https://api.example.com\""
        let lines = EnvFileParser.parse(content)

        var exportCount = 0
        var otherCount = 0
        for line in lines {
            switch line {
            case .export: exportCount += 1
            case .other: otherCount += 1
            }
        }
        try assertEqual(exportCount, 5)
        try assertEqual(otherCount, 3)
    }

    test("Reconstruction is faithful") {
        let original = "# Config\nKEY=value\nSECRET=\"hello world\""
        let lines = EnvFileParser.parse(original)
        let reconstructed = EnvFileParser.reconstruct(lines)
        try assertEqual(reconstructed, original)
    }

    test("Inline comment stripped") {
        let lines = EnvFileParser.parse("PORT=3000 # server port")
        if case .export(_, let value, _) = lines[0] {
            try assertEqual(value, "3000")
        } else {
            throw TestError.assertionFailed("Expected .export")
        }
    }

    test("Build simple line") {
        let line = EnvFileParser.buildLine(name: "KEY", value: "value")
        try assertEqual(line, "KEY=value")
    }

    test("Build quoted line") {
        let line = EnvFileParser.buildLine(name: "MSG", value: "hello world")
        try assertEqual(line, "MSG=\"hello world\"")
    }

    test("Extract variables with project scope") {
        let content = "# Config\nKEY=value\nSECRET=abc"
        let url = URL(fileURLWithPath: "/project/.env")
        let lines = EnvFileParser.parse(content)
        let vars = EnvFileParser.extractVariables(from: lines, sourceFile: url)

        try assertEqual(vars.count, 2)
        try assertEqual(vars[0].scope, .project)
        try assertEqual(vars[0].name, "KEY")
        try assertEqual(vars[1].name, "SECRET")
    }
}
