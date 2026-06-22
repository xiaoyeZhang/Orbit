// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "OrbitUI",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "OrbitUI", targets: ["OrbitUI"]),
    ],
    dependencies: [
        .package(path: "../OrbitCore"),
    ],
    targets: [
        .target(
            name: "OrbitUI",
            dependencies: ["OrbitCore"],
            path: "Sources/OrbitUI"
        ),
    ]
)
