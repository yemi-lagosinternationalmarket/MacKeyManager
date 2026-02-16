import Foundation

public enum Validators {
    /// Validate an environment variable name.
    /// Must match [A-Za-z_][A-Za-z0-9_]* and not be empty.
    public static func validateVariableName(_ name: String) -> Result<Void, MacKeyManagerError> {
        guard !name.isEmpty else {
            return .failure(.invalidVariableName(name))
        }

        guard ShellParser.isValidVariableName(name) else {
            return .failure(.invalidVariableName(name))
        }

        return .success(())
    }

    /// Check for duplicate variable names in a list.
    public static func checkDuplicate(
        name: String,
        in variables: [EnvironmentVariable],
        excluding id: UUID? = nil
    ) -> Result<Void, MacKeyManagerError> {
        let exists = variables.contains { variable in
            variable.name == name && variable.id != id
        }

        if exists {
            return .failure(.duplicateVariable(name))
        }

        return .success(())
    }
}
