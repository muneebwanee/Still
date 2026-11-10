// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ReceiverCore", platforms: [.iOS(.v17), .macOS(.v13)], products: [.library(name: "ReceiverCore", targets: ["ReceiverCore"])], targets: [.target(name: "ReceiverCore"), .testTarget(name: "ReceiverCoreTests", dependencies: ["ReceiverCore"])])
