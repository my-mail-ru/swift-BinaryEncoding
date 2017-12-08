// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "BinaryEncoding",
	products: [
		.library(name: "BinaryEncoding", targets: ["BinaryEncoding"]),
	],
	targets: [
		.target(name: "BinaryEncoding"),
		.testTarget(name: "BinaryEncodingTests", dependencies: ["BinaryEncoding"]),
	]
)
