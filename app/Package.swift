// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Hangar",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "HangarCore"),
        .executableTarget(
            name: "Hangar",
            dependencies: ["HangarCore"]
        ),
        .executableTarget(
            name: "hangar-probe",
            dependencies: ["HangarCore"]
        ),
        // Named for the file it builds, not the command it becomes: the app
        // target is "Hangar", and macOS filesystems are case insensitive, so a
        // target called "hangar" would collide with it in one build directory.
        // `scripts/bundle.sh` installs it as Contents/Helpers/hangar.
        .executableTarget(
            name: "hangar-cli",
            dependencies: ["HangarCore"]
        ),
        .testTarget(
            name: "HangarCoreTests",
            dependencies: ["HangarCore"]
        ),
    ]
)
