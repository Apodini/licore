// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "licore",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .executable(name: "Run", targets: ["Run"]),
        .library(name: "App", targets: ["App"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.4.1"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0-rc.2.2"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0-rc.2"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0-rc.1.2"),
        .package(url: "https://github.com/vapor/queues.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0-rc.3"),
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.39.1"),
        .package(url: "https://github.com/weichsel/ZIPFoundation/", from: "0.9.10")
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "Vapor", package: "vapor"),
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
            .product(name: "Leaf", package: "leaf"),
            .product(name: "Queues", package: "queues"),
            .product(name: "QueuesRedisDriver", package: "queues-redis-driver"),
            .product(name: "SwiftLintFramework", package: "SwiftLint"),
            .product(name: "ZIPFoundation", package: "ZIPFoundation")
        ]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App", "XCTVapor"])
    ]
)
