// Tests/AppTests/XCTestManifests.swift
import XCTest

public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AnalysisTests.allTests),
        testCase(AppTests.allTests),
        // Future test case registrations here.
    ]
}