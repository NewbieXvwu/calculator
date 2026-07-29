// swift-tools-version:5.9
// SPM package exposing the CalcManager C++ engine to Swift on macOS.
import PackageDescription

let package = Package(
    name: "MacCalculator",
    platforms: [.macOS("26.0")],
    targets: [
        .target(
            name: "CalcManagerCore",
            path: "src/CalcManager",
            exclude: [
                "CalcManager.vcxproj",
                "CalcManager.vcxproj.filters",
                "ratpak.natvis",
                "CMakeLists.txt",
                "pch.cpp",
                "smoketest",
            ],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .headerSearchPath("Ratpack"),
            ]
        ),
        .target(
            name: "CalcManagerBridge",
            dependencies: ["CalcManagerCore"],
            path: "src/MacBridge",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../CalcManager"),
            ]
        ),
        .executableTarget(
            name: "MacCalculator",
            dependencies: ["CalcManagerBridge"],
            path: "src/MacApp",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "calc-smoke",
            dependencies: ["CalcManagerBridge"],
            path: "src/MacSmoke"
        ),
        .executableTarget(
            name: "engine-tests",
            dependencies: ["CalcManagerCore"],
            path: "src/MacEngineTests",
            cxxSettings: [
                .headerSearchPath("shim"),
                .headerSearchPath("."),
                .headerSearchPath(".."),
                .headerSearchPath("../CalcManager"),
                .headerSearchPath("../MacBridge"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
