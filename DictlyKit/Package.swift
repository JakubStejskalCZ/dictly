// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DictlyKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DictlyKit",
            targets: ["DictlyModels", "DictlyTheme", "DictlyStorage", "DictlyExport"]
        )
    ],
    targets: [
        .target(
            name: "DictlyModels",
            path: "Sources/DictlyModels"
        ),
        .target(
            name: "DictlyTheme",
            path: "Sources/DictlyTheme"
        ),
        .target(
            name: "DictlyStorage",
            path: "Sources/DictlyStorage"
        ),
        .target(
            name: "DictlyExport",
            path: "Sources/DictlyExport"
        ),
        .testTarget(
            name: "DictlyModelsTests",
            dependencies: ["DictlyModels"],
            path: "Tests/DictlyModelsTests"
        ),
        .testTarget(
            name: "DictlyThemeTests",
            dependencies: ["DictlyTheme"],
            path: "Tests/DictlyThemeTests"
        )
    ]
)
