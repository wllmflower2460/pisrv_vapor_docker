// Tests/AppTests/LinuxMain.swift
#if os(Linux)
import XCTest

@main
struct LinuxMain {
    static func main() {
        XCTMain(allTests())
    }
}
#endif
