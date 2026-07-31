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

## 三、UI 忠实度审查问题清单（2026-07-30）

> 进度：P0-1/P0-2/P0-3/P1-1/P1-2/P1-3/P2-1/P2-2/P2-3/P2-4 **全部已完成**（2026-07-30）。
> 剩余仅"待人工真机确认"项（无头环境无法验证）——见文末清单。

### P0-1 本地化系统性失效（最严重）✅ 已完成（2026-07-30）
现状：60 语言 xcstrings 只服务无障碍标签，可见 UI 是另一套硬编码中文。
- [x] 全部可见文案改走 String Catalog：各 View / `MacCalculatorApp.swift` 菜单 /
      `HistoryMemoryPanel`（"历史记录/内存/尚无历史记录…"）/ `GraphingView`（"函数/线条颜色/图形选项…"）/
      `SettingsView` 等所有硬编码中文串换成 `L10n`/`String(localized:)` 查表，英文系统显示英文
      —— 新增 143 个 `Mac_` 键（en+zh-Hans），复用原版 KeyGraphFeatures/按钮 AutomationProperties 键；
      全 MacApp 源码 0 处硬编码中文串（Python 全量清扫确认）
- [x] `Tools/package_app.sh` 生成的 Info.plist 修正：补 `CFBundleAllowMixedLocalizations`+`CFBundleLocalizations`
      （从 xcstrings 抽取全部语言列表注入），使 AppKit 系统菜单跟随 bundle 语言协商
- [x] 窗口标题硬编码 "计算器"改本地化
- [x] `CommandMenu` 等全部菜单标题与菜单项本地化
- [x] 验证：`xcstringstool compile` 产出全部 60 个 .lproj；en/zh-Hans 键值抽查正确
      （待人工真机确认三处语言一致——见文末清单）

### P0-2 绘图无法拖动平移（功能性破损）✅ 已完成
根因：`WindowConfigurator` 设 `window.isMovableByWindowBackground = true`（`CalcKeyStyles.swift:35`），
画布上的 `DragGesture` 被 AppKit 抢去拖窗口，平移形同虚设。
- [x] 解决拖窗与画布手势冲突：画布 NSHostingView 覆盖 `mouseDownCanMoveWindow=false`，
      挂载期间关闭 `isMovableByWindowBackground`、卸载时恢复（`CalcKeyStyles.swift:51-92`）
- [ ] 顺带核验捏合缩放/滚轮在画布上的可用性（真机——见文末清单）

### P0-3 `logo.playstation` 商标图标 ✅ 已完成
- [x] 已换 `point.3.filled.connected.trianglepath.dotted`（`ProgrammerCalculatorView.swift:131`）

### P1-1 顶栏 chrome 重构（模式切换 + 历史按钮 + 动画）✅ 已完成
现状（`CalculatorChrome.swift` + `ContentView.swift`）已重制为原生 `.toolbar`。
- [x] 改用原生 `.toolbar`：历史按钮常驻工具栏 leading（`sidebar.leading`）、模式菜单在 trailing
- [x] 历史/内存面板改为侧栏伸缩：常驻按钮 toggle + `withAnimation` 开合
- [x] 删除 `.padding(.leading, 76)` 红绿灯硬编码留白
- [x] 保留原版语义：程序员模式无历史；⌃H 开合、⇧⌃D 清除仍可用

### P1-2 绘图 graphView 按钮图标不可读 ✅ 已完成
- [x] 固定用 `arrow.up.left.and.down.right.magnifyingglass`（`GraphingView.swift:718`），
      手动调整态高亮 + tooltip"恢复自动适应视图"

### P1-3 图标语义修正 ✅ 已完成
- [x] 移位改 `chevron.right.2`（`ProgrammerCalculatorView.swift:147`），与换算模式图标不再撞车
- [x] 模式菜单按钮 `circle.grid.3x3` 兜底（`CalculatorChrome.swift:29`）
- [x] 标准模式菜单项对齐 `plus.slash.minus`（`CalculatorChrome.swift:20`）
- [x] 科学模式保留 `function`（`CalculatorChrome.swift:21`）
- [x] 程序员模式 `cpu`（`CalculatorChrome.swift:22`）
- [x] 位翻转键盘段选 `01.square`（`ProgrammerCalculatorView.swift:95`）
- [x] 绘图"函数分析"开关 `list.bullet.rectangle`（`GraphingView.swift:45`）
- [x] 绘图删除方程：保留 `xmark`（与新建/隐藏并排，语义为"移除该行"，评估后保留）
- 合格无需动（复查结论，30 处中 22 处）：`function`/`calendar`/`arrow.left.arrow.right`(换算)/
  `chart.xyaxis.line`/`clock.arrow.circlepath`(**仅空态插画**；工具栏历史按钮归 P1-1 改 `sidebar.leading`)/
  `trash`/`memorychip`/`plus`/`eye`(.slash)/
  `exclamationmark.circle.fill`/`plus.circle`/`minus.circle`/`slider.horizontal.3`/`scope`/
  `square.and.arrow.up`/`gearshape`/`plus.magnifyingglass`/`minus.magnifyingglass`/`angle`/
  `f.cursive`/`arrow.clockwise`/`arrow.up.arrow.down`/键面 8 个数学符号

### P2-1 应用图标缺失 ✅ 已完成
- [x] 程序化生成 macOS squircle 计算器图标（`Tools/make_appicon.swift` → `Tools/appicon/icon_1024.png`），
      `iconutil` 打成 `Tools/AppIcon.icns`；`package_app.sh` 拷入 bundle 并补 `CFBundleIconFile=AppIcon`
      （缺 icns 时告警不阻断）；iconset 中间产物已入 `.gitignore`

### P2-2 菜单栏充实 ✅ 已完成
现状：菜单单薄（用户对照 Apple 计算器截图指出"缺乏真正可用的选项"）。
- [x] 模式菜单并入 macOS 惯例的"显示(View)"菜单（`Mac_Menu_View`，⌘1..⌘6）
- [x] 自定义关于面板（应用菜单 `CommandGroup(.appInfo)` → `orderFrontStandardAboutPanel`），
      附版权 + 第三方许可声明（Giac GPLv3 合规可见性）；设置入口 ⌘, 由 Settings scene 提供
- [x] 不照抄 Apple 计算器特有功能（RPN/数学笔记，不做）
- 千位分隔符开关：**豁免（原版无此功能）**——原版 Settings.xaml 仅有主题三选与关于区，
  无任何分组开关；分组行为来自 OS 区域设置（`LocalizationSettings.h` 读 `LOCALE_SGROUPING`
  经 `EngineResourceProvider` 喂引擎，应用内不可调）。本移植同构：`CalcManagerBridge.mm`
  读 macOS `Locale.groupingSeparator`。补菜单开关=自创设计，违反 1:1 原则，故不做

### P2-3 键盘监听机制风险 ✅ 已完成
`NSEvent.addLocalMonitorForEvents`（`CalculatorChrome.swift`）全局截键，MathLive/WKWebView
或文本框聚焦时可能吞键。
- [x] 补"文本输入聚焦时放行"守卫：`KeyMonitor.isTextInputFocused` 检测第一响应者为
      `NSText`（含 NSTextField field editor / NSTextView）或 WebKit 内容视图时原样返回事件
      （待真机验证绘图 MathLive 输入——见文末清单）

### P2-4 排版留白校准（次要）✅ 已完成
- [x] 依原版 Calculator.xaml 行比（表达式 22* : 结果 72* : 内存 32* : 键盘 308*，结果行 MinHeight 20/42/54/72/108）
      放宽共享 `DisplayArea`：表达式行 18→20、结果文本 `minHeight:56`、纵向留白 6→10
      （Standard/Scientific/Programmer 共用，缓解"显示区偏挤"；最终观感待真机逐屏比对——见文末清单）

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
