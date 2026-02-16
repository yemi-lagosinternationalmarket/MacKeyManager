import Foundation

// Simple test harness for running without XCTest/Testing frameworks
var totalTests = 0
var passedTests = 0
var failedTests: [(String, String)] = []

func test(_ name: String, _ body: () throws -> Void) {
    totalTests += 1
    do {
        try body()
        passedTests += 1
        print("  PASS  \(name)")
    } catch {
        failedTests.append((name, "\(error)"))
        print("  FAIL  \(name): \(error)")
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, file: String = #file, line: Int = #line) throws {
    guard a == b else {
        throw TestError.assertionFailed("Expected \(a) == \(b) at \(file):\(line)")
    }
}

func assertTrue(_ value: Bool, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard value else {
        throw TestError.assertionFailed("Expected true\(message.isEmpty ? "" : ": \(message)") at \(file):\(line)")
    }
}

func assertFalse(_ value: Bool, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard !value else {
        throw TestError.assertionFailed("Expected false\(message.isEmpty ? "" : ": \(message)") at \(file):\(line)")
    }
}

func assertThrows<T>(_ body: @autoclosure () throws -> T, file: String = #file, line: Int = #line) throws {
    do {
        _ = try body()
        throw TestError.assertionFailed("Expected throw at \(file):\(line)")
    } catch is TestError {
        throw TestError.assertionFailed("Expected throw at \(file):\(line)")
    } catch {
        // Expected
    }
}

func assertNoThrow<T>(_ body: @autoclosure () throws -> T, file: String = #file, line: Int = #line) throws {
    do {
        _ = try body()
    } catch {
        throw TestError.assertionFailed("Unexpected throw: \(error) at \(file):\(line)")
    }
}

enum TestError: Error {
    case assertionFailed(String)
}

func printResults() {
    print("\n" + String(repeating: "=", count: 50))
    print("Results: \(passedTests)/\(totalTests) passed")
    if !failedTests.isEmpty {
        print("\nFailed tests:")
        for (name, error) in failedTests {
            print("  - \(name): \(error)")
        }
    }
    print(String(repeating: "=", count: 50))
}
