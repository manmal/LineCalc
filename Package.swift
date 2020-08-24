// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "LineCalc",
    products: [
        .library(
            name: "LineCalc",
            targets: ["LineCalc"]),
    ],
    dependencies: [
        .package(name: "NonEmpty", url: "https://github.com/pointfreeco/swift-nonempty.git", from: "0.2.2")
    ],
    targets: [
        .target(
            name: "LineCalc",
            dependencies: [.init(stringLiteral: "NonEmpty")]),
        .testTarget(
            name: "LineCalcTests",
            dependencies: ["LineCalc"]),
    ]
)
