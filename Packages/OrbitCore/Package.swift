// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "OrbitCore",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "OrbitCore", targets: ["OrbitCore"]),
    ],
    targets: [
        .target(
            name: "OrbitCore",
            path: "Sources/OrbitCore"
        ),
    ]
)
