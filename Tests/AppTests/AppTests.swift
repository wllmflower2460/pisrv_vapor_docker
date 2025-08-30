import App
import XCTest

final class AppTests: XCTestCase {
    func testNothing() throws {
        XCTAssert(true)
    }
#if !os(macOS)
    static var allTests: [(String, (AppTests) -> () throws -> Void)] {
        [
            ("testNothing", testNothing)
        ]
    }
#endif
}
