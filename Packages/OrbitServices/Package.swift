// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrbitServices",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "OrbitServices", targets: ["OrbitServices"]),
    ],
    dependencies: [
        .package(path: "../OrbitCore"),
    ],
    targets: [
        .target(
            name: "OrbitServices",
            dependencies: ["OrbitCore"],
            path: "Sources/OrbitServices",
            swiftSettings: [
                // 启用 Firebase 后端：在 Xcode 的 Other Swift Flags 加 -DORBIT_FIREBASE
                // .define("ORBIT_FIREBASE"),
            ]
        ),
    ]
)
