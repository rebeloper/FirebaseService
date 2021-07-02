// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FirebaseService",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "FirebaseService",
            targets: ["FirebaseService"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(name: "Firebase", url: "https://github.com/firebase/firebase-ios-sdk.git", .exact("8.2.0")),
        .package(name: "BetterCodable", url: "https://github.com/marksands/BetterCodable.git", .exact("0.3.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "FirebaseService",
            dependencies: [
                .product(name: "FirebaseAuth", package: "Firebase"),
                .product(name: "FirebaseFirestore", package: "Firebase"),
                .product(name: "FirebaseFirestoreSwift-Beta", package: "Firebase"),
                .product(name: "FirebaseStorage", package: "Firebase"),
                .product(name: "FirebaseStorageSwift-Beta", package: "Firebase"),
                "BetterCodable"
            ]),
        .testTarget(
            name: "FirebaseServiceTests",
            dependencies: ["FirebaseService"]),
    ]
)
