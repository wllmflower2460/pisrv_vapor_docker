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
        .package(url: "https://github.com/vapor/vapor.git", from: "4.83.0")
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [ .product(name: "Vapor", package: "vapor") ],
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
