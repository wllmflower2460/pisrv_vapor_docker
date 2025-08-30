// SwiftPM automatic test discovery is used (Swift 5.4+).
// Deliberately left without any invocations; presence of an empty file previously
// triggered a Swift 6 test discovery JSON issue. Keeping a harmless comment
// avoids zero-length source edge case.
#if canImport(XCTest)
// No manual test manifest needed.
#endif
