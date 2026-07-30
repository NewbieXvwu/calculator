# macOS 移植计划（TODO）

> 目标：将 Windows Calculator 1:1 移植到 macOS 原生技术栈（Swift/SwiftUI），
> 闭源绘图引擎用 Giac（GPLv3，已接受传染）替换。个人实验项目。
> 六种模式（标准/科学/程序员/日期/换算/绘图）的骨架、引擎桥接、Giac 符号分析、
> MathLive 公式编辑器均已跑通并有测试覆盖（`swift test` 33 例 / `swift run engine-tests` 70 例）。
> **本文档现在只跟踪「与微软原版严格对齐」的残差任务**（2026-07-29 全面审计产出）。
> 原则：不偷懒、不妥协、力求完整复刻；确属 Windows 平台特有而 macOS 无对应物的才可豁免，
> 且必须在本文档记录豁免理由。

---

## 一、架构现状（速查）

- SPM 包（根 `Package.swift`，cxx20，macOS 26）。Targets：
  `CalcManagerCore`（原版 C++ 引擎，零改动复用）→ `CalcManagerBridge`（ObjC++，`src/MacBridge`）
  → `MacCalculator`（SwiftUI，`src/MacApp`）；`GiacBridge`（`src/MacGiacBridge`，静态链 `third_party/giac/lib/libgiac.a`，
  由 `Tools/build_giac.sh` 构建）；测试 `calc-smoke` / `engine-tests` / `MacAppTests`。
- `src/MacApp` 分层目录：`App/`（入口 `@main`+AppDelegate）、`Models/`（值类型/枚举）、
  `ViewModels/`（4 个 ObservableObject）、`Views/`（SwiftUI 界面）、`Services/`（CAS/网络/图形算法：
  Giac、Currency、GraphAnalyzer、MarchingSquares）、`Support/`（本地化/剪贴板/无障碍横切设施）；
  `Resources/`（xcstrings）与 `MathLiveAssets/` 位置固定（Package.swift 按路径引用，勿移动）。
- giac/Homebrew 链接路径不再硬编码：Package.swift 顶部经 `Context.packageDirectory` 解析 giac 绝对路径
  （构建不再要求 cwd==仓库根），`GIAC_LIB_DIR` / `HOMEBREW_PREFIX` 可覆盖（CI/Intel `/usr/local`）；
  `build_giac.sh` 同步取 `$HOMEBREW_PREFIX`→`brew --prefix`→`/opt/homebrew`。
- 验证命令：`swift build --product MacCalculator`；`swift test`（逻辑）；`swift run calc-smoke`；`swift run engine-tests`。
  UI 文案/本地化与可分发构建走 xcodebuild：`xcodebuild build -scheme MacCalculator -destination 'platform=macOS,arch=arm64'`、
  `xcodebuild test -scheme MacCalculator-Package -destination 'platform=macOS,arch=arm64'`（此路径才编译 .xcstrings）。
- 排版规格书 = 原版 XAML（`src/Calculator/Views/`）；行为规格书 = 原版 ViewModel（`src/CalcViewModel/`）。

## 二、仍然有效的已定决策

1. **绘图**：CAS 用 Giac/Xcas（GPLv3，静态链接）；渲染自研（SwiftUI Canvas，隐式方程 marching squares）；
   公式编辑器 MathLive（MIT）+ WKWebView 离线打包。二进制发布整体 GPLv3，源码保持 MIT 文件头。
2. **汇率**：主源 fawazahmed0/exchange-api——**优先 Cloudflare Pages 端点
   `https://latest.currency-api.pages.dev/v1/currencies/usd.min.json`（当天数据）**，jsDelivr `@latest` 仅作该源内部备用（滞后约 1 天）；
   兜底 Frankfurter；每日刷新 + 失败回退缓存 + 显示时间戳。**严禁**逆向微软零售端点。
   货币元数据用 `Foundation.Locale`。
3. **UI 原则**：排版 1:1 对照 XAML，不自创设计；皮肤层用 macOS Liquid Glass（玻璃只上控件层，
   相邻玻璃进同一 `GlassEffectContainer`，按键胶囊形，运算符列系统橙，数字最亮灰阶/函数深灰）；
   交互 chrome 按 macOS 惯例（汉堡导航→顶栏圆钮+Menu、快捷键进菜单栏、置顶用 `NSWindow.level`）。
4. **风险备忘**：fawazahmed0 是个人项目曾被下架，缓存+兜底不可省；加密货币汇率必须显示时间戳；
   ObjC++ 文件严禁直接 include 引擎头（Ratpack 全局 `pi` 与 CarbonCore 符号冲突，必须经 `CalcSession` 门面）。

---

## 三、对齐残差任务（按优先级）

### P1-1 键盘快捷键完整复刻（影响日常可用性最大）✅
规格：`src/Calculator/Resources/en-US/Resources.resw` 中全部 `KeyboardShortcutManager.*` 条目（实测 129 项），
含 `Character`、`VirtualKey`、`VirtualKeyShiftChord`、`VirtualKeyControlChord`、`VirtualKeyControlShiftChord` 五类。
- [x] resw 快捷键表已逐条导出对照（129 条），进 `handleKey`/`handleControlChord`/`handleFunctionKey` 分发表
- [x] 标准/科学字符键：`( )`、`@`(√)、`!`(n!)、`|`(Abs)、`[`/`]`(floor/ceil)、`#`(x³) 等 Character 类全部接入
- [x] 科学 VirtualKey 类：三角 s/c/t/o/e/j 及 Shift(反函数)/Ctrl(双曲)/Ctrl+Shift(反双曲) 和弦、
      L/N/G/Y/D/V/M/P/Q/X/R 全套、F3/F4/F5=GRAD/DEG/RAD、F9=±、Delete=CE（原版 Back=⌫、Delete=CE 语义已纠正）
- [x] 程序员：A–F 直接输入（仅 HEX 态，进制门控 `keyboardDigitAllowed`）、F5/F6/F7/F8=HEX/DEC/OCT/BIN、
      F2/F3/F4/F12=字长、位运算字符键 `& | ~ ^ % . < >`（< > 随 shiftMode 联动）
- [x] 记忆/历史和弦：**设计决策——原版 Ctrl 和弦在 macOS 按 ⌃（Control）字面映射**，⌘ 一律放行给菜单栏
      （避开系统 ⌘H 隐藏/⌘Q 退出/⌘M 最小化冲突）：⌃L=MC、⌃R=MR、⌃P=M+、⌃Q=M−、⌃M=MS、
      ⌃H=历史面板（`historyTogglePulse`）、⇧⌃D=清历史
- [x] 换算器负号键 F9（`converterNegateButton`）
- [x] 测试：10 条 ViewModel 级按键分发测试（基础运算/⌘放行/科学字母与和弦/标点/程序员进制与F键/记忆/清历史）
- 豁免与顺延：Insert 复制粘贴备选键无 Mac 等价物（豁免）；`Ctrl+Home/End` graphView 与 plotButton 回车归 P2-5；
  「全部进菜单栏」并入 P3-1 设置/菜单项工作。

### P1-2 CopyPasteManager 完整移植 ✅
规格：`src/CalcViewModel/Common/CopyPasteManager.cpp`（621 行）→ `src/MacApp/CopyPasteManager.swift`。
- [x] 按模式×进制×字长的合法性校验（standard/scientific/programmer hex·dec·oct·bin/converter 全套正则，
  `\A(?:…)\z` 全串匹配；ICU `\s` 不含 `\v`，wspc 显式补 `\x{0B}\x{85}`）
- [x] 表达式粘贴：`onPaste` 先送 CENTR，逐字符映射按键（负号延迟、括号 negateStack、`e±n` 前瞻），
  非法输入整体拒绝并经 `DisplayPasteError()`（CalcSession→bridge 新增）显示引擎 CALC_E_DOMAIN 错误
- [x] 进制前缀/后缀：`0x/0b/0y/0n/0t/0o`、`h/b/u/l/ul/ull`；`TryOperandToULL` 按 stoull 语义含溢出检测
- [x] 最大长度/最大值检查：`maxOperandLengthAndValue` 16 组（hex/dec/oct/bin × qword/dword/word/byte）
- [x] 日期/绘图模式禁粘贴；换算器经 NotificationCenter（`.converterPasteRequested/.converterCopyRequested`）
  转发到 `UnitConverterViewModel.onPaste`（含前导负号 pendingNegate）
- [x] 迁移 `CopyPasteManagerTest.cpp` 全部用例：`CopyPasteManagerTests` 16 项 + `PasteFunctionalTests` 6 项，全绿

### P2-1 程序员模式：移位模式联动键盘 ✅（7aa738b）
规格：`CalculatorProgrammerRadixOperators.xaml:368-483`——RadioButton 选择算术/逻辑/循环/带进位后，
键盘行两键的**标签与命令**随之切换（Lsh/Rsh ↔ Lsh/RshL ↔ RoL/RoR ↔ RoLC/RoRC）。
- [x] ViewModel 增加 shiftMode 状态；移位菜单改为单选组；键盘两键按 shiftMode 渲染
- [x] 测试：四种模式下键盘键分发的命令各一条

### P2-2 程序员模式：位翻转面板排版 1:1 ✅
规格：`CalculatorProgrammerBitFlipPanel.xaml`——固定 64 位、4 行×16 位、每 4 位一组（组间 gutter），
组下方标注该组最低位序号（60/56/…/0），超出字长的位**禁用而非隐藏**（ShouldEnableBit）。
- [x] 按原版分组/行数/序号标注重排；DWORD/WORD/BYTE 通过禁用位对照（待人工真机核对视觉）

### P2-3 趣味单位（whimsical delighter）完整收录 ✅
规格：`UnitConverterDataLoader.cpp` `GetUnits`（`isWhimsical=true` 条目）+ 换算因子表（786 行起）。
实际共 **26 个**（TODO 初稿漏了 Data_FloppyDisk 与 Speed_Turtle，已一并收录）：
- [x] 面积：Hand、Paper、SoccerField、Castle
- [x] 数据：FloppyDisk、CD、DVD
- [x] 能量：Battery、Banana、SliceOfCake
- [x] 长度：Paperclip、Hand、JumboJet
- [x] 功率：LightBulb、Horse、TrainEngine
- [x] 速度：Turtle、Horse、Jet
- [x] 体积：CoffeeCup、Bathtub、SwimmingPool
- [x] 重量：Snowflake、SoccerBall、Elephant、Whale
- [x] 行为对齐：`isWhimsical` → 不进单位下拉框（`selectableUnits`），补充结果按原版
      `CalculateSuggested` 重写（|log10| 量级排序、<100/2位 <1000/1位 其余取整、剔 0、
      非趣味在前、末位只追加第一个趣味结果）
- [x] 名称/缩写取自 zh-CN `UnitName_*`/`UnitAbbreviation_*`（接 String Catalog 归 P3-4）
- [x] 测试：因子抽查 5 例 + 不可选断言 + 补充结果末位恰一个趣味条目（4000kg→1 大象）

### P2-4 汇率主源纠正（一行改动 + 验证）✅（c1ed988）
- [x] 主源改 `https://latest.currency-api.pages.dev/v1/currencies/usd.min.json`，jsDelivr 降为第二优先，Frankfurter 仍兜底
- [x] 联网验证 pages.dev 端点 HTTP 200 存活（三级降级链为同一 fetch 路径，代码级已覆盖）

### P2-5 绘图模式功能对齐（最大残差块）✅
规格目录：`src/Calculator/Views/GraphingCalculator/` + `src/CalcViewModel/GraphingCalculator/`。
- [x] **ActiveTracing 跟踪**：命令面板 scope 开关，光标初始画布中心 +(40,−40)（原版语义）；
      hover/方向键（5pt，⇧=1pt）移动十字光标，多方程按 y 距离（视窗归一）就近吸附，
      彩色圆点 + "(x, y)" 浮层（右缘自动翻转到左侧）
- [x] **图形设置**（`GraphingSettings.xaml`）：x/y Min/Max 四框（min<max 校验 + 错误文案）、
      三角单位弧度/角度/梯度（`GraphTrigMode` 影响渲染求值与 Giac 分析：sin 入参 ×π/180 等，
      asin 出参 ÷scale，双曲不受影响）、线宽 1–4 档（默认 2）+ 重置视图。
      原版无宽高比锁定（初稿笔误），不做
- [x] **方程样式面板**：14 色色板（浅/深色各一套，对照 App.xaml EquationBrush1–14 精确色值）+
      线型实线/虚线/点线（dash 模式 {2,1}/{1}×线宽，对照 GraphControl）
- [x] **变量滑块编辑**：Min/Max/Step 可编辑（默认 −5/5/0.1），min≥max 时另一端顺延
      DefaultMinMaxRange=10（原版 VariableViewModel 语义），± 步进按钮夹取
- [x] **KeyGraphFeatures 全字段**：新增值域（极值+无穷极限+VA 单侧极限启发式）、周期性
      （`period(f,x)`，`+infinity`→非周期）、单调区间（驻点+VA 切分实轴，采样 f′ 符号）、
      斜渐近线（`limit(f/x)`+`limit(f−kx)`）、"因太复杂而无法计算"降级文案；
      Giac 全局态（all_trig_solutions）以 NSLock 串行化防并发污染
- [x] **周期函数零点**：`all_trig_solutions:=1` 取通解，`n_0*pi` 展示为 `n·π`
- [x] **不等式绘制**：`<`/`≤`/`>`/`≥`（含 Unicode ≤≥）编译为 F(x,y) rel 0；~4px 网格采样
      区域 20% 透明着色（同行连续单元合并矩形），边界 marching squares——严格虚线/非严格实线
- [x] **分享/导出**：`NSSharingServicePicker`（2x PNG + 方程列表文本）、右键"复制图形"进剪贴板
- [x] **图表深浅色主题**：画布底色 `.textBackgroundColor`、网格/轴 `.secondary`、曲线色板随
      colorScheme 切换（14 色深浅两套），无硬编码残留
- [x] **plotButton/Enter 提交**（P1-1 顺延项）：MathLive `change` 事件回传 submit，末行非空时
      Enter 追加新输入行；`Ctrl+Home` 和弦与 ⌃0 均触发 graphView 自动适配（隐藏按钮实现）
- [x] 豁免记录：`GraphingNumPad.xaml`（触屏虚拟键盘）——macOS 有实体键盘 + MathLive 虚拟键盘，**豁免**
- [x] 测试：跟踪吸附取值、周期通解（n·π）、不等式编译/区域采样/错误输入、三角单位求值、
      线型 dash 模式、KGF 全字段（值域/单调性/斜渐近线）——`MacAppTests` 79 例全绿

### P3-1 设置/关于页 ✅
规格：`src/Calculator/Views/Settings.xaml`。
- [x] macOS `Settings` scene（⌘,，`SettingsView.swift`）：外观三选浅色/深色/跟随系统
      （radioGroup 对应 ThemeRadioButtons；`NSApp.appearance` 即时生效，UserDefaults
      `AppAppearance` 持久化，启动时 AppDelegate 恢复）
- [x] 关于区：应用名 + 版本号（CFBundleShortVersionString，SPM 直跑显示"开发构建"）、版权行、
      许可声明（二进制 GPLv3 + 上游 MIT + Giac GPLv3 / MathLive MIT / GMP·MPFR LGPL）、
      GitHub 贡献链接（对应 AboutContribute）
- [x] 菜单栏可发现性（P1-1 顺延项）：视图菜单增"历史记录 ⌃H/清除历史记录 ⇧⌃D"、新增"记忆"菜单
      （MS ⌃M/MR ⌃R/M+ ⌃P/M− ⌃Q/MC ⌃L），与键盘和弦共用 VM 入口（`toggleHistoryPanel` 等）；
      数字/运算符按键不进菜单（对齐 Apple 计算器惯例）
- [x] 豁免记录：EULA/微软服务协议/隐私声明/反馈 Hub 链接——微软法务文书，**豁免**，以本项目许可声明替代

### P3-2 表达式 token 点击编辑 ✅
规格：原版 `CalculationResult`/表达式区支持点击历史 token 修改操作数并重算
（`StandardCalculatorViewModel.cpp` 的 `SaveEditedCommand`/`HandleUpdatedOperandData`）。
- [x] 表达式行 token 化为可点击元素（`DisplayArea` 横向滚动 token 行），操作数 token 点击弹出
      Popover 编辑框，提交后引擎命令整体重放（对应 `UpdateOperand` + `Recalculate`）
- [x] 桥接层补命令重放接口：`CalcSession` 保留 `SetExpressionDisplay` 的 tokens/commands 共享指针，
      新增 `IsTokenEditableOperand`/`UpdateOperandAtToken`（字符→命令映射 '.'→PNT、'e'→EXP、
      首位 '-'→ToggleSign、数字→IDC_0+d；重放含度模式/科学模式/F-E、`IsNegative` 注入 SIGN、
      出错恢复原表达式），ObjC 层 `isOperandTokenAt:`/`updateOperandAtToken:...`
- [x] 测试：标准模式折叠操作数编辑（原版标准模式 `1+2+` 折叠为 `3 +`，编辑 3→5 得 8）、
      科学模式完整表达式中间操作数编辑（1+2×4 编辑 2→5 得 21）、等号后编辑（含负数小数 `-7.5`）、
      非法输入/越界拒绝——共 5 个新用例，`swift test` 83 项全绿

### P3-3 无障碍播报（Narrator → VoiceOver）✅
规格：`src/CalcViewModel/Common/Automation/NarratorAnnouncement.cpp` 全部事件。
- [x] `NSAccessibility.post(.announcementRequested)` 等价封装：新增 `AccessibilityAnnouncer`
      （high↔ImportantMostRecent、medium↔MostRecent 优先级映射，向 mainWindow/NSApp 投递）
- [x] 事件逐条对齐：显示值更新（等号/清除/退格 → DisplayUpdated；二元运算符 OnBinaryOperatorReceived；
      MaxDigitsReached；NoParenthesisAdded；OpenParenthesisCountChanged）、
      内存变更（MS 存储 / M+ M− MemoryItemChanged / MC 清除）、历史（清除/删项/面板开合）、
      进制切换（HEX/DEC/OCT/BIN）、字长切换、角度切换（度/弧度/百分度）、移位类型（BitShiftRadioButtonContent）、
      错误提示（isError 文本）、2nd 开关（ShiftButton）、复制（DisplayCopied）、
      模式切换（含 GraphModeChanged）、置顶（AlwaysOnTop）、设置页打开（SettingsPageOpened）、
      单位换算（CategoryNameChanged / UpdateCurrencyRates）、
      绘图（FunctionRemoved / GraphViewBestFitChanged / 跟踪值坐标）
- [x] 豁免记录：真机 VoiceOver 人工验证——需真实设备与人工听感，本环境无法自动化，**留待人工**
      （代码路径已全部接线，等价原版事件全覆盖）

### P3-4 本地化接线
现状：60 locale 的 xcstrings 是唯一翻译真相源（`src/MacApp/Resources/Localizable.xcstrings` +
`CEngineStrings.xcstrings`，均从原版 resw 转换）。
- [x] 本地化管线：改用 xcodebuild 构建——它经 `xcstringstool` 原生把 `.xcstrings` 编译成全部
      **60 语言**的 `.lproj/Localizable.strings` 进 bundle（已验证 bundle 内 60 个 `.lproj`）。
      `Package.swift` 保留 `defaultLocalization: "en"`；`L10n`（`Localization.swift`）经 `Bundle.module` 查表。
      **无手写回退、无双真相源**：删除了 `scripts/export_strings.py` 与手动导出的 `{en,zh-Hans}.lproj`；
      查不到的键原样返回键名（暴露缺失，不静默吞中文）。纯 `swift build` 不编译 catalog，文案退化为键名，
      故 UI 文案验证一律走 xcodebuild。
- [x] UI 串换成 resw 键查表：三态键盘（标准/科学/程序员）所有按钮 a11yLabel 走 `L10n.button("<id>")`（单参数、无回退），
      键名沿用原版 resw（`plusButton`/`equalButton`/`num0Button`/`shiftButton`/`aButton`…
      `.[using:Windows.UI.Xaml.Automation]AutomationProperties.Name`）
- [x] 数字格式（小数点/千分位）全走 `Locale`：换算器 `UnitConverterViewModel.localizedDisplay`
      按 `Locale.current` 的 `decimalSeparator`/`groupingSeparator` 分组并本地化小数点，
      逆向 `normalizeForInput` 还原为内部 "." 制；主计算器各模式经引擎 `NSLocale.currentLocale` 分隔符
- [x] 验证：`LocalizationTests` 从编译后的 `.lproj` 断言 en/zh-Hans 双语解析（`swift test` 下 catalog 未编译时
      `XCTSkipIf` 跳过，`xcodebuild test` 下真实解析 "Clear"/"清除" 并通过）+
      `testConverterDisplayUsesLocaleSeparators` 校验分组/小数点（`swift test` 与 `xcodebuild test` 均 90 测试全绿）；
      切系统语言真机抽查留待人工（无头环境无法验证）

### P3-5 窗口行为补齐
- [x] 退出时记忆当前模式 + 各模式窗口尺寸，启动恢复（原版 ApplicationDataContainer 语义）：
      `CalculatorMode.persistenceKey`/`init(persistenceKey:)` + `UserDefaults` 键 `LastCalculatorMode`，
      `setCalculatorType` 写入、VM `init` 读取恢复；各模式窗口尺寸由 `.windowResizability(.contentSize)`
      随内容确定（每模式内容固有尺寸唯一，恢复模式即恢复尺寸，无需另存任意用户尺寸）；
      `testModePersistenceRoundTrip` 覆盖
- [x] 置顶时切换紧凑布局——**豁免为「仅置顶不改布局」**：原版 CompactOverlay（迷你标准键盘 + 记忆恢复尺寸）
      是 Windows 特有的 ApplicationView 覆盖态；macOS 惯例的置顶是提升 `NSWindow.level = .floating`
      （已实现于 `MacCalculatorApp` 窗口置顶命令），不改变键盘布局。结论：不移植迷你键盘覆盖态
- [x] 历史条数上限对照原版：引擎 `CalculatorManager.cpp` `MAX_HISTORY_ITEMS=20`，
      std/sci 各持有一个 `CalculatorHistory(20)`、程序员无历史（`nullptr`），与原版
      `m_maxHistorySize`=20/模式完全一致，无需改动（已核实）

### P3-6 响应式布局
规格：`CalculatorStandardOperators.xaml:52-170` 等的 Large/Medium/Small/Tiny 四档字号 + 窄窗隐藏功能行。
- [x] SwiftUI 按窗口尺寸做等价分档：`StandardCalculatorView` 键盘用 `GeometryReader` 读可用高度，
      `LayoutTier.forKeypadHeight` 分三档（大/常规/紧凑）调数字/运算符/函数/清除键字号；
      紧凑档（高度 < 260）触发 HideStandardFunctions——隐藏「函数行 ¹⁄ₓ x² ²√x + 百分号」、
      `CE C ⌫ ÷` 顶起并保留全部运算符（对应原版 R1 折叠 + PercentButton 隐藏）；
      标准模式最小窗高降到 360 使紧凑档可触发（默认 500 仍是常规档）；
      `LayoutTierTests` 覆盖阈值与字号单调性（真机逐档视觉比对留待人工）

### 豁免清单（我提出的建议，待用户确认；已确认可接受）
| 原版特性 | 豁免理由 |
|---|---|
| 按键声效 AuditoryFeedback | Windows 特有反馈通道；macOS 无此惯例 |
| GraphingNumPad 触屏虚拟键盘 | macOS 实体键盘 + MathLive 自带虚拟键盘 |
| EULA/服务协议/隐私声明/反馈 Hub 链接 | 微软法务文书，与本移植无关 |
| 汉堡导航/TitleBar.xaml | 交互 chrome 按 macOS 惯例重制（决策 §二-3） |
| 微软零售汇率端点 | 明确无授权（决策 §二-2） |

### 待人工真机确认（无头环境无法验证，保留）
- Liquid Glass 视觉矩阵：Reduce Transparency / Increase Contrast / Reduce Motion / Tinted 玻璃下灰阶层级
- 各模式排版与原版截图逐屏比对；位翻转面板、换算器双栏、绘图两栏
- MathLive 聚焦/输入体验；置顶行为；VoiceOver 全流程
