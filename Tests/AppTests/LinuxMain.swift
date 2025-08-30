// Tests/AppTests/LinuxMain.swift
#if os(Linux)
import XCTest
import AppTests

@main
struct LinuxMain {
    static func main() {
        XCTMain(allTests())
    }
}
#endif