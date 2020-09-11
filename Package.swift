// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "LineCalc",
    products: [
        .library(
            name: "LineCalc",
            targets: ["LineCalc"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LineCalc",
            dependencies: []),
        .testTarget(
            name: "LineCalcTests",
            dependencies: ["LineCalc"]),
    ]
)
