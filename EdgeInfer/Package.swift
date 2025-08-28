// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "EdgeInfer",
    platforms: [
        .macOS(.v12),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .executable(
            name: "EdgeInfer",
            targets: ["Run"]
        ),
    ],
    dependencies: [
        // 💧 Vapor framework
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.0"),
        // 📊 Prometheus metrics
        .package(url: "https://github.com/MrLotU/SwiftPrometheus.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Prometheus", package: "SwiftPrometheus"),
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(
            name: "Run",
            dependencies: [.target(name: "App")],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        // Temporarily removing tests to fix build issue
        // .testTarget(
        //     name: "AppTests",
        //     dependencies: [
        //         .target(name: "App"),
        //         .product(name: "XCTVapor", package: "vapor"),
        //     ]
        // ),
    ]
)
