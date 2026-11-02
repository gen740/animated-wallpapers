// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Wallpaper",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PenroseWallpaper", targets: ["PenroseWallpaper"]),
        .executable(name: "LifeWallpaper", targets: ["LifeWallpaper"])
    ],
    targets: [
        .executableTarget(name: "PenroseWallpaper"),
        .executableTarget(name: "LifeWallpaper")
    ]
)
