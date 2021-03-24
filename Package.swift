// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "WorkSequencer",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "WorkSequencer",
            targets: ["WorkSequencer"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/combine-schedulers",
            .branch("main"))
    ],
    targets: [
        .target(
            name: "WorkSequencer",
            dependencies: [
                .product(name: "CombineSchedulers", package: "combine-schedulers")
            ]),
        .testTarget(
            name: "WorkSequencerTests",
            dependencies: [
                "WorkSequencer"
            ]),
    ]
)
