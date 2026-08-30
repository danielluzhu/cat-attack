// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CatAttack",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "CatAttackCore",
            path: "Sources/CatAttackCore"
        ),
        .executableTarget(
            name: "CatAttack",
            dependencies: ["CatAttackCore"],
            path: "Sources/CatAttack"
        ),
        .testTarget(
            name: "CatAttackTests",
            dependencies: ["CatAttackCore"],
            path: "Tests/CatAttackTests"
        ),
    ]
)
