import Foundation

@main
struct TestMain {
    static func main() {
        print("MacKeyManager Test Suite")
        print(String(repeating: "=", count: 50))

        runShellParserTests()
        runEnvFileParserTests()
        runZshrcServiceTests()
        runDotEnvServiceTests()
        runCatalogServiceTests()
        runValidatorTests()

        printResults()

        if !failedTests.isEmpty {
            exit(1)
        }
    }
}
