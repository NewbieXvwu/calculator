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
- 验证命令：`swift build --product MacCalculator`；`swift test`；`swift run calc-smoke`；`swift run engine-tests`。
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

### P1-1 键盘快捷键完整复刻（影响日常可用性最大）
现状：`StandardCalculatorViewModel.handleKey`（`src/MacApp/StandardCalculatorViewModel.swift:506`）只接了
数字/四则/`=`/`%`/小数点/Esc/⌫/回车，**连 `(` `)` 都没接**。
规格：`src/Calculator/Resources/en-US/Resources.resw` 中全部 `KeyboardShortcutManager.*` 条目（100+ 项），
含 `Character`、`VirtualKey`、`VirtualKeyShiftChord`、`VirtualKeyControlChord`、`VirtualKeyControlShiftChord` 五类。
- [ ] 写脚本或手工把 resw 快捷键表逐条导出成对照清单（**以 resw 键值为准，禁止凭记忆猜按键**），进代码常量表
- [ ] 标准/科学字符键：`( )`、`@`(√)、`!`(n!)、`|`(Abs) 等 Character 类全部接入
- [ ] 科学 VirtualKey 类：三角 sin/cos/tan/sec/csc/cot 及 Shift(反函数)/Ctrl(双曲)/Ctrl+Shift(反双曲) 和弦、
      对数/幂 (`logBase10Button`/`logBaseEButton`/`powerButton`/`cubeRootButton`…)、`F-E`、DEG/RAD/GRAD 切换、
      π/e (`pButton`/Shift 和弦)、F9=±、DMS/Degrees
- [ ] 程序员：A–F 直接输入（仅 HEX 态）、F5/F6/F7/F8=HEX/DEC/OCT/BIN、位运算字符键（`&` `|` `~` `^` `<` `>` 类）、
      字长循环、位翻转切换
- [ ] 记忆/历史和弦（Windows Ctrl→macOS ⌘）：⌘L=MC、⌘R=MR、⌘P=M+、⌘Q=M−、⌘M=MS、⇧⌘P=M 面板、
      ⌘H=历史面板、⇧⌘D=清历史（⌘H 与 macOS「隐藏窗口」冲突时改 ⌥⌘H 并记录）
- [ ] 换算器负号键（`converterNegateButton`）
- [ ] 全部进菜单栏（macOS 惯例：快捷键必须可发现），按模式分组启用/禁用
- [ ] 测试：每类和弦至少一条 ViewModel 级按键分发测试

### P1-2 CopyPasteManager 完整移植
现状：`pasteFromPasteboard` 只识别数字/小数点/前导负号（`StandardCalculatorViewModel.swift:565`）。
规格：`src/CalcViewModel/Common/CopyPasteManager.cpp`（621 行）。
- [ ] 按模式×进制×字长的合法性校验（正则表 `c_programmerHexPatterns` 等全套）
- [ ] 表达式粘贴：运算符/括号/科学计数 `e±n` 逐 token 送引擎；非法输入整体拒绝（对应原版行为）而非静默丢字符
- [ ] 进制前缀：`0x`/`0b`、程序员模式按当前进制解析；字长溢出检查（`TryOperandToULL`/位宽上限）
- [ ] 最大长度/最大位数检查（`MaxOperandLengthForViewMode` 等价物）
- [ ] 日期/换算/绘图模式的粘贴行为对照（原版禁用或按数字处理）
- [ ] 迁移 `src/CalculatorUnitTests/CopyPasteManagerTest.cpp` 全部用例到 `MacAppTests`

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

### P2-5 绘图模式功能对齐（最大残差块）
规格目录：`src/Calculator/Views/GraphingCalculator/` + `src/CalcViewModel/GraphingCalculator/`。
- [ ] **ActiveTracing 跟踪**（`GraphingCalculator.xaml:612` + `ActiveTracing` 逻辑）：
      开关后光标/拖动沿曲线吸附，浮层显示 (x, y)；键盘方向键微移；多方程时就近吸附
- [ ] **图形设置**（`GraphingSettings.xaml`）：x/y 范围（Min/Max 四框手动输入，联动画布）、
      三角单位弧度/角度/梯度（影响 sin(x) 周期渲染与分析）、宽高比锁定
- [ ] **方程样式面板**（`EquationStylePanelControl.xaml`）：14 色色板 + 线型（实线/虚线/点线）逐方程可改；
      当前固定 8 色轮换不可改，需替换
- [ ] **变量滑块编辑**（`EquationInputArea.xaml` 变量区）：每个变量可设 Min/Max/Step（当前硬编码 −10…10，
      `GraphingView.swift:103`），加减步进按钮
- [ ] **KeyGraphFeatures 全字段**（`EquationViewModel.cpp` KeyGraphFeaturesInfo）：现有定义域/奇偶/零点/
      y 截距/极值/拐点/垂直渐近线/水平渐近线，**缺**：值域(Range)、周期性(Periodicity)、单调区间(Monotonicity)、
      斜渐近线(ObliqueAsymptotes)、以及"太复杂无法计算"(TooComplexFeatures) 的降级提示文案。
      Giac 对应物：值域 `range`/极值推导、周期 `period(f,x)`、单调性由驻点分段 + 一阶导符号、斜渐近线 `limit(f/x)`+`limit(f-kx)`
- [ ] **周期函数零点**：当前 solve 只给主解（如 sin 只报 x=0），对照原版给通解形式（`x = k·π` 类），
      Giac 侧开 `solve` 的周期解模式或后处理
- [ ] **不等式绘制**：`y < f(x)`/`≤`/`>`/`≥` 区域阴影 + 虚线/实线边界（原版由引擎支持，我们在 Canvas 层实现）
- [ ] **分享/导出**：原版 Share contract（图 + 方程列表）→ macOS `NSSharingServicePicker` + 导出 PNG 到剪贴板/文件
- [ ] **图表深浅色主题**（GraphingTheme：轴/网格/背景色跟随系统外观，当前部分硬编码需核查）
- [ ] 豁免记录：`GraphingNumPad.xaml`（触屏虚拟键盘）——macOS 有实体键盘 + MathLive 虚拟键盘，**豁免**
- [ ] 测试：跟踪吸附取值、周期通解、不等式区域采样、样式持久化

### P3-1 设置/关于页（当前完全缺失）
规格：`src/Calculator/Views/Settings.xaml`。
- [ ] macOS `Settings` scene（⌘,）：外观三选——浅色/深色/跟随系统（`NSApp.appearance`，UserDefaults 持久化；
      对应 ThemeRadioButtons）
- [ ] 关于区：应用名 + 版本号（对应 AboutBuildVersion）、版权行、许可声明
      （本移植二进制 GPLv3 + 上游 MIT + 第三方：Giac GPLv3 / MathLive MIT / GMP·MPFR LGPL）、
      GitHub 贡献链接（对应 AboutContribute）
- [ ] 豁免记录：EULA/微软服务协议/隐私声明/反馈 Hub 链接——微软法务文书，**豁免**，以本项目许可声明替代

### P3-2 表达式 token 点击编辑
现状：表达式行只读展示。规格：原版 `CalculationResult`/表达式区支持点击历史 token 修改操作数并重算
（`StandardCalculatorViewModel.cpp` 的 `SaveEditedCommand`/`HandleUpdatedOperandData`）。
- [ ] 表达式行 token 化为可点击元素，选中操作数弹出编辑，提交后 `SetHistoryExpressionDisplay` 等价重放
- [ ] 桥接层补 `PDATA`/命令重放接口；测试：编辑中间操作数后结果与原版一致

### P3-3 无障碍播报（Narrator → VoiceOver）
规格：`src/CalcViewModel/Common/Automation/NarratorAnnouncement.cpp` 全部事件。
- [ ] `NSAccessibility.post(.announcementRequested)` 等价封装
- [ ] 事件逐条对齐：显示值更新（等号/清除后）、内存变更（MS/M+/M−/MC）、历史面板开合、
      进制/字长/角度切换、错误提示、2nd 开关、绘图跟踪值
- [ ] 真机 VoiceOver 过一遍（记录待人工项）

### P3-4 本地化接线
现状：60 locale 的 xcstrings 已生成（`src/MacApp/Resources/`），但 UI 全部硬编码中文。
- [ ] UI 串逐个换成 `String(localized:)`/String Catalog 键，键名沿用原版 resw 键（如 `plusButton`）
- [ ] 数字格式（小数点/千分位）全走 `Locale`，核对 `decimalSeparator` 逗号地区
- [ ] 验证：切系统语言 en/zh-Hans 抽查主要界面

### P3-5 窗口行为补齐
- [ ] 退出时记忆当前模式 + 各模式窗口尺寸，启动恢复（原版 ApplicationDataContainer 语义）
- [ ] 置顶时切换紧凑布局（原版 CompactOverlay 进入迷你标准键盘并记忆恢复尺寸）——评估后或豁免为
      「仅置顶不改布局」，结论写回本文档
- [ ] 历史条数上限对照原版（`CalculatorManager` `m_maxHistorySize`=20/模式）核实并对齐

### P3-6 响应式布局
规格：`CalculatorStandardOperators.xaml:52-170` 等的 Large/Medium/Small/Tiny 四档字号 + 窄窗隐藏功能行。
- [ ] SwiftUI 按窗口尺寸做等价分档（至少 2 档：常规/紧凑），窄高度时标准模式隐藏函数行（对应 HideStandardFunctions）

### 豁免清单（已定，不再讨论）
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
