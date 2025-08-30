// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "EdgeInfer",
    platforms: [ .macOS(.v13) ],
    products: [
        .executable(name: "Run", targets: ["Run"])
    ],
    dependencies: [
        // Vapor core only (Fluent removed)
        .package(url: "https://github.com/vapor/vapor.git", from: "4.83.0"),
        // Pin swift-system to a Swift 5.10 compatible tag to avoid IORing Swift 6 parser features
        .package(url: "https://github.com/apple/swift-system.git", exact: "1.3.0")
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SystemPackage", package: "swift-system")
            ],
            path: "Sources/App",
            exclude: [
                // Exclude legacy Todo components if still present
                "Controllers/TodoController.swift",
                "Migrations/CreateTodo.swift",
                "Models/Todo.swift"
            ]
        ),
        .executableTarget(
            name: "Run",
            dependencies: ["App"],
            path: "Sources/Run"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                "App",
                .product(name: "XCTVapor", package: "vapor")
            ],
            path: "Tests/AppTests"
        ),
    ]
)
