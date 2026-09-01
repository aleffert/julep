// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "JulepKit",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "JulepKit", targets: ["JulepKit"])
    ],
    targets: [
        .target(name: "JulepKit"),
        .testTarget(
            name: "JulepKitTests",
            dependencies: ["JulepKit"],
            resources: [.copy("Resources/corpus.txt")]
        ),
    ]
)
