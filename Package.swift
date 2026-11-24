// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "utodo",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "utodo", targets: ["utodo-cli"]),
        .executable(name: "UTodoApp", targets: ["UTodoApp"]),
    ],
    targets: [
        .target(name: "UTodoCore", linkerSettings: [.linkedLibrary("sqlite3")]),
        .executableTarget(name: "utodo-cli", dependencies: ["UTodoCore"]),
        .executableTarget(name: "UTodoApp", dependencies: ["UTodoCore"]),
        .testTarget(name: "UTodoCoreTests", dependencies: ["UTodoCore"]),
    ]
)
