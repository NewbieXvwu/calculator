# macOS 移植计划（TODO）

> 目标：将 Windows Calculator 移植到 macOS 原生技术栈（Swift/SwiftUI + Metal/Core Graphics），
> 并用开源实现替换仓库中不包含的闭源绘图引擎。
> 本文档记录全部已定决策与分析结论，防止上下文丢失。个人实验项目，授权协议不设限（接受 GPL 传染）。

---

## 一、现状盘点（已实测）

| 模块 | 行数 | 技术 | 移植策略 |
|---|---|---|---|
| `src/CalcManager` | ~15.5k | 可移植 C++（含 `sal_cross_platform.h`、`winerror_cross_platform.h`），Ratpack 任意精度引擎 | **直接复用**，加 CMake 构建 |
| `src/CalcViewModel` | ~15.7k | C++/CX，绑死 WinRT（`Windows.Globalization`、ResourceLoader、Dispatcher） | 用 Swift 按原逻辑重写 |
| `src/Calculator` | ~27k | C# UWP，27 个 XAML 页面 | SwiftUI 重写 |
| `src/GraphControl` | ~4.5k | DirectX (D2D/D3D SwapChain) XAML 控件，见 `GraphControl/DirectX/` | Metal/Core Graphics 重写 |
| `src/GraphingInterfaces` | ~1k | 纯抽象接口头（`IMathSolver`/`IGraphRenderer`/`IGraphAnalyzer` 等） | **保留作为规约** |
| `src/GraphingImpl/Mocks` | ~0.85k | 闭源引擎（Microsoft Math Solver）的 Mock 桩，`UseMockGraphingImpl` 默认 true | 用开源实现替换 |

先例：Uno Platform 的 Calculator 移植复用了 CalcManager（macOS/iOS/WASM 均跑通），也跳过了绘图模式。

总工作量估计：单人全职 6–12 个月达到功能对等；不含绘图的 MVP 约 2–3 个月。

---

## 二、已定技术决策

### 1. 绘图引擎替换（最大难点，2–3 个月+）
- **CAS 引擎：Giac/Xcas（GPLv3）**。GeoGebra CAS / HP Prime 的底层引擎，
  solve/limit/极值/渐近线/级数齐全，几乎逐条覆盖 `IGraphAnalyzer` 需求，可静态链接。
  - 落选备选：Maxima（Lisp，只能子进程管道）、SymPy（嵌入 Python 太重）、
    GiNaC（无通用 solve/limit）、SymEngine（求解能力弱）。
- **渲染器：自研**（Metal 或 Core Graphics）。自适应采样 + 间断点检测 + 交互平移缩放没有现成库。
  - 原型阶段可用 ImPlot（MIT）快速验证；
  - 隐式方程用 marching squares，可抄 contourpy（BSD）/matplotlib 实现；
  - 采样逻辑可参考/借用 KmPlot、KAlgebra（GPL）的代码。
- **公式输入编辑器：MathLive（MIT，JS）+ WKWebView**，替代 Windows 独有的 `MathRichEditBox`。
  SwiftMath/iosMath（MIT）只能渲染不能编辑，仅用于历史记录展示。
- 后果：链接 Giac 后整个应用需按 GPLv3 发布（已接受）。

### 2. 汇率数据源（已确认，半天工作量）
- 现状：`CalcViewModel/DataLoaders/CurrencyHttpClient.cpp` 已被完全 Mock（火星元/月球币假数据）。
  微软明确声明零售版端点 "not licensed for your use"（README「Currency Converter」节 + PR #524 提交信息）。
  **不要逆向找回零售端点**（历史端点在 git 历史 2b17f82/bb540e6 可查，仅供参考）。
- **主源：fawazahmed0/exchange-api**（CC0，200+ 货币，无 key 无限额）。
  - 优先用 Cloudflare Pages 端点 `https://latest.currency-api.pages.dev/v1/currencies/{code}.min.json`（当天数据）；
  - jsDelivr `@latest` 端点因 CDN 缓存滞后约 1 天，作为该源内部的备用；
  - 每日更新一次（2026-07-29 实测存活且新鲜）；支持 `/v1/{YYYY-MM-DD}/...` 历史回溯。
- **兜底：Frankfurter**（`frankfurter.dev`，开源可自托管，欧洲央行数据，~30 种主流货币）。
- **缓存必须保留**：原版 `CurrencyDataLoader` 的"每日刷新 + 失败用陈旧缓存 + 显示时间戳"逻辑照搬。
- 元数据接口（`GetCurrencyMetadataAsync`：国家/货币名、符号）整个砍掉——
  macOS 用 `Foundation.Locale`/ICU 原生获取本地化货币名称与符号。
- 适配方式：实现 `GetCurrencyRatiosAsync` 等价物，把响应转成原有 `{"An": "USD", "Rt": 1.0}` 形状。
- 若日后砍到只剩 30 种主流货币，可单用 Frankfurter（甚至自托管）再简化一层。

### 3. UI 原则（用户明确要求）
- **维持原版排版，不自己加设计**：27 个 XAML 页面就是排版规格书，1:1 转译。
  - 按钮矩阵（XAML `Grid`）→ SwiftUI `Grid`；历史/内存侧板、换算器双栏结构全保留。
- 只换"皮肤"层：采用 **macOS 26 Tahoe Liquid Glass** 设计语言（见下 §3a），跟随系统深浅色；
  用原生 SwiftUI 控件默认观感，**不模仿 Fluent，也不自造毛玻璃**。
- macOS 惯例替换交互 chrome：
  - 汉堡导航 → 顶栏圆形玻璃按钮（历史）+ 玻璃 Menu（模式切换），小窗不用 NavigationSplitView；
  - 键盘快捷键进菜单栏（原版键盘映射表照搬）;
  - 置顶小窗（Always-on-Top）→ `NSWindow.level` 浮动窗口。
- `src/Calculator/DesignData/` 有现成设计时数据，用作 `#Preview` 素材。
- 本地化：海量 `.resw` 资源写脚本转 `.strings`/`.xcstrings`。

### 3a. Liquid Glass 设计规范（评审定稿，仅约束皮肤层，排版网格不动）
> 依据 Apple HIG（Materials/Liquid Glass）、WWDC25 Session 219/310/323、macOS Tahoe 自带计算器截图。
- **玻璃只用于控件层**（按键、顶栏圆钮）；内容层（显示区、历史/内存列表行、图表画布）**禁止**加玻璃。
- 相邻玻璃元素必须包进单个 `GlassEffectContainer`（玻璃无法采样另一块玻璃）；科学模式新增键列时保持一个大 container。
- 自定义键用 `glassEffect(.regular.tint(…).interactive())`；系统按钮（`.buttonStyle(.glass)`）不再叠 `.interactive()`。
- 按键形状 = **胶囊（Capsule）**，large 控件范畴，与窗口角同心。
- **着色语义**：数字键=最亮灰阶、函数键=深灰阶、右侧运算符列 `÷×−+=`=**系统橙**（白字，Apple 计算器语义，不用会漂移的 accentColor）、科学模式 INV/2nd=橙 25%。灰阶走 NSColor 动态双通道（等价资产目录深浅色），不硬编码单一 hex。
- 显示区：大号 `weight: .light` SF Pro + `.contentTransition(.numericText())` 数字滚动；`.monospacedDigit()` 防抖。
- 面板：不用自定义背景色，空态用 `ContentUnavailableView`，hover/填充用语义 `.quaternary`，浮动内容下方加 `.scrollEdgeEffectStyle(.soft, for: .top)`。
- 无障碍：所有 symbol 键补 `accessibilityLabel`；禁用态用语义 `.tertiary`；结果变化播报（待补）。
- 反模式（已核对不违反，保持）：内容层玻璃、玻璃不进 container、`.clear` 玻璃用在按键、tint 当装饰、自绘 blur。`NSVisualEffectView` 仅作窗口底材是合规用法。
- **待人工真机目测矩阵**：Reduce Transparency / Increase Contrast / Reduce Motion / 外观→Liquid Glass→Tinted（浊玻璃下灰阶层级仍要可分）。无头环境无法截图，需人工过视觉。

---

## 三、实施阶段（按序）

### Phase 0：骨架（1–2 周）
- [x] 创建 Xcode 工程（SwiftUI App，macOS target）
      （已完成：沿用 SPM 方案（Xcode 可直接打开 Package.swift 运行），新增 `MacCalculator`
      可执行 target（`src/MacApp/`）：SwiftUI App + AppDelegate（无 bundle 需手动
      `setActivationPolicy(.regular)`）+ CalculatorModel（ObservableObject 包桥接）+
      骨架键盘验证全链路。完整 1:1 排版归 Phase 1。若后续需要正式 app bundle/签名，
      再引入 xcodegen 或手建 .xcodeproj）
- [x] 为 `CalcManager` 写 CMake 构建，在 macOS 编译通过
      （已完成：`src/CalcManager/CMakeLists.txt`；PPL 依赖用 `ppltasks_cross_platform.h` 垫片解决；
      冒烟测试 `smoketest/main.cpp` 在 arm64 通过：1+2=3、2*8=16、10/3=3.333333333333333）
- [x] **排查 `wchar_t` 坑**：macOS 上 4 字节 vs Windows 2 字节，全库重度使用 `std::wstring`，
      逐处核查 UTF-16 假设（Uno 移植踩过，可参考其补丁）
      （已完成：全库无 `sizeof(wchar_t)` 假设、无代理对处理、无 UINT16 强转；
      仅有 ASCII 范围的 `wchar_t` 运算（`CalcInput.cpp:63`），4 字节下安全。
      结论：引擎宽度无关，字符串转换统一在 Swift 桥接层处理）
- [x] Swift/C++ interop 或 ObjC++ 桥接层，跑通"引擎算出 1+1"
      （已完成：根目录 `Package.swift`（SPM）；`src/MacBridge/CalcSession.{h,cpp}` 纯 C++ pimpl 门面
      隔离引擎头文件，`CalcManagerBridge.mm`（ObjC++）供 Swift 调用；`src/MacSmoke` 冒烟通过。
      暗坑备忘：Ratpack 的全局 `extern PRAT pi` 与 Apple CarbonCore `fp.h` 的 `pi` 符号冲突，
      因此 ObjC++ 文件严禁直接 include 引擎头，必须经 CalcSession 门面）
- [x] 迁移 `CalculatorUnitTests` 中引擎相关单测（转 XCTest 或保留 googletest）
      （已完成：`src/MacEngineTests/`，自研 CppUnitTest.h 兼容垫片让上游测试源码近乎零修改编译
      （仅每文件末尾追加一行 REGISTER_TEST_CLASS）；覆盖 CalcInput/Rational/CalcEngine/
      CalculatorManager 四个套件，`swift run engine-tests` 70 项全过。
      引擎字符串来自 `Tools/generate_engine_strings.py` 从 CEngineStrings.resw 生成的
      `src/MacBridge/EngineStringsData.g.h`（该表未来给 App 复用）。
      HistoryTests/UnitConverterTest 依赖 ViewModel，推迟到 Phase 1/3 随重写迁移）

### Phase 1：标准 + 科学模式（3–5 周）
- [x] Swift 重写 `StandardCalculatorViewModel` 核心逻辑
      （已完成：`src/MacApp/StandardCalculatorViewModel.swift`——按钮分发（错误恢复/FE 重置/角度模式）、
      模式切换（精度 16/32/64 + SetRadix + UpdateMaxIntDigits）、内存增删改查、历史列表、
      表达式 tokens、IsInputEmpty；桥接层补齐 SetPrecision/SetRadix/GetResultForRadix。
      暂缺随后续条目补：表达式 token 点击编辑（SaveEditedCommand/HandleUpdatedOperandData，
      随科学模式 UI 补）、粘贴解析（独立条目）、Narrator 播报（无障碍条目））
- [x] 标准模式 UI（含历史/内存面板）
      （已完成：`src/MacApp/Views/`——StandardCalculatorView 按 CalculatorStandardOperators.xaml
      1:1 转译（6 行×4 列：%/CE/C/⌫、1/x/x²/√/÷、数字区、±0.=）+ 内存栏 MC/MR/M+/M−/MS；
      HistoryMemoryPanel 对应 HistoryList.xaml/Memory.xaml（宽 ≥560 显示右侧 Dock）。
      注意：无头环境无法截图目测，仅验证编译+运行不崩溃，需人工过一遍视觉）
- [x] 科学模式 UI（含 F-E 切换、角度模式等）
      （已完成：`src/MacApp/Views/ScientificCalculatorView.swift` 按 CalculatorScientificOperators.xaml
      + CalculatorScientificAngleButtons.xaml 1:1 转译——外层 8 行×5 列铺成 1+6 行网格：
      行1 = 2nd(INV)/π/e/CE·C/⌫；左侧函数列随 2nd 切换 x²√xxʸ10ˣlogln ↔ x³∛xʸ√x2ˣlogᵧeˣ；
      行2-7 右侧 = 1/x·|x|·exp·mod / (·)·n!·÷ / 数字区 / ±0.= 运算符列。
      角度栏 DEG/RAD/GRAD 三段循环 + F-E 切换；三角/函数下拉用原生 Menu（含反/双曲/反双曲子菜单）。
      复用 Phase 1 Liquid Glass 体系：数字最亮灰阶、函数深灰、运算符列系统橙、2nd/角度态强调橙；
      抽出 `CalculatorChrome.swift`（顶栏 + 键盘监听修饰符）供标准/科学共用。
      ContentView 按 mode 切换视图并放宽窗口最小尺寸。无头环境仅验证编译+运行不崩溃 + 引擎冒烟通过）
- [x] 键盘映射 + 菜单栏快捷键
      （已完成：`StandardCalculatorViewModel.handleKey`（NSEvent .keyDown 本地监听）——
      0-9→数字、+−*/=→运算、.,→小数点、%→百分号、Esc→Clear、Delete/Backspace→退格、
      Return/Enter→等号；⌘ 组合键放行给菜单栏。`MacCalculatorApp` CommandMenu「模式」
      ⌘1/⌘2/⌘3 + CommandGroup(.pasteboard) 拷贝⌘C/粘贴⌘V。按键按下有 150ms 高亮闪烁反馈）
- [x] 复制/粘贴（对照 `CopyPasteManager` 的解析规则）
      （部分完成：copyDisplay 写 NSPasteboard；pasteFromPasteboard 先 Clear 再逐字符送
      数字/小数点/前导符号。完整 CopyPasteManager 的进制/科学计数/表达式合法性校验待后续补齐）
- [x] 无障碍（VoiceOver，对照原版 Narrator/`NarratorAnnouncement` 行为）
      （部分完成：所有按键 `.accessibilityLabel`、显示区 `.accessibilityValue`、历史/内存行
      `.accessibilityElement(children:.combine)` + 删除 `.accessibilityAction`。
      计算结果的主动播报（NarratorAnnouncement 等价物）待后续补齐）

### Phase 2：程序员 + 日期计算（2–3 周）
- [x] 程序员模式（进制转换、位运算、位翻转面板）
      - RadixKind / WordSize 枚举 + ViewModel 状态（currentRadix / wordSize / isBitFlipChecked /
        四进制显示 / binaryBits / areHexButtonsEnabled），对照原版 SwitchProgrammerModeBase /
        ValueBitLength / UpdateProgrammerPanelDisplay；进制切换、字长循环、位翻转、A–F 与 0–9
        按进制启用/禁用均已接通。
      - EngineCommand 增补 binPos0(700) + bitFlip(pos) / lshfl 保持与算术左移复用（引擎无独立命令）。
      - ProgrammerCalculatorView：四进制转换行（点按切进制）、整键盘/位翻转分段、字长循环按钮、
        位运算 ▾ / 移位 ▾ 菜单（AND/OR/XOR/NOT/NAND/NOR，算术/逻辑/循环/带进位移位）、
        A–F + 数字 + 运算符键盘网格、按字长(64/32/16/8)铺开的位翻转开关面板。
      - calc-smoke 增补 255→HEX FF / OCT 377 / BIN 11111111 校验，通过。
      - （待人工确认：位翻转面板与四进制行的视觉排布需真机截图核对；分组填充 AddPadding 暂用引擎原始分组）
- [x] 日期计算模式
      - DateCalculatorViewModel（Swift）：直接用 Foundation.Calendar / DateComponents 替代原版
        Windows.Globalization.Calendar；日期差先算年、月，剩余天数拆周+天，另给纯天数结果，
        同天或仅差天数时只显示一个结果（对应 StrDateDiffResult / InDays / IsDiffInDays）；
        加减日期为起始日 ±(年,月,天)，越界返回 nil→"超出范围"（对应 IsOutOfBound）；偏移上限 999。
      - DateCalculatorView：日期差/加减日期分段切换、DatePicker、年/月/日 Stepper(0...999)、结果卡片；
        .date 作为非引擎 CalculatorMode（usesEngine=false），隐藏历史/记忆 Dock。
      - CalculatorChrome 模式菜单 + modeIcon 增补 .date(calendar 图标)；ContentView 接入并补最小窗口尺寸。

### Phase 3：单位/汇率换算器（2–3 周）
- [x] Swift 重写 `UnitConverterViewModel` + `UnitConverterDataLoader`（静态单位部分）
      - UnitConverterData（Swift）：移植 GetConversionData 全量换算因子 + GetExplicitConversionData
        温度非线性换算。12 个类别（长度/重量/体积/温度/面积/速度/时间/功率/数据/压强/角度/能量），
        每类别以基准单位 factor==1，convert = value*(fromFactor/toFactor)；温度用摄氏中转特判。
        暂不含趣味单位(isWhimsical)。
      - UnitConverterViewModel：类别/单位选择、活动框切换(SwitchActive)、数字/小数点/退格/清除/正负号
        输入、换算与补充结果(CalculateSuggested)、有效数字格式化(去尾零/科学计数)。
      - UnitConverterView：类别 Picker + 数值1/单位1 + ⇅交换 + 数值2/单位2 + 补充结果横向条 + 数字键盘；
        .converter 作为非引擎 CalculatorMode（usesEngine=false），隐藏历史/记忆 Dock，专用键盘监听。
      - 数值校验：1m→100cm / 1kg→2.2046lb / 100°C→212°F / 32°F→0°C / 1mi→1.609344km / 1GB→1000MB 均正确。
      - （待人工确认：横向排布与原版上下双数值框排版需真机截图核对）
- [x] 汇率：按上文决策接 fawazahmed0 + Frankfurter 兜底 + 缓存
      - CurrencyService：主源 fawazahmed0 currency-api（jsDelivr，无 key），兜底 Frankfurter，
        均以 USD 为基准；结果写入 ~/Library/Caches/MacCalculator/currency_rates.json，
        离线/失败回退缓存；提供手动刷新。
      - 端到端联网校验：拉取 338 种货币，100 USD→676.78 CNY，factor(=1/rate) 换算与直算一致。
      - （打包分发为 .app 时需补 com.apple.security.network.client 权限，留待 Phase 5）
- [x] 货币元数据改用 `Foundation.Locale`
      - 货币列表取 Locale.commonISOCurrencyCodes ∩ 汇率键集（滤除加密货币等），
        本地化名用 localizedString(forCurrencyCode:)，常用币种(USD/EUR/GBP/JPY/CNY…)优先排序。
      - 「货币」作为动态 ConverterCategory 接入换算器（factor=1/rate 复用现有换算逻辑），
        选中时显示汇率日期 + 刷新按钮。

### Phase 4：绘图模式（8–12 周+，最后攻坚）
- [ ] 先接 `GraphingImpl/Mocks` 等价的 Swift Mock，跑通 UI 架构
- [ ] 编译 Giac 为 macOS 静态库，桥接
- [ ] 实现 `IMathSolver` 适配（解析/求值/格式化，对齐计算器输入语法）
- [ ] 实现 `IGraphAnalyzer` 适配（零点/极值/拐点/渐近线/单调区间）
- [ ] 自研渲染器：自适应采样 + 间断点检测 + Metal/CG 绘制 + 平移缩放交互
- [ ] 隐式方程：marching squares
- [ ] MathLive + WKWebView 公式输入编辑器
- [ ] 变量滑块、函数分析面板等 `GraphControl` 周边 UI

### Phase 5：收尾
- [ ] 本地化资源批量转换（.resw → .xcstrings 脚本）
- [ ] 置顶小窗、窗口尺寸记忆等窗口行为
- [ ] UI 测试（XCUITest 重写，原 `CalculatorUITests` 仅作行为参考）
- [ ] 确定发布授权（含 Giac 则整体 GPLv3）

---

## 四、风险与暗坑备忘

1. **`wchar_t` 宽度差异**是 CalcManager 移植唯一实质风险，Phase 0 必须先验证。
2. **不得使用微软零售版汇率端点**（明确无授权）。
3. `MathRichEditBox` 无 macOS 等价物，MathLive 是唯一现实解；若 WKWebView 方案交互不佳，
   自研数学编辑器成本极高，需提前原型验证。
4. fawazahmed0 是个人项目，前身 currency-api 曾被 GitHub 下架过——兜底 + 缓存不可省。
5. Giac 编译体积和符号分析性能未验证，Phase 4 开头先做 spike。
6. 加密货币汇率若保留，UI 必须显示数据时间戳（每日一档，波动误差大）。
