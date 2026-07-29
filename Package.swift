// swift-tools-version:5.9
// SPM package exposing the CalcManager C++ engine to Swift on macOS.
import PackageDescription

let package = Package(
    name: "MacCalculator",
    platforms: [.macOS(.v13)],
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
            name: "calc-smoke",
            dependencies: ["CalcManagerBridge"],
            path: "src/MacSmoke"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
