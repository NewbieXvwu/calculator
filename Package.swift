// swift-tools-version:5.9
// SPM package exposing the CalcManager C++ engine to Swift on macOS.
import PackageDescription

// giac 静态库与 Homebrew 依赖路径：默认适配 Apple Silicon + 仓库内产物，
// 可用环境变量覆盖（CI / Intel `/usr/local` / 自定义前缀）。
// giac 路径解析为绝对路径（根于包目录），构建不再要求 cwd == 仓库根。
let giacLibDir = Context.environment["GIAC_LIB_DIR"]
    ?? "\(Context.packageDirectory)/third_party/giac/lib"
let homebrewPrefix = Context.environment["HOMEBREW_PREFIX"] ?? "/opt/homebrew"

let package = Package(
    name: "MacCalculator",
    defaultLocalization: "en",
    // 部署目标 macOS 13：Liquid Glass 等 26-only API 经 #available 运行时回退（见 Support/PlatformCompat.swift）。
    platforms: [.macOS("13.0")],
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
                // Release 提速：覆盖 Xcode 默认的 -Os（与 giac 官方 full-speed 建议的 -O3 对齐）。
                .unsafeFlags(["-O3"], .when(configuration: .release)),
            ]
        ),
        .target(
            name: "CalcManagerBridge",
            dependencies: ["CalcManagerCore"],
            path: "src/MacBridge",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../CalcManager"),
                .unsafeFlags(["-O3"], .when(configuration: .release)),
            ]
        ),
        .target(
            name: "GiacBridge",
            path: "src/MacGiacBridge",
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags(["-O3"], .when(configuration: .release)),
            ],
            linkerSettings: [
                // libgiac.a 由 Tools/build_giac.sh 产出到 third_party/giac/lib，
                // 依赖 Homebrew 的 gmp/mpfr/gettext。路径见文件顶部：giac 已解析为
                // 绝对路径，Homebrew 前缀可经 HOMEBREW_PREFIX 覆盖，不再绑定仓库根/Apple Silicon。
                .unsafeFlags(["-L\(giacLibDir)", "-L\(homebrewPrefix)/lib"]),
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
            resources: [
                .process("Resources"),
                // MathLive 需保留目录结构（mathfield.html 相对引用 js/fonts）。
                .copy("MathLiveAssets"),
            ]
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
