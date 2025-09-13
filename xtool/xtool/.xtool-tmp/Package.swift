// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "SoundToLightTherapy-Builder",
    platforms: [
        .iOS("17.0"),
    ],
    dependencies: [
        .package(name: "RootPackage", path: "../.."),
    ],
    targets: [
        .executableTarget(
    name: "SoundToLightTherapy-App",
    dependencies: [
        .product(name: "SoundToLightTherapy", package: "RootPackage"),
    ],
    linkerSettings: [
    .unsafeFlags([
        "-Xlinker", "-rpath", "-Xlinker", "@executable_path/Frameworks",
    ]),
]
)
    ]
)
