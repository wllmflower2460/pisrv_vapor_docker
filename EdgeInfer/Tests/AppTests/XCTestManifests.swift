// Tests/AppTests/XCTestManifests.swift
import XCTest

public func allTests() -> [XCTestCaseEntry] {
    return [
        // Keep existing test suites if any:
        // testCase(AnalysisTests.allTests),
        testCase(AnalysisRealPathTests.allTests),
    ]
}
