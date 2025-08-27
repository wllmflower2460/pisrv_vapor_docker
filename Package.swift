// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VaporApp",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "VaporApp",
            targets: ["App"]
        ),
        .executable(
            name: "Run",
            targets: ["Run"]
        ),
    ],
    dependencies: [
        // 💧 Vapor framework
        .package(url: "https://github.com/vapor/vapor.git", from: "4.83.0"),
        // 🔵 Fluent ORM core
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        // 🔵 Fluent SQLite-driver for Vapor
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.4.0"),
    ],
    targets: [
    .target(
        name: "App",
        dependencies: [
            .product(name: "Vapor", package: "vapor"),
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
        ],
        path: "Sources/App"
    ),
    .executableTarget(
        name: "Run",
        dependencies: ["App"],
        path: "Sources/Run"
    ),
    .testTarget(
        name: "AppTests",
        dependencies: ["App"],
        path: "Tests/AppTests"
    ),
]
)
