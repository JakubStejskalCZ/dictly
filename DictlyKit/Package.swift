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
            dependencies: ["DictlyModels"],
            path: "Sources/DictlyStorage",
            linkerSettings: [
                .linkedFramework("CoreSpotlight")
            ]
        ),
        .target(
            name: "DictlyExport",
            dependencies: ["DictlyModels"],
            path: "Sources/DictlyExport"
        ),
        .testTarget(
            name: "DictlyModelsTests",
            dependencies: ["DictlyModels", "DictlyStorage"],
            path: "Tests/DictlyModelsTests"
        ),
        .testTarget(
            name: "DictlyThemeTests",
            dependencies: ["DictlyTheme"],
            path: "Tests/DictlyThemeTests"
        ),
        .testTarget(
            name: "DictlyStorageTests",
            dependencies: ["DictlyStorage"],
            path: "Tests/DictlyStorageTests"
        ),
        .testTarget(
            name: "DictlyExportTests",
            dependencies: ["DictlyExport", "DictlyModels"],
            path: "Tests/DictlyExportTests"
        )
    ]
)
