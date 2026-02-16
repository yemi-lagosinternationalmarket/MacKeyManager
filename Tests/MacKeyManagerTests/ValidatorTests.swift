import Foundation
import MacKeyManagerLib

func runValidatorTests() {
    print("\n--- Validator Tests ---")

    test("Valid standard names") {
        try assertNoThrow(try Validators.validateVariableName("FOO").get())
        try assertNoThrow(try Validators.validateVariableName("API_KEY").get())
        try assertNoThrow(try Validators.validateVariableName("_PRIVATE").get())
        try assertNoThrow(try Validators.validateVariableName("my_var_123").get())
        try assertNoThrow(try Validators.validateVariableName("A").get())
        try assertNoThrow(try Validators.validateVariableName("PATH").get())
        try assertNoThrow(try Validators.validateVariableName("HOME").get())
    }

    test("Invalid names rejected") {
        try assertThrows(try Validators.validateVariableName("").get())
        try assertThrows(try Validators.validateVariableName("123ABC").get())
        try assertThrows(try Validators.validateVariableName("MY-VAR").get())
        try assertThrows(try Validators.validateVariableName("MY VAR").get())
        try assertThrows(try Validators.validateVariableName("foo.bar").get())
        try assertThrows(try Validators.validateVariableName("a@b").get())
        try assertThrows(try Validators.validateVariableName("my/var").get())
    }

    test("No duplicate for unique name") {
        let variables = [
            EnvironmentVariable(name: "FOO", value: "1", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/test")),
            EnvironmentVariable(name: "BAR", value: "2", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/test"))
        ]
        try assertNoThrow(try Validators.checkDuplicate(name: "BAZ", in: variables).get())
    }

    test("Duplicate detected") {
        let variables = [
            EnvironmentVariable(name: "FOO", value: "1", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/test"))
        ]
        try assertThrows(try Validators.checkDuplicate(name: "FOO", in: variables).get())
    }

    test("Duplicate check excludes specified ID") {
        let id = UUID()
        let variables = [
            EnvironmentVariable(id: id, name: "FOO", value: "1", scope: .global,
                              sourceFile: URL(fileURLWithPath: "/test"))
        ]
        try assertNoThrow(try Validators.checkDuplicate(name: "FOO", in: variables, excluding: id).get())
    }
}
