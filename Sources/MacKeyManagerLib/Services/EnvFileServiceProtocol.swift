import Foundation

/// Protocol for environment file services (ZshrcService, DotEnvService).
/// Provides a uniform interface for loading, modifying, and saving environment variables
/// backed by different file formats.
public protocol EnvFileServiceProtocol {
    var fileURL: URL { get }
    var parsedLines: [ParsedLine] { get }
    var variables: [EnvironmentVariable] { get }
    var isDirty: Bool { get }

    func load() throws
    func add(name: String, value: String) throws
    func update(variableID: UUID, name: String, value: String) throws
    func remove(variableID: UUID) throws
    func save() throws
}
