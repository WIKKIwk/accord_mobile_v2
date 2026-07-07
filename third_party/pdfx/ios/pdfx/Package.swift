// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "pdfx",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "pdfx", targets: ["pdfx"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "pdfx",
            dependencies: [
                "pdfx_messages",
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            exclude: [
                "PdfxPlugin.h",
                "PdfxPlugin.m",
                "messages.h",
                "messages.m",
                "pdfx.h"
            ],
            cSettings: [
                .headerSearchPath(".")
            ]
        ),
        .target(
            name: "pdfx_messages",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            path: "Sources/pdfx_messages",
            sources: [
                "messages.m"
            ],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        )
    ]
)
