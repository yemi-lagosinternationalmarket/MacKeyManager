import Foundation
import MacKeyManagerLib

func runShellParserTests() {
    print("\n--- ShellParser Tests ---")

    test("Parse simple unquoted export") {
        let lines = ShellParser.parse("export PATH=/usr/local/bin")
        try assertEqual(lines.count, 1)
        if case .export(let name, let value, _) = lines[0] {
            try assertEqual(name, "PATH")
            try assertEqual(value, "/usr/local/bin")
        } else {
            throw TestError.assertionFailed("Expected .export")
        }
    }

    test("Parse double-quoted export") {
        let lines = ShellParser.parse(#"export API_KEY="abc123""#)
        if case .export(let name, let value, _) = lines[0] {
            try assertEqual(name, "API_KEY")
            try assertEqual(value, "abc123")
        } else {
            throw TestError.assertionFailed("Expected .export")
        }
    }

    test("Parse single-quoted export") {
        let lines = ShellParser.parse("export SECRET='my secret value'")
        if case .export(_, let value, _) = lines[0] {
            try assertEqual(value, "my secret value")
        } else {
            throw TestError.assertionFailed("Expected .export")
        }
    }

    test("Parse spaces in value") {
        let lines = ShellParser.parse(#"export GREETING="hello world""#)
        if case .export(_, let value, _) = lines[0] {
            try assertEqual(value, "hello world")
        } else {
            throw TestError.assertionFailed("Expected .export")
        }
    }

    test("Parse empty value") {
        let lines = ShellParser.parse("export EMPTY=")
        if case .export(let name, let value, _) = lines[0] {
            try assertEqual(name, "EMPTY")
            try assertEqual(value, "")
        } else {
            throw TestError.assertionFailed("Expected .export")
        }
    }

    test("Comment line preserved as .other") {
        let lines = ShellParser.parse("# This is a comment")
        try assertEqual(lines.count, 1)
        if case .other(let text) = lines[0] {
            try assertEqual(text, "# This is a comment")
        } else {
            throw TestError.assertionFailed("Expected .other")
        }
    }

    test("Commented-out export is .other") {
        let lines = ShellParser.parse("# export OLD_VAR=value")
        if case .other = lines[0] {
            // Expected
        } else {
            throw TestError.assertionFailed("Commented export should be .other")
        }
    }

    test("Blank line preserved") {
        let lines = ShellParser.parse("")
        try assertEqual(lines.count, 1)
        if case .other(let text) = lines[0] {
            try assertEqual(text, "")
        } else {
            throw TestError.assertionFailed("Expected .other")
        }
    }

    test("Alias line preserved as .other") {
        let lines = ShellParser.parse("alias ll='ls -la'")
        if case .other(let text) = lines[0] {
            try assertEqual(text, "alias ll='ls -la'")
        } else {
            throw TestError.assertionFailed("Expected .other")
        }
    }

    test("Inline comment stripped") {
        let lines = ShellParser.parse("export FOO=bar # this is a comment")
        if case .export(_, let value, _) = lines[0] {
            try assertEqual(value, "bar")
        } else {
            throw TestError.assertionFailed("Expected .export")
        }
    }

    test("Inline comment inside quotes preserved") {
        let lines = ShellParser.parse(#"export MSG="hello # world""#)
        if case .export(_, let value, _) = lines[0] {
            try assertEqual(value, "hello # world")
        } else {
            throw TestError.assertionFailed("Expected .export")
        }
    }

    test("Mixed file parses correctly") {
        let content = "# My zshrc config\nexport PATH=/usr/local/bin:$PATH\n\nalias gs='git status'\n\nexport EDITOR=vim\n# export OLD_VAR=deprecated"
        let lines = ShellParser.parse(content)
        try assertEqual(lines.count, 7)

        var exportCount = 0
        var otherCount = 0
        for line in lines {
            switch line {
            case .export: exportCount += 1
            case .other: otherCount += 1
            }
        }
        try assertEqual(exportCount, 2)
        try assertEqual(otherCount, 5)
    }

    test("Reconstruction is faithful") {
        let original = "# Config\nexport FOO=bar\nalias ll='ls -la'\nexport BAZ=\"hello world\""
        let lines = ShellParser.parse(original)
        let reconstructed = ShellParser.reconstruct(lines)
        try assertEqual(reconstructed, original)
    }

    test("Build unquoted export line") {
        let line = ShellParser.buildExportLine(name: "FOO", value: "bar")
        try assertEqual(line, "export FOO=bar")
    }

    test("Build quoted export line") {
        let line = ShellParser.buildExportLine(name: "MSG", value: "hello world")
        try assertEqual(line, "export MSG=\"hello world\"")
    }

    test("Build empty value export line") {
        let line = ShellParser.buildExportLine(name: "EMPTY", value: "")
        try assertEqual(line, "export EMPTY=\"\"")
    }

    test("Valid variable names") {
        try assertTrue(ShellParser.isValidVariableName("FOO"))
        try assertTrue(ShellParser.isValidVariableName("_PRIVATE"))
        try assertTrue(ShellParser.isValidVariableName("my_var_123"))
        try assertTrue(ShellParser.isValidVariableName("A"))
    }

    test("Invalid variable names") {
        try assertFalse(ShellParser.isValidVariableName("123ABC"))
        try assertFalse(ShellParser.isValidVariableName("MY-VAR"))
        try assertFalse(ShellParser.isValidVariableName("MY VAR"))
        try assertFalse(ShellParser.isValidVariableName(""))
        try assertFalse(ShellParser.isValidVariableName("foo.bar"))
    }

    test("Extract variables with correct line numbers") {
        let content = "# comment\nexport A=1\n\nexport B=2"
        let url = URL(fileURLWithPath: "/test/.zshrc")
        let lines = ShellParser.parse(content)
        let vars = ShellParser.extractVariables(from: lines, sourceFile: url)

        try assertEqual(vars.count, 2)
        try assertEqual(vars[0].name, "A")
        try assertEqual(vars[0].lineNumber, 2)
        try assertEqual(vars[0].scope, .global)
        try assertEqual(vars[1].name, "B")
        try assertEqual(vars[1].lineNumber, 4)
    }
}
