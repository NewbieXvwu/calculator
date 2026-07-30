# macOS 移植计划（TODO）

> 目标：将 Windows Calculator 1:1 移植到 macOS 原生技术栈（Swift/SwiftUI），
> 闭源绘图引擎用 Giac（GPLv3，已接受传染）替换。个人实验项目。
> 2026-07-29 的「对齐残差任务」（快捷键/CopyPaste/绘图/设置/无障碍/本地化管线等）已全部完成并有测试覆盖。
> **本文档现在只跟踪 2026-07-30 UI 忠实度全面审查发现的未修复问题**（对照基准 =
> 原版 XAML `src/Calculator/Views/` + macOS 平台惯例 + Apple 计算器交互参照）。
> 原则：不偷懒、不妥协；确属 Windows 平台特有而 macOS 无对应物的才可豁免，且必须记录豁免理由。

---

## 一、架构现状（速查）

- SPM 包（根 `Package.swift`，cxx20，**部署目标 macOS 13**）。Targets：
  `CalcManagerCore`（原版 C++ 引擎，零改动复用）→ `CalcManagerBridge`（ObjC++，`src/MacBridge`）
  → `MacCalculator`（SwiftUI，`src/MacApp`）；`GiacBridge`（`src/MacGiacBridge`，静态链 `third_party/giac/lib/libgiac.a`，
  由 `Tools/build_giac.sh` 构建）；测试 `calc-smoke` / `engine-tests` / `MacAppTests`。
- `src/MacApp` 分层目录：`App/`（入口 `@main`+AppDelegate）、`Models/`、`ViewModels/`、`Views/`、
  `Services/`（Giac、Currency、GraphAnalyzer、MarchingSquares）、`Support/`（本地化/剪贴板/无障碍）；
  `Resources/`（xcstrings）与 `MathLiveAssets/` 位置固定（Package.swift 按路径引用，勿移动）。
- 验证命令：`swift build --product MacCalculator`；`swift test`；`swift run calc-smoke`；`swift run engine-tests`。
  UI 文案/本地化与可分发构建走 xcodebuild（此路径才经 xcstringstool 编译 .xcstrings）：
  `xcodebuild test -scheme MacCalculator-Package -destination 'platform=macOS,arch=arm64'`。
- **版本兼容（部署目标 13）**：显式 Liquid Glass 及 macOS 26/14-only API 全部收进
  `src/MacApp/Support/PlatformCompat.swift` 的 `#available` 封装；按键玻璃回退在 `CalcKeyStyles.swift`。
- 排版规格书 = 原版 XAML（`src/Calculator/Views/`）；行为规格书 = 原版 ViewModel（`src/CalcViewModel/`）。

## 二、仍然有效的已定决策

1. **绘图**：CAS 用 Giac/Xcas（GPLv3，静态链接）；渲染自研（SwiftUI Canvas，隐式方程 marching squares）；
   公式编辑器 MathLive（MIT）+ WKWebView 离线打包。二进制发布整体 GPLv3，源码保持 MIT 文件头。
2. **汇率**：主源 fawazahmed0/exchange-api（Cloudflare Pages 端点优先，jsDelivr 备用），兜底 Frankfurter；
   每日刷新 + 失败回退缓存 + 显示时间戳。**严禁**逆向微软零售端点。
3. **UI 原则**：排版 1:1 对照 XAML，不自创设计；皮肤层用 macOS Liquid Glass；
   交互 chrome 按 macOS 惯例（快捷键进菜单栏、置顶用 `NSWindow.level`）。
4. **风险备忘**：fawazahmed0 是个人项目曾被下架，缓存+兜底不可省；
   ObjC++ 文件严禁直接 include 引擎头（必须经 `CalcSession` 门面）。

---

## 三、UI 忠实度审查问题清单（2026-07-30，全部未修复）

### P0-1 本地化系统性失效（最严重）
现状：60 语言 xcstrings 只服务无障碍标签，可见 UI 是另一套硬编码中文。
- [ ] 全部可见文案改走 String Catalog：各 View / `MacCalculatorApp.swift` 菜单 /
      `HistoryMemoryPanel`（"历史记录/内存/尚无历史记录…"）/ `GraphingView`（"函数/线条颜色/图形选项…"）/
      `SettingsView` 等所有硬编码中文串换成 `L10n`/`String(localized:)` 查表，英文系统显示英文
- [ ] `Tools/package_app.sh` 生成的 Info.plist 修正：`CFBundleDevelopmentRegion` 与实际一致、
      补 `CFBundleAllowMixedLocalizations`（否则 AppKit 系统菜单——应用/编辑/窗口/帮助——永远英文，
      与中文自定义菜单混搭，即用户实测现象）；确认主 bundle 语言协商能命中资源 bundle 的 .lproj
- [ ] 窗口标题硬编码 "计算器"（`MacCalculatorApp.swift:13`）改本地化
- [ ] `CommandMenu("模式")`/`CommandMenu("记忆")` 等全部菜单标题与菜单项本地化
- [ ] 验证：切系统语言 en/zh-Hans 两遍，菜单栏 + 窗口内文案 + 系统菜单三处语言一致

### P0-2 绘图无法拖动平移（功能性破损）
根因：`WindowConfigurator` 设 `window.isMovableByWindowBackground = true`（`CalcKeyStyles.swift:35`），
画布上的 `DragGesture`（`GraphingView.swift:868-880`）被 AppKit 抢去拖窗口，平移形同虚设。
- [ ] 解决拖窗与画布手势冲突（画布区域禁用背景拖窗：如 NSHostingView 覆盖 `mouseDownCanMoveWindow`，
      或整窗弃用 isMovableByWindowBackground、由标题栏区域拖动）
- [ ] 顺带核验捏合缩放/滚轮在画布上的可用性（真机）

### P0-3 `logo.playstation` 商标图标（ProgrammerCalculatorView.swift:136）
位运算下拉用了索尼 PS 商标图标，语义零关联 + 商标滥用风险。原版是计算器字体字形 U+F895
（`CalculatorProgrammerRadixOperators.xaml:241`）。
- [ ] 换 `point.3.filled.connected.trianglepath.dotted`（逻辑门拓扑感）或 `circle.grid.2x1.left.filled`
      （维恩图交并感）——两者均已验证本机存在

### P1-1 顶栏 chrome 重构（模式切换 + 历史按钮 + 动画）
现状（`CalculatorChrome.swift` + `ContentView.swift:14-42`）：
自绘顶栏放在**计算器列内部**而非整窗——宽窗停靠历史面板后模式按钮悬在窗口中间；
`.padding(.leading, 76)` 给红绿灯硬留白导致窄窗历史按钮距左缘 76pt；
历史按钮仅窗宽 < 560 时存在（宽窗消失、用户实测"点了会消失"）；
面板开合零动画、从右侧突兀出现；popover 式历史两头不靠（原版窄窗是全高覆盖层，macOS 惯例是侧栏）。
- [ ] 改用原生 `.toolbar`（Apple 计算器特写截图核实的布局基准）：
      历史按钮**常驻**工具栏 leading 端、紧贴红绿灯，图标用 `sidebar.leading`（Apple 同款侧栏开关，
      时钟图标只留给空态插画）；模式菜单按钮在工具栏 trailing 端（右上角本身就是 Apple 惯例，
      现病灶是自绘顶栏内嵌计算器列导致按钮悬在窗口中部）
- [ ] 历史/内存面板改为侧栏伸缩：常驻按钮 toggle + `withAnimation` 非线性动画开合
      （参照 Apple 计算器），替换现有"宽度阈值硬跳变 + 窄窗 popover"双态方案
- [ ] 删除 `.padding(.leading, 76)` 一类红绿灯硬编码留白（工具栏体系下不需要）
- [ ] 保留原版语义：程序员模式无历史；⌃H 开合、⇧⌃D 清除仍可用

### P1-2 绘图 graphView 按钮图标不可读（GraphingView.swift:716-723）
原版 graphViewButton（`GraphingCalculator.xaml:748-762`）在"手动调整 ⇄ 自动适应"两态切换字形；
本移植选的 `arrow.up.left.and.arrow.down.right` / `sparkle.magnifyingglass` 双态图标均无法传达语义
（用户实测："默认全屏图标，点了变魔法放大镜，不知道干什么用"）。
- [ ] 固定用 `arrow.up.left.and.down.right.magnifyingglass`（zoom-to-fit 惯例，已验证存在），
      手动调整态加 accentColor 高亮；tooltip 明确"恢复自动适应视图"

### P1-3 图标语义修正（除 P0-3/P1-2 外的全部替换项，均已验证本机存在）
- [ ] 程序员"移位"菜单 `arrow.left.arrow.right`（`ProgrammerCalculatorView.swift:152`）与
      "单位换算"模式图标（`CalculatorChrome.swift:44`）**一符两义撞车** → 移位改 `chevron.right.2`（`>>` 即移位运算符）
- [ ] 模式菜单按钮图标（`CalculatorChrome.swift:49,64-72`）：Apple 用私有"计算器"字形
      （圆角矩形 = 显示条 + 键盘点阵；SF 公共库无 `calculator`，已验证不存在）→
      自绘 custom SF symbol 对齐 Apple；过渡期可用 `circle.grid.3x3` 兜底
- [ ] 标准模式菜单项：菜单里 `plusminus`（`CalculatorChrome.swift:40`）vs 按钮 `square.grid.2x2`
      （`CalculatorChrome.swift:68`）不一致 → 对齐 Apple"基础"混合运算符字形，
      公共库最接近 `plus.slash.minus`（已验证存在），或随模式按钮一起自绘
- [ ] 科学模式 `function` 可保留，或换 Apple 同款 `fx`（已验证存在）
- [ ] 程序员模式 `chevron.left.forwardslash.chevron.right`（"写代码"）→ `cpu`（Apple 计算器同款芯片隐喻）
- [ ] 位翻转键盘段选 `switch.2`（`ProgrammerCalculatorView.swift:100`，拨杆勉强）→ `01.square`
- [ ] 绘图"函数分析"开关 `chart.bar.doc.horizontal`（`GraphingView.swift:51`，"报表"无关）→
      `doc.text.magnifyingglass` 或 `list.bullet.rectangle`
- [ ] 绘图删除方程 `xmark`（`GraphingView.swift:190`，"关闭"非"删除"，轻微）→ 评估换 `trash` 或保留
- 合格无需动（复查结论，30 处中 22 处）：`function`/`calendar`/`arrow.left.arrow.right`(换算)/
  `chart.xyaxis.line`/`clock.arrow.circlepath`(**仅空态插画**；工具栏历史按钮归 P1-1 改 `sidebar.leading`)/
  `trash`/`memorychip`/`plus`/`eye`(.slash)/
  `exclamationmark.circle.fill`/`plus.circle`/`minus.circle`/`slider.horizontal.3`/`scope`/
  `square.and.arrow.up`/`gearshape`/`plus.magnifyingglass`/`minus.magnifyingglass`/`angle`/
  `f.cursive`/`arrow.clockwise`/`arrow.up.arrow.down`/键面 8 个数学符号

### P2-1 应用图标缺失
- [ ] 设计/生成 .icns，`package_app.sh` Info.plist 补 `CFBundleIconFile`（现在 Dock/访达是白纸图标）

### P2-2 菜单栏充实
现状：菜单单薄（用户对照 Apple 计算器截图指出"缺乏真正可用的选项"）。
- [ ] 结合 P0-1 本地化后补齐：关于窗口、设置入口（⌘, 已有 Settings scene，菜单可发现性确认）、
      模式菜单并入 macOS 惯例的"显示"类菜单结构；评估千位分隔符开关等原版 Settings 项的菜单直达
- [ ] 不照抄 Apple 计算器特有功能（RPN/数学笔记等非原版特性，不做）

### P2-3 键盘监听机制风险
`NSEvent.addLocalMonitorForEvents`（`CalculatorChrome.swift:93`）全局截键，MathLive/WKWebView
或文本框聚焦时可能吞键。
- [ ] 评估迁移到 SwiftUI focus 体系或按第一响应者过滤；至少补"文本输入聚焦时放行"守卫并真机验证绘图输入

### P2-4 排版留白校准（次要）
- [ ] 显示区/表达式行/键盘间距与原版 XAML 逐屏比对（用户截图观感：显示区与键盘偏挤）

---

## 豁免清单（已确认可接受）

| 原版特性 | 豁免理由 |
|---|---|
| 按键声效 AuditoryFeedback | Windows 特有反馈通道；macOS 无此惯例 |
| GraphingNumPad 触屏虚拟键盘 | macOS 实体键盘 + MathLive 自带虚拟键盘 |
| EULA/服务协议/隐私声明/反馈 Hub 链接 | 微软法务文书，与本移植无关 |
| 汉堡导航/TitleBar.xaml | 交互 chrome 按 macOS 惯例重制（决策 §二-3）；**注意：现行替代实现有病，按 P1-1 重做，豁免仅指"不做汉堡面板"本身** |
| 微软零售汇率端点 | 明确无授权（决策 §二-2） |
| Windows CompactOverlay 迷你键盘覆盖态 | macOS 置顶惯例 = `NSWindow.level = .floating`，不改布局 |

## 待人工真机确认（无头环境无法验证，保留）

- Liquid Glass 视觉矩阵：Reduce Transparency / Increase Contrast / Reduce Motion / Tinted 玻璃下灰阶层级
- 各模式排版与原版截图逐屏比对；位翻转面板、换算器双栏、绘图两栏
- MathLive 聚焦/输入体验；置顶行为；VoiceOver 全流程
- "历史按钮点击后消失"的精确复现路径（P1-1 重构后应整类消除，重构前如需定位：
  疑与宽度阈值双态 + macOS 26 玻璃按钮 popover 锚定有关）
