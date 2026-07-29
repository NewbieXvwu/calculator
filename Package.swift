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
        .target(
            name: "GiacBridge",
            path: "src/MacGiacBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                // libgiac.a 由 tools/build_giac.sh 产出到 third_party/giac/lib，
                // 依赖 Homebrew 的 gmp/mpfr/gettext；-L 相对路径要求在仓库根执行 swift build。
                .unsafeFlags(["-Lthird_party/giac/lib", "-L/opt/homebrew/lib"]),
                .linkedLibrary("giac"),
                .linkedLibrary("mpfr"),
                .linkedLibrary("gmp"),
                .linkedLibrary("gmpxx"),
                .linkedLibrary("intl"),
                .linkedFramework("Accelerate"),
            ]
        ),
        .executableTarget(
            name: "MacCalculator",
            dependencies: ["CalcManagerBridge", "GiacBridge"],
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
        .testTarget(
            name: "MacAppTests",
            dependencies: ["MacCalculator"],
            path: "src/MacAppTests"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
