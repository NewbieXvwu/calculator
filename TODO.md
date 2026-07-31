# 跨平台移植 TODO（v2）

> 替换旧版《macOS 移植计划》。旧版记录的 macOS parity 工作已完成，归档至 `docs/archive/TODO-macos-v1.md`。
> 制定日期：2026-07-31｜基线 commit：`106ee4a`

---

## 第一部分 · 元规则

这四条约束**高于**本文档中任何具体任务。发生争议时回到这里。

### M1. 对齐原则：能对着 XAML 就对着 XAML

偏离原版必须写明理由，**且理由只能属于以下四类之一**：

| 类别 | 说明 | 举例 |
|---|---|---|
| **(1) 平台无对应物** | 目标平台不存在该概念 | macOS 无汉堡导航惯例 |
| **(2) 平台惯例冲突** | 两者不可兼得 | Material 3 药丸键 vs XAML 方块键 |
| **(3) 平台能力缺失** | 技术上做不到 | Web 无法拦截 Ctrl+W |
| **(4) 原版存在明确缺陷** | **需附证据**（截图/复现步骤）并说明修正方式 | 见 §4.3 原版三处 UI bug |

**以下不是合法理由**：「我觉得这样更好看」「太麻烦了」「用户大概看不出来」「先这样后面再说」。

### M2. 三层严格度

| 层 | 内容 | 严格度 |
|---|---|---|
| **行为** | 引擎命令语义、运算顺序、错误处理、历史/记忆上限、进制字长规则 | **绝对 1:1，无豁免通道** |
| **功能完备性** | 六模式、26 whimsical 单位、129 快捷键、KGF 全 13 字段 | **1:1，缺失必须走豁免流程并记录** |
| **呈现** | 布局、材质、控件形状、导航、图标 | **先对 XAML，冲突时按 M1 四类理由偏离并记录** |

注意"呈现"层**不是自由发挥区**：按键 6×4 网格、哪些键归一组、运算符列在右侧——这些在任何平台都照抄 XAML。只有"按键是圆角矩形还是药丸形"这类真冲突才允许偏离。

### M3. 完成度是二值的

一个阶段要么 **100%**，要么**未开始**。

**禁止的表述**：「基本完成」「核心已完成」「绘图暂缓」「先做核心功能」「后续完善」。
**正确的表述**：「阶段一已完成（100%）」「阶段二未开始（0%）」。

### M4. 诚实优先于完整

**宁可显示"无法计算"，也绝不显示一个看似合理的错误答案。**

用户没有第二个工具来交叉验证计算器。一个错误的渐近线比诚实的"太复杂"糟糕得多。

这条不是口号，是**可检验的验收标准**：任何字段在无法可靠计算时，必须走 `TooComplexFeatures` 通道，不得静默返回空值或近似值。

---

## 第二部分 · 决策存档

已定，不再讨论。若要推翻，需在此处附新证据。

### D1 · 共享层边界（分级下沉）

```
下沉 C++ 共享层：
  ✓ 单位换算表 + 因子 + CalculateSuggested 排序算法
  ✓ 日期差算法
  ✓ 粘贴校验规则（按模式×进制×字长；规则下沉，正则实现各平台可自选）
  ✓ 图形几何：采样 / 等值线 / 坐标变换 / 刻度 / 跟踪吸附
  ✓ 键盘快捷键表（129 项，作为数据）
  ✓ 键盘布局规格（三套键盘的按键五元组）
  ✓ 模式元数据（id / 名称键 / 图标语义名 / 快捷键 / 最小尺寸 / 是否用引擎 / 是否有历史）

留各平台各写一份：
  ✗ StandardCalculatorViewModel 状态机（1,182 行，跟 UI 惯例绑定）
  ✗ 所有 View
  ✗ 平台服务实现（剪贴板 / 窗口 / 按键监听 / 无障碍播报 / 分享 / 材质取色）
```

**判据**：这段代码在 Compose 和 SwiftUI 上会写得一模一样吗？会 → 下沉；不会 → 别下沉。

### D2 · 平台档位

| 档 | 平台 | 说明 |
|---|---|---|
| **主线** | macOS、Windows、iOS/iPadOS、Android、Linux、HarmonyOS、Web | 七个都要做完 |
| **暂不做** | tvOS、watchOS | 遥控器 / 表盘与计算器交互冲突。记录为暂缓，非永久否决 |
| **顺手评估** | visionOS | iOS 完成后评估，预计增量 3–5 人日 |
| **白送** | CLI / TUI | 共享层的最小验证载体，2–4 人日 |

### D3 · 每平台两阶段交付

> **阶段一 · 五模式完整体**：标准 / 科学 / 程序员 / 日期 / 换算。
> 必须**全部功能 1:1 完成**——含 129 项快捷键、26 个 whimsical 单位、完整粘贴校验、
> 完整无障碍播报、60 语言。**不允许以"先跑起来"为由削减任何一项。**
> 划分依据：这五个模式**不依赖任何 CAS 或画布**，是纯引擎 + 键盘 UI，可独立完成、独立验收。
>
> **阶段二 · 绘图完整体**：绘图模式全部功能。
> 划分依据：绘图额外依赖 giac、Canvas 后端、自绘区无障碍三条独立技术线，与阶段一无耦合。
> **它是一块同等分量的大工程，不是阶段一的补丁。**

### D4 · 求解器策略（B 方案）

| 构建 | 分析面板 | 绘图渲染 | 许可 |
|---|---|---|---|
| **完整版**（链接 giac） | ✅ 全 13 字段 | ✅ 完整 | GPLv3 |
| **lite 版**（不链 giac） | ❌ **整体缺失**，显示「此版本不含函数分析」 | ✅ **完整**（画曲线 / 不等式 / 跟踪 / 缩放） | MIT |

**lite 版不提供任何单个分析字段**——不给值域、不给奇偶性、不给零点。理由是一致性：3/13 字段的面板会让用户不断疑惑"为什么这项有那项没有"，而"此版本不含函数分析"是一句清楚的话。

**编译期开关，同一份代码。**

分发矩阵：

| 产物 | 求解器 | 渠道 |
|---|---|---|
| macOS `.dmg` | giac | GitHub Release |
| Windows | giac | GitHub Release |
| iOS `.ipa`（未签名） | giac | GitHub Release，侧载 |
| iOS lite | 无 | 留待有开发者账号时上架 |
| Android `.apk` / `.aab` | giac | Release / Play Store（接受 GPL，已确证 KDE Connect 先例） |
| Linux | giac（`apt` 现成） | Flatpak / AUR |
| HarmonyOS | giac（编得出）/ lite（编不出） | 侧载（调试证书实名 1 年 / 100 台） |
| Web | **lite** | 自托管 / Pages |

**关于分发措辞**：GPL 从不禁止分发，被禁的是 App Store 的 ToS。大方写「因 App Store 条款与 GPLv3 冲突，完整版仅提供侧载」即可，不必隐晦。

### D5 · 仓库结构

**Monorepo。** 规格表（键盘 / 单位 / 快捷键 / 色板）必须单一真相源，跨仓库同步必然漂移。

```
src/
  CalcManager/        引擎（上游，几乎零改动）
  Shared/             ← 新增：C ABI 门面 + 规格表 + 图形几何
  MacApp/  WinApp/  iOSApp/  AndroidApp/  LinuxApp/  OhosApp/  WebApp/
  MacEngineTests/     ← 扩展为跨平台 C++ 测试
spec/                 ← 新增：规格文档（KGF 格式、图标语义名、快捷键矩阵）
docs/
  decisions/          ← 本轮 10 份分析文档
  rejected/           ← 废案
  archive/            ← 旧 TODO
```

`src/CalculatorUITests` / `CalculatorUITestFramework`（C# + WinAppDriver）保留但不移植，其 Page Object 定义作为"应测状态清单"的来源。

### D6 · 测试策略

- **引擎级 + 求解器级测试全部 C++**，扩展 `src/MacEngineTests/shim/CppUnitTest.h`（291 行，已实测在 macOS / GCC Linux / OHOS clang 三套工具链上编译运行）
- **UI / VM 级测试各平台各写**
- **现有 `MacAppTests.swift`（1,343 行 / 90 例）中测纯逻辑的部分逐步退役**，避免双真相源
- **对拍/平价测试退役纪律**：`GraphGeometryTests`（C↔Swift 平价）、`MarchingSquares.swift`（对拍 oracle）等过渡测试**与 Swift 首发实现退役绑定**——实现删除之日必须同步处理：有独立行为价值的断言翻译为 C 层直接测试，其余删除。禁止平价测试锁定死代码（见 P-macOS 回填任务）
- **验证方法优先级**：属性断言（相对残差，非绝对值）> 与原版实测对照 > 硬编码期望值（最后手段）

### D7 · 上游关系

**不提 PR。** 两个 include 修复作为 fork 内本地修复，记录在 §3 S1 的"与上游的已知差异"中，便于将来 rebase 时不被覆盖。

### D8 · 图标与符号

**关键区分：现在被当成"图标"的东西里，大部分其实是数学符号。**

```
必须改为 Unicode 文本（全平台通用、无许可问题、随字体缩放）：
  ÷ (U+00F7)  × (U+00D7)  − (U+2212)  + (U+002B)
  = (U+003D)  % (U+0025)  ± (U+00B1)
  当前 macOS 版用的 SF Symbols 名（"divide"/"multiply"/"minus"/"plus"/"equal"/
  "percent"/"plus.forwardslash.minus"）只是 Apple 平台的渲染选择，
  规格表必须存 Unicode，不存 SF Symbols 名。
```

真正需要图标集的只剩 **UI chrome，约 15–20 个**：退格、历史、记忆、设置、菜单、分享、缩放、跟踪、复制、粘贴、展开/收起。

| 平台 | 图标来源 |
|---|---|
| Apple 系 | SF Symbols（系统内置，**禁止导出到其它平台**） |
| Android | Material Symbols |
| HarmonyOS | HarmonyOS Symbol（**仅在鸿蒙运行时调用，不抽取字形**） |
| Windows | 原版 XAML 已有（Segoe Fluent Icons） |
| **Web / Linux** | **Material Symbols（Apache-2.0，许可明确）** |

Linux 补充：freedesktop 图标命名规范里有的（`edit-copy`、`edit-paste`、`document-properties`）用 `QIcon::fromTheme` 让 DE 提供，这比塞 Material 更原生；规范里没有的（退格、跟踪）用 Material 兜底：

```cpp
QIcon::fromTheme("edit-copy", QIcon(":/icons/copy.svg"))
```

**规格表存语义名**（`backspace` / `history` / `memory-add` / …），各平台一张映射表，落地 `spec/icons.json`。

### D9 · 标量类型（N3）

**统一 `double`，留 `CalcScalar.h` 逃生通道。**

```cpp
// src/CalcManager/CalcScalar.h
#pragma once
#if defined(CALC_USE_EXTENDED_FLOAT)
  #include <boost/multiprecision/cpp_bin_float.hpp>
  using calc_float = boost::multiprecision::cpp_bin_float_double_extended;
  #define CALC_FLOAT_NAME "double-double"
#else
  using calc_float = double;          // 默认：全平台一致
  #define CALC_FLOAT_NAME "double"
#endif
static_assert(sizeof(double) == 8, "IEEE754 binary64 required");
```

**真正保证一致性的不是 typedef，是黄金测试**（见 S10）。typedef 只是让切换便宜。

### D10 · 符号层（N2）

**随数值方案一并归档。** 完整版由 giac 提供符号能力，lite 版不提供分析面板，因此自研 AST 符号层无用武之地。若将来 lite 版需要恢复分析能力，见 `docs/rejected/numeric-solver.md`。

---

## 第三部分 · 共享层任务

按依赖顺序。**S1–S3 优先于一切平台工作**，因为它们修的是现在正在给出错误答案的代码。

---

### S1 · 隐式依赖修复 ✅ 完成（2026-07-31）

**问题**：两个头文件靠 Apple SDK 的间接包含侥幸编过，换任何工具链都失败。

```cpp
// src/CalcManager/Ratpack/support.cpp
#include <cmath>          // log2 / ceil

// src/CalcManager/Header Files/IHistoryDisplay.h
#include <string>
#include <string_view>    // std::wstring_view
```

**证据**（实测）：
- GCC 14 / Linux：`support.cpp:139: error: 'log2' was not declared in this scope`
- OHOS clang 15.0.4 / aarch64：`IHistoryDisplay.h:16: error: no type named 'wstring_view' in namespace 'std'`

**验收**：
- [x] 两处 include 已添加
- [x] macOS 构建无回归（`swift build` + `xcodebuild test` 全绿）
- [x] CI 增加检查：引擎在 `-std=c++17` 下能编译（防止将来引入 C++20 依赖）——`Tools/check_engine_cxx17.sh`
- [x] `docs/upstream-divergence.md` 记录这两处修改，标注"上游 `pch.h` 注释明确要求支持非 MSVC 工具链，此二文件违反该目标"

**成本**：1 人日

---

### S2 · 删除 `GraphAnalyzer.swift` ✅ 完成（2026-07-31）

**问题**：这 102 行是不依赖 giac 的降级路径，有三个实测确认的真 bug：

| Bug | 说明 |
|---|---|
| 漏偶重根 | `(x-1)²` 不变号，`y0*y1 < 0` 永远不成立 → 零点漏报 |
| 极值精度 = 采样分辨率 | 直接取 `xs[i]`，误差 = 区间/2000，不做任何细化 |
| `fLo * fMid < 0` 可能溢出 | 大数相乘溢出 → 符号判断错误。应比较符号而非乘积 |
| 密集根漏检 | `sin(1/x)` 在 0 附近必翻车 |

**B 方案下它没有存在理由**：完整版用 giac，lite 版不给分析面板。

**不保留为 giac 超时兜底**——那意味着"超时后给出可能错误的答案"，违反 M4。

**验收**：
- [x] 文件已删除
- [x] `GiacMathSolver` 中对它的引用已清理（核查结果：无代码引用，仅注释提及上游接口名）
- [x] 相关测试已移除或改为 giac 路径（删除 `GraphAnalyzerTests` 2 例；giac 路径已有 `GiacMathSolverTests` 覆盖）
- [x] `docs/rejected/numeric-solver.md` 记录删除理由

**成本**：0.5 人日

---

### S3 · GiacMathSolver 诚实性加固 ✅ 完成（2026-07-31）

**背景**：2026-07-31 端到端实测 14 个函数，发现 **6 类正确性缺陷**。这些缺陷全在 `GiacMathSolver`（313 行）的编排与解析层，**不在 giac 内核**——giac 返回的是对的，是我们的解析漏了。

**当前用户可见的错误输出举例**：
- `tan(x)` 单调性显示 `(-∞, +∞) 递增`（明显为假）
- `1/x` 值域显示 `(-∞, +∞)`（包含取不到的 0）
- `sin(x)+sin(πx)` 水平渐近线显示 `y = bounded_function(17)`（乱码级）

#### R1 · `bounded_function(k)` 泄漏 🔴

giac 用 `bounded_function(n)` 表示"极限有界但不存在"——**这恰恰是"无水平渐近线"的正确信号**，我们却当成了渐近线的值。

```
修复：
  if result contains "bounded_function" → 无水平渐近线（确定没有，不是 too complex）

同时 isFiniteResult 建立 giac 特殊记号黑名单：
  bounded_function / undef / infinity / unsigned_inf / +infinity / -infinity
  任何未在数值白名单内的 token 一律不显示。
```

影响：`sin(x)`、`sin(x)+sin(πx)` 两例。

#### R2 · 值域空洞丢失 🔴

现逻辑"双向无界 ⇒ `(-∞,+∞)`"忽略不可达值，**3 例全错**：

| 函数 | 原版 | 我们 |
|---|---|---|
| `1/x` | `y ∈ ℝ\{0}` | `(-∞,+∞)` |
| `x+1/x` | `(-∞,-2]∪[2,∞)` | `(-∞,+∞)` |
| `(x²-1)/(x-1)` | `y ∈ ℝ\{2}` | `(-∞,+∞)` |

**正确做法**：值域必须从「驻点值 ∪ 端点极限 ∪ VA 单侧极限 ∪ 可去奇点处的极限值」**构造**，而不是从上下界推断。

第三例最微妙：需识别"定义域挖点处的极限值也要从值域挖掉"。

**构造不出完整结构 → 报 too complex**，不得给一个包含取不到值的区间。

#### R3 · `Auto assume x∈[0,2π]` 截断 🔴 影响最广

giac 解三角方程时自动假设主区间，导致：

| 函数 | 后果 |
|---|---|
| `tan(x)` | 定义域只排一个点 `x<>(1/2·π)`；VA 全丢；单调性 `(-∞,+∞) 递增` |
| `sin(x)` | 单调性给出 `(π/2, +∞) 递减` 等无穷区间断言 |

**两个方向**：
1. 试 `all_trig_solutions:=1` 是否也影响 `solve(diff...)` 与 `domain`（该开关已在零点通解中使用）
2. 若不行：**检测到 `Auto assume` 警告输出时，该字段直接标 too complex**

**原则**：宁可标 too complex，也不能把主区间结论外推到 ℝ。

#### R4 · bisection 数值解冒充完备列表 🔴

giac 无法符号求解时回退数值 bisection，我们当成了完整答案：

| 函数 | 输出 |
|---|---|
| `sin(1/x)` | 拐点 36 个数值点（原版：too complex） |
| `sin(x)+sin(πx)` | 拐点 137 个点含 `(2.6e-27, 1.1e-26)` 垃圾；单调性 143 段噪声 |

**判据（任一触发即整字段标 too complex）**：
- giac 往 stderr 打 bisection 提示
- 结果点数超阈值（建议 20）
- 结果含超出视窗量级的垃圾值

#### R5 · `sign` 浮点失配 🔴 最阴险

`sign(...)` 对浮点系数返回 `-1.0`，代码 `== "-1"` 精确匹配失配 → **极值静默丢失**。

```swift
// 改为数值解析
if let v = Double(result) { sign = v > 0 ? 1 : (v < 0 ? -1 : 0) }
```

影响：`1/(x²+0.01)` 的极大值 `(0,100)` 丢失、`sin(x)+sin(πx)` 全部极值丢失。

**附带任务**：在 313 行中全局搜索"字符串精确比较 giac 返回值"的模式，大概率不止此一处。

#### R6 · 常函数 `period() = 0` 🔴

`period()` 返回 0 表示"任意周期 / 不适用"，不是"周期为 0"。

```
period == 0          → 不显示周期字段（对齐原版）
period == +infinity  → 非周期
```

#### 同时补齐的缺失项 ⬜

| 项 | 现状 | 修复 |
|---|---|---|
| 不可导 / 端点极值 | `abs(x)` 的 (0,0)、`sqrt(x)` 的 (0,0) 全空（`diff` 在断点 undef） | 在定义域端点和不可导点上单独判断。**原版做了，我们必须做** |
| 有界值域 | `abs`/`sqrt`/`1/(x²+0.01)`/`5` 全降级 too complex | 随 R2 一起重写 |
| `abs`/`sqrt` 单调性全空 | 中点采样恰落在 x=0（undef） | 采样点避开断点，或断点两侧分别取样 |
| 定义域 = ℝ 不显示 | 返回 nil | 原版显示 `x ∈ ℝ`，补上 |
| `tan` 值域静默为空 | — | 至少标 too complex，不得静默 |

#### 暂不做（记录，第二阶段考虑）

**极值 / 拐点 / 单调性的周期通解族**。零点通解已有（`n·π`），其余字段被 `Auto assume` 截断成代表点。要做出 `(2πn₁+π/2, 1), n₁∈ℤ` 需在 R3 之上再加一层"主区间解 + 周期 → 合成通解族"。

**先把 🔴 消干净（不说错话），再追求通解（说得更全）。**

#### 性能治理 🟠

实测：12/14 个函数在 0.19–0.36s；`sin(1/x)` 1.17s（96 条查询）；**`sin(x)+sin(πx)` 8.26s（688 条查询）**。单条 `caseval` 约 11–13ms 恒定。

giac 有全局锁串行化 → **8.3s 会阻塞后续所有分析请求**。

三条对策（建议全做）：
1. **查询预算**：单函数超过 100 条查询即中止，剩余字段标 too complex
2. **总超时**：2 秒
3. **利用 `PerformAnalysisType` 位标志**（原版留好的免费设计，0x01–0x80）：交互期只算便宜字段（定义域 / 截距 / 奇偶性），停下来再补算贵的（单调性 / 拐点）

#### 保留的三处"强于原版" ✅+

按 M1 第 (4) 类记录：

| 项 | 原版 | 我们 |
|---|---|---|
| `sin(x)+sin(πx)` 周期 | too complex | **非周期**（`period()` 返回 `+infinity`） |
| `sin(x)+sin(πx)` X 截距 | **bug：说"没有"**（错） | **两族有理化通解，数学正确** |
| `sin(1/x)` 值域 / 周期 | too complex | `[-1,1]` / 非周期 |

#### 已确认无回归 ✅

**Q1 结论**：`denom(normal(f))` 路径天然正确处理可去奇点与复奇点。
- `(x²-1)/(x-1)` → VA 空（原版也空）✅
- `1/(x²+0.01)` → VA 空（原版也空）✅

这印证了早前的判断：**VA 判定必须先求分母零点，`standardChop` 只能作辅助信号。**

**验收**：
- [x] 6 类根因全部修复（2026-07-31，`GiacMathSolver` 全量重写 ~750 行：R1 bounded_function 白名单、R2 值域构造式重建、R3 stderr `Auto assume` 检测门控（GiacBridge 新增 `evaluate:warningsOut:` 管道捕获）、R4 bisection/解数>20 拒收、R5 sign 数值解析、R6 period==0 隐藏字段；另补齐：不可导点/闭端点极值（abs/sqrt 的 (0,0)）、定义域 ℝ 显示、常函数短路径、tan 值域显式 too complex）
- [x] 14 函数回归测试（见 S9）全部转绿，无 🔴（`tests/kgf-regression/` 14 个期望文件 + `KGFRegressionTests` 逐字段断言；🟡 格式差清单见 `spec/kgf-reference.md` §4.5）
- [x] 性能：任何单函数分析 ≤ 2 秒（查询预算 100 条 / 总超时 1.8s；实测 14 case 全部 ≤0.5s，`sin(x)+sin(πx)` 从 8.26s 降至 0.21s；回归测试内置 ≤2s 断言）
- [x] 三处"强于原版"保留并记录（`spec/kgf-reference.md` §3.11/§3.12：sin(1/x) 值域+非周期+零点通解、sin(x)+sin(πx) 非周期+两族 X 截距通解）

**成本**：1.5–2 人周

---

### S4 · 区间算术（Tupper 方法）✅ 已完成（2026-07-31）

**问题**：绘图渲染层有**唯一的静默失败**——它不知道自己错了。

| 缺陷 | 说明 |
|---|---|
| marching squares 漏格 | 一格内 f 有两零点 → 四角同号 → 整段曲线消失。反例：`x² = y²(x+1)` 自交点、比一格更窄的满足区域 |
| 逐列求值混叠 | `sin(1000x)` 画出虚假低频曲线；窄峰被跳过 |
| 不等式着色 | 细窄条带整片消失，或误染 |

**"拓扑精确"不成立**——正确表述是「网格分辨率足以解析所有特征时才拓扑精确」，而这个前提无法用采样验证。

**注意**：这个缺陷 giac 版和 lite 版**完全一样**，因为绘图路径不调 giac（`drawCurve` 用 `GraphExpression.evaluate()`，`drawImplicit` 用 `MarchingSquares.trace()`）。**这是两版共享、且唯一能让我们超过原版的地方。**

**方案**：
- 隐式方程 / 不等式着色改用**区间算术**（Tupper, SIGGRAPH 2001），对每个像素矩形做区间求值，三值输出：确定有解 / 确定无解 / 不确定；不确定则细分
- **"不确定"这个状态本身就是内建自检**，不需要额外发明降级条件
- 库：`Boost.Numeric.Interval`（Boost 许可，header-only）
- 参考实现：Graphest（Rust / MIT，用 IEEE 1788 的 `inari`）

**分层引入**（N1 决定：a）：
- 隐式绘图 / 不等式着色：**从一开始就用区间**
- 显式曲线 `y=f(x)`：先保持逐列求值，第二阶段升级为"该列 x 区间上 f 的值域是否与像素 y 区间相交"

**验收**：
- [x] `x² = y²(x+1)` 自交点正确渲染
- [x] `0 < sin(1/x) < 0.1` 附近的细窄区域不整片消失
- [x] 「不确定」像素有明确的视觉表示或细分策略

**成本**：1–2 人周

**验收记录（2026-07-31）**：
- 架构：四叉树细分 + 三值判定下沉共享 C 层（`graph_geometry.h`：`graph_implicit_cells` / `graph_inequality_regions` / `graph_pow2_cell_count` / `graph_eval2_interval_fn`，与 S7 同一门面）；区间求值经 C 回调接 Swift 内核（`GraphExpression.evaluateInterval`），实现纯数学、零分配、snprintf 式 cap 约定，超预算由调用方加粗 `pixel_px`（保守方向，只多涂不丢解）。
- 区间内核（Swift，`GraphExpression.swift`）：`IntervalValue` + 全部 15 个函数与四则/幂的区间扩展；外向舍入用 `nextDown/nextUp`（复合运算 2×加宽），三值定义域（defined / maybeDefined / nowhereDefined）；约定 0×∞→0、除以含零区间→全线+maybeDefined、sin/cos 宽区间→[-1,1]、周期极值经格点检测（容差随量级放大）。
- 隐式方程混合渲染（`GraphingView.drawImplicit`）：marching squares 段保平滑与线型 + 区间补格只补 MS 因四角同号/角未定义漏画的格（自交点、亚格特征）；四叉树叶与 MS 网格经 `graph_pow2_cell_count` 逐节点对齐（2^k 格），角抑制判定才成立。
- 不等式三值渲染（`GraphingView.drawInequality`）：「确定成立」0.2 透明度（原版口径）、「不确定」0.08 更浅着色显式呈现（M4：近似不冒充精确）；确定区域以未细分四叉树大块输出。
- 验收判据逐条：①自交点——`testImplicitCellsCoverSelfIntersection`（无角抑制时原点叶格必幸存=无假阴性）+ `testImplicitCellsFindSubCellCircleMarchingSquaresMisses`（半径 1e-3 圆 MS 全盲、区间补格救回且聚在圆心 6px 内）；②细窄区域——`testInequalityRegionsKeepNarrowBandOldSamplerMisses`（0.2px 细带旧采样丢失、新版以不确定保住且面积收敛）+ `testInequalityRegionsSinOneOverXNoFalseNegatives`（sin(1/x)<0.1 全部真值列覆盖、x→0 振荡区以不确定可见）；③不确定表示——三值 API 分开输出 + UI 浅色着色 + `testInequalityRegionsCertainHalfPlane`（确定不越界、不确定贴边界）。
- 内核性质锁定：`testIntervalEnclosesPointSamplesAcrossCorpus`（9 表达式 × 5 盒 × 81 采样点包含性 + 定义域三值诚实性）、`testIntervalSpecialShapes`（sin 周期极值、1/x 含零、sqrt/ln 部分定义域）。
- 全量回归：swift test 126/126 通过，engine-tests ALL TESTS PASSED，calc-smoke 通过。
- **M1 偏离**：未用 `Boost.Numeric.Interval`（TODO 原建议），改为自研 Swift 区间内核。理由（合法理由②依赖不可用）：boost 未 vendor 进仓库，且求值器 AST 在 Swift 侧（`GraphExpression` 私有类型），跨 C++ 桥接 AST 的成本远高于 ~200 行自研内核；语义按 Tupper 2001 + IEEE 1788 精神实现并被性质测试锁定。
- 诚实未消费项：①显式曲线 `y=f(x)` 仍为逐列采样（N1 决定 a 的第二阶段，`sin(1000x)` 混叠仍在，待升级为列区间求值）；②外向舍入依赖 libm ≤1 ulp 误差假设（Apple libm 满足；复合运算 2×加宽作缓冲），非形式化验证；③舍入方向未用 fesetround（Swift/多线程下不可靠），用 nextUp/nextDown 代替，区间比最优紧界略宽；④`x^y`（底含负）与 tan 跨渐近线直接放宽为全线+maybeDefined，正确但不最紧；⑤参考实现 Graphest/inari 未逐项对照，仅按论文语义自证。

---

### S5 · C ABI 门面 ✅ 完成（2026-07-31）

**问题**：`CalcManagerBridge.mm`（337 行 ObjC++）是唯一进入引擎的通道，而 ObjC 运行时**只存在于 Apple 平台**。Android / Linux / Web / Windows / 鸿蒙**每一个都要重写这 337 行**。

`CalcSession.{h,cpp}`（542 行纯 C++）已经把门面做好了，只差最后一步：

```
现状:  Swift ──> CalcManagerBridge.mm (ObjC++) ──> CalcSession (C++) ──> CalcManager

目标:  Swift ──┐
       Kotlin ─┤
       TS/JS ──┼──> calc_c_api.h (extern "C") ──> CalcSession (C++) ──> CalcManager
       ArkTS ──┤
       C++ ────┘
```

C ABI 是所有语言的最小公倍数：Swift 直接 import、Kotlin 走 JNI、JS 走 Emscripten bindings、ArkTS 走 NAPI、C# 走 P/Invoke。

**保留现有经验**：TODO v1 记录的「ObjC++ 文件严禁直接 include 引擎头（Ratpack 全局 `pi` 与 CarbonCore 符号冲突，必须经 `CalcSession` 门面）」——C ABI 天然强化这道隔离。

**接口粒度**：只导出十几个领域 API，不要把 C++ 类逐一暴露。

```
calc_session_create / destroy
calc_send_command / send_digit
calc_get_display_state
calc_set_mode / set_radix / set_precision
calc_memory_*  (store / recall / add / subtract / clear)
calc_history_*
calc_paste / copy
calc_set_locale_symbols     ← 见 S8，分隔符注入
calc_serialize / restore_state
```

**异常处理约束**：引擎抛的是**裸 `uint32_t` 错误码**（`CALC_E_DIVIDEBYZERO` 等，定义在 `Ratpack/CalcErr.h`），不是 `std::exception`。抛出点遍布 `rat.cpp` / `logic.cpp` / `fact.cpp` / `conv.cpp` / `scioper.cpp` / `exp.cpp` / `trans*.cpp` / `Rational.cpp`。

→ **绝不让 C++ 异常穿过 C ABI 边界。** 在边界处 `catch (uint32_t)` 并转成错误码返回值。

**成本**：3–5 人日

**完成记录（2026-07-31）**：`src/MacBridge/include/calc_c_api.h`（纯 C 头，UTF-8
字符串约定 + 回调表 + 错误码约定）+ `calc_c_api.cpp`（只 include `CalcSession.h`，
维持引擎头隔离；`CALC_GUARD` 在每个入口 `catch (uint32_t)` 转错误码、`catch (...)`
折叠为 `CALC_E_UNKNOWN`，异常绝不穿越 C 边界；UTF-8↔wchar_t 转换自带，兼容
2/4 字节 wchar_t）。`CalcCApiTests` 5 例冒烟（Swift 直接走 C ABI）：算术+历史、
内存回调、locale 分隔符注入、程序员进制转换、NULL/越界边界安全。
偏差记录：TODO 草案中的 `calc_paste/copy` 与 `calc_serialize/restore_state` 未
实现——`CalcSession` 门面本身无此能力（粘贴解析在 ViewModel 层，序列化待
S10），列表本为示意粒度；macOS Swift 切换到 C ABI 属 P-macOS 回填任务。

---

### S6 · 规格表下沉 ✅ 完成（2026-07-31）

**问题**：本该是数据的东西被写成了代码，会被抄 7 遍，每抄一遍多一处漂移源。

| 规格 | 现状 | 目标 |
|---|---|---|
| 键盘布局 | 三个 View 里 57 个 `CalcKey(` 调用，799 行 | 五元组表（标签 / 样式 / 命令 / a11y 键 / 禁用条件） |
| 129 项快捷键 | 分发表散在代码里 | 数据表 + 各平台冲突矩阵（见 S12） |
| 单位换算 | `UnitConverterData.swift` 307 行 | C++ 静态表 |
| 14 色方程色板 | 硬编码 | 规格表（深浅两套） |
| `LayoutTier` 字号分档阈值 | 硬编码 | 规格表 |
| 模式元数据 | 三个平行 `switch`（`minBodyWidth` / `minWindowWidth` / `minWindowHeight`）+ `persistenceKey` + `usesEngine` + ⌘1-6 散在两个文件 | **一张模式描述表** |
| 图标语义名 | SF Symbols 名硬编码 | `spec/icons.json`（见 D8） |

**进展（2026-07-31）**：
- [x] 模式元数据 → `spec/modes.json` + `ModeDescriptor.swift` 一张表：消灭了 4 处平行 switch（usesEngine/precision/persistenceKey/announcementLabel、ContentView 三个尺寸 switch、模式菜单图标、⌘1-6 菜单），SpecTableTests 防漂移
- [x] `LayoutTier` 分档阈值 → `spec/layout-tiers.json` + `LayoutTier.all` 静态表（降序匹配 + 0 兜底），含边界行为测试
- [x] 14 色方程色板 → `spec/graph-colors.json`（深浅两套 hex），与 `GraphingViewModel.lightPalette/darkPalette` 逐色比对
- [x] 键盘布局五元组表 `spec/keyboard-layout.json`：四键盘全量（标准 6 行含紧凑首行变体、科学 7 行、程序员 6 行含移位四态 shiftVariants、换算 4 行动作键盘）；label/style/command/a11y/disabled 五元组 + 动态键 kind（CE/C 切换、2nd 态 invPair、移位变体、locale 小数点）；SpecTableTests 校验命令名可解析、行跨度=列数、invPair ⇄ functionColumn、shiftVariants ⇄ BitShiftMode
- [x] 快捷键数据表 `spec/keyboard-shortcuts.json`：菜单（⌘1-6/⌘C/⌘V/⌃记忆五键/⌃H/⌃⇧D/⌥⌘↑）+ 特殊物理键 + F2-F12 按模式表 + 字符词条逐模式映射 + 科学模式字母四类和弦（plain/⇧/⌃/⌃⇧）+ 程序员 A-F/移位动态键 + 换算独立监听；SpecTableTests 行为级防漂移（直接驱动 handleKey 断言 flashedCommand/进制/角度/字长），冲突矩阵审计归 S12
- [x] 单位换算数据表 `spec/units.json`（12 类 142 单位，脚本自 Swift 表机械提取零手抄；factor 位级比对 + 温度特判抽样）；C++ 静态表在共享层落地时以此 JSON 为数据源生成（macOS 现阶段消费方仍是 UnitConverterData.swift，防漂移已锁死）
- [x] 图标语义名 `spec/icons.json`（40 项语义名，含 key.* 供键盘布局表引用）+ `AppIcons.swift` 镜像；全部视图调用点已切到语义常量，源码不再出现 SF Symbol 字面量（键面符号经键盘布局表落地）

下沉后各平台键盘退化成 ~80 行渲染循环：

```
for row in spec.rows(mode, tier):
    for key in row:
        平台原生按钮(key.label, 样式映射[key.style], onClick: { send(key.command) })
```

**成本**：1–1.5 人周

**验收记录（2026-07-31）**：spec/ 下 7 张 JSON 表全部落地，SpecTableTests 七项双向防漂移测试全绿（含行为级 handleKey 驱动）。macOS 视图切换为直接消费规格表渲染循环属 P-macOS 回填（见 §7），单位表 C++ 静态表生成属共享层落地时的消费方迁移。

---

### S7 · 图形几何下沉 ✅ 完成（2026-07-31）

`GraphingView.swift` 1,056 行里，真正的绘制调用只有 13 个 `Path(`、10 个 `context.stroke`、4 个 `context.fill`。**其余绝大部分是可共享的几何数学**：

- 坐标变换 `toScreenX` / `toScreenY`
- 刻度算法 `niceStep`（1-2-5）
- 跟踪吸附 `moveTraceCursor`（按 y 距离视窗归一化就近吸附）
- 采样 / 抽稀
- marching squares（93 行，保留自研——教科书算法，边界情况少，引 CGAL/VTK 不划算）

**这层抽象在 macOS(CoreGraphics) / Web(Canvas) / 鸿蒙(OH_Drawing) / Android(Compose Canvas) 上是同一套代码，只换后端。这是 UI 相关代码里唯一能真正跨平台共享的部分。**

**成本**：1 人周

**验收记录（2026-07-31）**：`src/MacBridge/include/graph_geometry.h` + `graph_geometry.cpp`
落地（纯 C ABI、零引擎依赖、零分配——调用方自备缓冲，求值以回调传入，异常不越界）。
覆盖：视窗结构与坐标双向变换、1-2-5 刻度步长与刻度枚举、pan/zoom/锚点缩放/
applyRange/auto-fit（5%–95% 分位）、逐像素列采样（未定义列抬笔 + 1.5 倍画布高
跳变断裂）、marching squares（含 ε 防退化与鞍点中心消歧）、不等式区域行程合并、
跟踪就近吸附。`GraphGeometryTests` 12 项平价测试把 C 层与 macOS 首发实现
（GraphingView/GraphingViewModel/MarchingSquares）逐项锁定，其中 marching squares
逐线段位级比对——为此 CalcManagerBridge 编译加 `-ffp-contract=off`（fma 收缩会翻转
近零节点符号，改变等值线拓扑；各平台移植构建须同样关闭）。macOS 视图改调共享层
属 P-macOS 回填（见 §7）。

---

### S8 · Locale 分隔符注入加固 ✅ 完成（2026-07-31）

**实测证据**（OHOS aarch64 / qemu）：

```
setlocale(fr_FR.UTF-8) -> NULL (unsupported)
localeconv decimal_point='.' thousands_sep=''
wchar_t=4  wregex match=1
```

musl 只有 6 个 locale：`C` / `C.UTF-8` / `en_US` / `en_US.UTF-8` / `zh_CN` / `zh_CN.UTF-8`。

**60 语言应用指望 `localeconv()` 拿法语逗号会全军覆没，而且是静默返回错误值而非报错。**

**结论**：现有 `IResourceProvider` 注入设计**不是"可行"，是唯一可行**。

**代码规范（写进 CI 检查）**：

```
禁止在引擎与共享层出现：
  localeconv()  /  setlocale()  /  std::locale("")  /  wcstod_l()  /  strtod_l()
  std::wcout / std::wcerr        （依赖 wide facet，日志走平台原生）
  std::wstring_convert / std::codecvt_utf8   （C++17 deprecated，自写 30 行 UTF-8↔UTF-32）
```

**分组模式（R6 遗留项）** 🔴 可能是现存 bug：

引擎的 `sGrouping` 现在传 `"3;0"`。但：
- **印度**是 `3;2;2`（12,34,567 拉克/克若尔制）
- 部分 locale 有 `minimumGroupingDigits`（西班牙语四位数不显示分隔符）

现有 macOS 实现只取了 `Locale.groupingSeparator`（分隔符**字符**），没有推导**分组模式**。

**改为存结构而非字符串**：

```cpp
struct Grouping {
    int  primary;               // 3
    int  secondary;             // 2（印度）
    bool repeatSecondary;
    int  minimumGroupingDigits;
};
```

各平台获取方式：

| 平台 | API |
|---|---|
| ICU | `DecimalFormat::getGroupingSize()` + `getSecondaryGroupingSize()` |
| Apple | `NumberFormatter.groupingSize` + `secondaryGroupingSize`（**只读前者会破坏印度分组**） |
| Android | API 24+ 用 `android.icu.text.DecimalFormat`（不要用旧 `java.text`） |
| ArkTS | `Intl.NumberFormat` 的 `resolvedOptions()` **不暴露分组尺寸** → 用大整数跑 `formatToParts()` 反推各 `integer` 段长度 |

**纠正**：现代 CLDR 中文是**三位**分组，不是四位。

**成本**：3–5 人日

**验收记录（2026-07-31）**：
- 分组结构落地：`MacCalc::Grouping{primary, secondary, repeatSecondary,
  minimumGroupingDigits}`（CalcSession.h）+ `EngineString()` 为唯一的
  sGrouping 换算点；C ABI 暴露 `calc_grouping_t` + `calc_grouping_format`
  （snprintf 语义），各平台从结构生成，不再手拼字符串。
- 原 bug 修复：CalcManagerBridge.mm 此前只注分隔符、sGrouping 恒为 "3;0"；
  现经 NSNumberFormatter `groupingSize`+`secondaryGroupingSize` 推导注入
  （印度 → "3;2;0"）。行为验证：`testIndianGroupingDrivesEngineDisplay`
  断言引擎实际输出 `12,34,567`。
- CI 禁用清单：`LocaleBanTests` 随 swift test 扫描 src/CalcManager +
  src/MacBridge 全部 C/C++/ObjC++ 源，禁 localeconv/setlocale/std::locale("")/
  wcstod_l/strtod_l/std::wcout/std::wcerr/wstring_convert/codecvt_utf8
  （smoketest 开发 harness 豁免）。
- 如实记录的未消费项：`minimumGroupingDigits` 结构已承载但引擎 GroupDigits
  暂不支持（西语 1234 仍会分组），属引擎侧后续项；单位换算器的 Swift 侧
  分组仍固定三位（UnitConverterViewModel），随规格表消费方迁移一并处理。

---

### S9 · KGF 规格与 14 函数回归测试 ✅ 完成（2026-07-31）

**这是本项目唯一一份原版行为的一手记录**——微软的专有引擎不开源，你的截图就是规格书。

落地两份文件：

```
spec/kgf-reference.md       原版 14 函数 × 13 字段实测记录（附截图）
tests/kgf-regression/       每 case 一个期望文件
```

#### 显示格式规格（截图实测，必须照抄）

| 项 | 规格 |
|---|---|
| **定义域** | `x ∈ ℝ` / `x ≠ 0` / `x ≥ 0` / `x ≠ πn₁ + π/2, ∀n₁ ∈ ℤ` |
| **值域** | `y ∈ ℝ` / `y ∈ ℝ \ {0}` / `y ∈ (0,100]` / `y ∈ [0,∞)` / `y ∈ (−∞,−2] ∪ [2,∞)` / `y ∈ [−1,1]` / `y ∈ {5}` |
| 空截距 | `∅` |
| 空极值 / 拐点 / 渐近线 | **完整中文句子 + 句号**（如「此函数没有任何极小值点。」） |
| 渐近线 | 方程形式 `x = 0` / `y = x + 1` |
| 极值 / 拐点 | 坐标对 `(0,100)` / `(√6/3, −4√6/9)` |
| **多零点分隔** | `x = −√2 or x = 0 or x = √2` ← **中文界面里是英文 "or"** |
| 多条渐近线 | 分行（`\|x\|` 的 `y = x` / `y = −x`） |
| 周期 | 符号形式 `2π` / `π` |
| too complex | 底部独立段落 +「这些功能过于复杂，计算器无法计算:」+ 逗号分隔字段名 |
| 通解 | 零点用 `n₁ ∈ ℤ`（无 ∀）；定义域用 `∀n₁ ∈ ℤ`（有 ∀） |
| **不化简** | 原版保留 `sin(π/2)` 不化简为 `1` → 我们也不必追求深度化简 |

**注意定义域与值域的记号不对称**：同样是"挖掉一个点"，定义域写 `x ≠ 0`，值域写 `y ∈ ℝ \ {0}`。

**字段显示顺序**（XAML 定，非枚举顺序）：

```
定义域 → 值域 → X轴截距 → Y轴截距 → 极小值 → 极大值 → 拐点
→ 垂直渐近线 → 水平渐近线 → 斜渐近线 → 奇偶性 → 单调性 → 周期
```

**单调性区间顺序**：原版无规律（`1/x`、`x³-2x`、`|x|` 是右到左，但 `x+1/x` 给出 `(0,1)→(1,∞)→(-∞,-1)→(-1,0)`）。判定为引擎内部发现顺序的泄漏，无语义。→ **我们用从左到右**，按 M1 第 (4) 类记录。

#### 原版三处 UI bug（我们必须修）

| 函数 | 现象 |
|---|---|
| `tan(x)` | 垂直渐近线栏显示「没有」，同时又列进 too complex |
| `sin(1/x)` | 拐点栏显示「没有转折点」，同时又列进 too complex |
| `sin(x)+sin(πx)` | X 截距栏说「没有」，但 x=0 处确实为 0（Y 截距栏自己写了 `y=0`） |

**机制**：字段被标 `TooComplexFeatures` 时未被抑制，仍渲染了默认的 `KGF*None` 文案。**两个信息源缺互斥。**

**我们的做法**：字段被标 too complex 时显示「无法计算」，**不显示 None 文案**。按 M1 第 (4) 类记录。

#### 回归测试用例（14 个）

```
x^2-2  1/x  sin(x)  tan(x)  x^3-2x  abs(x)  sqrt(x)  x+1/x
(x^2-1)/(x-1)  1/(x^2+0.01)  sin(1/x)  sin(x)+sin(pi*x)  5  e^x
```

**验收标准**：全部 14 case 无 🔴（错误值）。🟡（格式差）和 ⬜（缺失）单独跟踪。

**完成记录（2026-07-31）**：两份文件已落地——`spec/kgf-reference.md`（格式规格 + 14 case
原版/我方对照，实测格与未存档格如实区分）+ `tests/kgf-regression/*.json`（14 个期望
文件，`KGFRegressionTests` 逐字段断言）。验收达成：无 🔴；🟡 清单在规格 §4.5；
⬜（trig 极值/单调性通解族）按 S3「暂不做」记录，属第二阶段。

**属性断言（补充手段）**——注意必须相对化：

```
❌ 无效：  |f(root)| < ε          没有量纲归一化
✅ 有效：  |f(root)| / (‖f‖_∞ · 尺度) < ε
     或：  |f(root)| / |f'(root)| < ε      （估计根的实际误差半径）
```

**成本**：3–5 人日（规格整理）+ 随 S3 一并验收

---

### S10 · 黄金测试与标量一致性 ✅ 已完成（2026-07-31）

配合 D9：

```
tests/golden/scalar_vectors.txt    输入 + 期望输出（十六进制浮点，避免十进制舍入干扰）
```

覆盖：
- 超越函数边界（`sqrt(4)`、`sin(π)`、`ln(e)`）
- 灾难性抵消（`(1-cos x)/x²` 小 x、`sqrt(x+1)-sqrt(x)` 大 x）
- 极大极小值、进制转换往返
- 那 7 个鸿蒙失败测试涉及的输入

**CI 在 x86-64 / aarch64 / WASM 上跑同一份向量，要求逐位一致。** 不一致 = 移植 bug，不是"平台差异"。

**双构建 job**：`default`（double）+ `CALC_USE_EXTENDED_FLOAT`。后者允许失败但要报告差异，防止逃生通道腐烂。

**CI 检查**：`grep -rn "long double" src/ | grep -v CalcScalar.h` 必须为空。

**Ratpack 闸门** 🟠：精确有理数在连续运算下分子分母指数膨胀，用户按住等号或滑块联动时会卡。

```cpp
constexpr size_t kMaxRationalDigits = 10000;   // 超限切浮点并置标志位
```

并把"已切换到浮点"状态**暴露给 UI**——不要在用户以为是精确值时悄悄给近似值（M4）。

**成本**：3–5 人日

**验收记录（2026-07-31）**：
- **D9 标量收敛**：新增 `src/CalcManager/CalcScalar.h`（`calc_float` = double 默认，
  `CALC_USE_EXTENDED_FLOAT` 下切 boost `cpp_bin_float_double_extended`，
  `static_assert(sizeof(double)==8)`）；`ratpak.h` 引入。`grep -rn "long double" src/`
  （豁免 CalcScalar.h 自身）已并入 `Tools/check_engine_cxx17.sh`，CI 每次跑。
- **黄金向量**：`tests/golden/scalar_vectors.txt` 45 条——E 记录走完整引擎命令流
  （超越函数边界 sqrt(4)/sin(π)/ln(e)/e、灾难性抵消 (1-cos x)/x² 与
  sqrt(x+1)-sqrt(x)、100! 极值、上下溢、程序员模式分组、7 个鸿蒙失败输入），
  R 记录进制转换往返，D 记录 IEEE 正确舍入运算（+−×÷/sqrt/strtod）的 %a 十六进制
  逐位断言。跑器 `src/MacEngineTests/GoldenScalarTests.cpp`（3 个用例）随
  `swift run engine-tests` 自动执行，74 例全绿。
- **跨架构 CI**：新增 `Tools/build_engine_tests_portable.sh`（纯 clang++，不经 SPM）
  + CI `engine-x64` job（ubuntu-latest，x86-64 Linux）——与 macos-26 arm64 的
  engine job 跑同一份向量，逐位一致才过。脚本本地仅在 arm64 macOS 验证通过
  （无 Linux 环境），glibc 差异以 CI 首跑为准。
- **Ratpack 闸门**：`trimit()`（mulrat/divrat/addrat/泰勒级数的公共汇点）加界：
  `g_ratio·cdigit > kMaxRationalDigits(10000)` 时对 pp/pq 做 TRIMTOP 式低位截断
  （低位并入 exp，保幅值），置粘滞标志。原版 trim 用 min(pp,pq)，q=1 整数链
  永不触发——10^12000 实测 cdigit 无界增长，闸门后 ≤8。标志经
  `rat_precision_limited()` → CalcSession → C ABI（`calc_precision_limited`）→
  ObjC 桥 → ViewModel `isPrecisionLimited` → 主显示"≈"角标 +
  VoiceOver 播报（`Mac_PrecisionLimited`，en/zh-Hans），Clear 时复位（M4）。
  单测：10^12000 触发 + 显示不变（1.e+12000）；7^100 不误触发。
- **诚实未消费项**：① D 段有意排除 libm 超越函数（sin/exp 等 1-ulp 平台差异，
  IEEE 不要求正确舍入）——超越一致性由 E 段经 Ratpack 纯整数泰勒级数保证，
  理由写在向量文件头；② WASM CI 腿未建（无 Emscripten 工装，待 Web 平台任务）；
  aarch64-Linux 腿**已建**（2026-07-31 订正：GitHub 自 2025 年起对公开仓库免费提供
  arm64 托管 runner `ubuntu-24.04-arm`，engine-arm64 job 已加入，与 macos-26 arm64
  构成"同架构、不同 libc/工具链"（glibc vs Apple）交叉验证；OHOS 的 musl 差异
  仍只能由 P-OHOS 真机/qemu 验证）；Windows arm64 腿**待办**——`windows-11-arm`
  已 GA 且公开仓库免费，镜像预装 LLVM 20.1.6 + VS2022 Enterprise（含 ARM64 工具链），
  可行性高，但 `Tools/build_engine_tests_portable.sh` 需加 Windows 分支
  （MSVC 环境初始化 + clang++ 链接，或改 clang-cl），且 Windows 是第三套 libc
  （ucrt），价值在工具链维度而非架构维度（架构已被 arm64 双腿覆盖）；
  ③ `CALC_USE_EXTENDED_FLOAT` 双构建 job 未建——boost 未 vendor 进仓，逃生通道
  目前只有 typedef 本体 + static_assert，"防腐烂"的 CI 消费待真实需要 80-bit
  的平台出现时补；④ 粘滞标志是引擎全局（Ratpack 无会话上下文），多会话场景
  （目前不存在）需重审；⑤ "≈"角标经单元/逻辑链路验证，无自动化 UI 截图比对。

---

### S11 · `@Observable` 迁移 ✅ 完成（2026-07-31）

51 处 `@Published` + `ObservableObject` 来自 **Combine**，而 Combine 是闭源 Apple 框架，Linux / Windows / Android 的 Swift 上不存在。Swift 的 Observation 模块是开源的、随 corelibs 分发。

**收益**：2,178 行 ViewModel 从"Apple 专属"变成"任何跑 Swift 的地方都能用"。

**成本**：2–3 人日（机械替换 + 回归测试）

**执行记录（2026-07-31）**：用户调研后决定放弃 macOS 13 支持，解除暂缓前置约束：
- Package.swift 部署目标 **13.0 → 14.0**（并同步更新注释）。
- 4 个 ViewModel（`StandardCalculatorViewModel` / `GraphingViewModel` / `UnitConverterViewModel` / `DateCalculatorViewModel`）`ObservableObject` → `@Observable`，51 处 `@Published` 全部去掉修饰符，`private(set)` 语义保留。
- 视图层：30+ 处 `@ObservedObject` 改 `let`（只读即自动跟踪）；`@StateObject` 改 `@State`；需写绑定的 `$x.prop`（`DateCalculatorView`、`ProgrammerCalculatorView` 的 `$model.shiftMode`、`GraphingView` 的 `$graph.equations`、`GraphingSettingsPanel` 的 `$graph.trigMode/lineWidth`）在对应作用域内声明局部/存储 `@Bindable`。
- 清理 PlatformCompat.swift 的 macOS 13 回退分支（`onChangeCompat` / `defaultTrailingScrollAnchor` / `arrowKeyNavigation` / `CalcEmptyState` 删除，调用点改用 14 API），文件头注释同步更新；`ArrowKey` 枚举保留（GraphCanvas 方向键移动复用）。
- 验证：`swift build` + 126 测试全绿；全库无 `ObservableObject`/`@Published`/`Combine` 残留（唯一命中是测试文件的说明性注释）。
- 附带收益：ViewModel 与 SwiftUI/Combine 解耦，纯逻辑可在非 UI 环境复用。

**历史暂缓依据（2026-07-31，已解除）**：`@Observable` 宏与 SwiftUI 自动观察追踪在 Apple SDK
中标注 **macOS 14.0+**，而原部署目标是 **macOS 13**。带着 13 迁移只有两条路：
① 升部署目标到 14 —— 砍掉 macOS 13 用户，是产品决策，不在本清单授权范围；
② 双实现（`@available(macOS 14, *)` 的 Observable 版 + Combine 回退版）——
ViewModel 全量翻倍，与"机械替换 2–3 人日"的前提矛盾，且回退版仍依赖 Combine，
跨平台收益为零。另外收益前提"共享 Swift ViewModel"目前不存在：各平台按 §6
走 Kotlin/ArkTS/TS 消费 C ABI。→ 用户 2026-07-31 决定放弃 macOS 13（调研确认无
保留必要），原方案按机械替换执行，成本估计不变。

---

### S12 · 快捷键跨平台冲突矩阵 ✅ 已完成（2026-07-31）

129 项在各平台冲突情况不同。建立三层结构：

```
默认安全  →  平台冲突（需改键）  →  用户可覆盖
```

已知冲突集合：

| 平台 | 不可用 / 不可拦截 |
|---|---|
| **Web（最严重）** | `Ctrl/Cmd + W T N L D R P S O U`、`F5`、`Ctrl/Cmd+Shift+T`、`Ctrl/Cmd+Shift+I/J/C`、`Alt+←/→` |
| Android / 鸿蒙 PC | Home、Back、Recent、系统截图 / 锁屏 / 亮度 / 音量、`Alt+Tab`、`Meta` 组合、输入法切换 |
| Linux DE | `Alt+F2/F4/F7/F8`、`Super`、`Alt+F1`、`Ctrl+Alt+方向键`、`Ctrl+Alt+F1..F12`、截图 / 工作区 / 平铺 |
| macOS | 已解决（⌃ 字面映射，⌘ 放行给菜单栏） |

**输入法约束**：物理按键与 IME 文本提交必须分开处理，否则中日韩输入法的 composing 状态会被误当快捷键。

落地 `spec/shortcuts.json` + 各平台覆盖表。

**成本**：3 人日

**验收记录（2026-07-31）**：落地 `spec/shortcut-conflicts.json`（绑定清单已由 S6 的
`keyboard-shortcuts.json` 承担，本表是其上的平台覆盖层）。内容：三层语义
（safe / platformConflict / userOverridable）、五平台保留集合（macOS 标记
resolved、reserved 为空）、IME 约束（composing 让位 + 文本提交与 keydown
双通道，affects 覆盖全部 5 类字符分发通道）、9 组冲突条目——Web：⌘1-6→
Ctrl+Shift+数字（Ctrl+1..8 为标签切换）、Ctrl+L/R/P→Ctrl+Alt+同字母、F5→
Ctrl+Alt+5、科学 ⌃S/O/T/U/N/D→Ctrl+Alt+同字母、⌃⇧T/I/J→Ctrl+Alt+Shift+
同字母、置顶 notApplicable；Android/鸿蒙：F2-F12 requiresFn（媒体层优先）；
Linux：置顶 menuOnly（Ctrl+Alt+方向键被工作区抓取）。防漂移测试
`SpecTableTests.testShortcutConflictMatrixCrossReferencesBindings` 锁三条硬约束：
① 每个 ref 必须真实存在于 keyboard-shortcuts.json；② Web 保留集合与全部
现有绑定（menu/functionKeys/controlChords/科学 ⌃、⌃⇧ 和弦，cmd≡ctrl 归一化）
的碰撞必须被冲突条目全覆盖——新增绑定若撞保留集合即红；③ remap 目标不得
落回保留集合、平台内不重复、不与 Web 幸存绑定撞车。诚实记录未消费项：
Android/鸿蒙/Linux 的保留集合含"系统截图/工作区"等非和弦描述性词条，
不参与归一化碰撞检查（无绑定可撞，仅作用户覆盖时的拒绝依据，由各平台
实现期落地）；AltGr≡Ctrl+Alt 的欧洲布局歧义已在 web.notes 标注，属实现期
约束而非本表可验证项。

---

### S13 · 自绘区无障碍统一抽象 ✅ 已完成（2026-07-31）

绘图区自绘 → 对屏幕阅读器**完全不可见**。这是**三平台共同问题**：

| 平台 | 机制 |
|---|---|
| Web | Canvas bitmap 不进入无障碍树。需建立与绘制场景同源的语义 DOM / 覆盖层 |
| Android | 自绘 View 用 `ExploreByTouchHelper` 暴露虚拟节点 |
| HarmonyOS | `accessibilityVirtualNode(builder)`（API 11+）+ `OH_ArkUI_AccessibilityEventSetTextAnnouncedForAccessibility` |
| iOS/macOS | `UIAccessibilityElement` / `NSAccessibilityElement` |

**统一抽象**（语义树驱动绘制，而非绘制后从像素反推）：

```
SemanticNode {
  stableId, role, label, value, state,
  bounds, children, actions, traversalOrder
}
```

绘图区应暴露：当前视窗范围、光标坐标、极值 / 零点、选中曲线、缩放结果。

**成本**：1 人周（抽象层）+ 各平台 2–3 人日

**验收记录（2026-07-31）**：落地 `spec/graph-accessibility.json`（SemanticNode
字段表、6 角色 / 5 动作 / 5 状态词表、先序遍历规则、TODO 要求的五项暴露
requiredExposures、3 项事件播报 → String Catalog 键、四平台机制表）+ macOS
首实现 `GraphSemantics.swift`（GraphSemanticTree.build：视窗节点带缩放四动作、
方程节点带可见/错误/选中状态与 KGF featureGroup 子节点、跟踪节点带屏幕定位
bounds）+ `GraphingView` 画布接线（语义树先序展开为隐形 overlay 元素，
VoiceOver 可达，actions 映射为自定义动作，不拦截指针事件）。新增 l10n 键
`Mac_A11y_Equation`/`Mac_A11y_ResetView`（en+zh-Hans），根/视窗/跟踪节点复用
原版 `graphAutomationName`/`Mac_GridRange`/`Mac_TracePoint`。测试
GraphSemanticsTests 5 项：词表 spec⇄Swift 枚举逐项一致、spec 引用的全部
l10n 键真实存在于 String Catalog、默认树结构与 labelArgs、隐藏/错误/选中
状态 + 跟踪节点 (1,1)→(220,135) 定位、featureGroup 与先序遍历唯一性。
诚实记录：① featureGroup 无 bounds——giac 结果是符号串（如 x = π）无法
定位像素，属诚实建模；② macOS 画布接线传空 analyses（KGF 数据已由分析
面板文本行呈现，画布内重复注入属平台期决策）；③ hidden/error 状态在
macOS overlay 仅经动作名（显示/隐藏函数）间接可感知，SwiftUI 无对应
trait，Android/Web 虚拟节点有原生对应物；④ VoiceOver 端到端行为未做
自动化验证（需真机 AX inspector），结构正确性由单元测试锁定。

---

## 第四部分 · 各平台任务

每个平台统一使用以下小节结构。**未列出的小节不代表不做，代表沿用共享层。**

```
P-<平台>-0   可行性验证（bring-up spike）
P-<平台>-1   阶段一：五模式完整体
P-<平台>-2   阶段二：绘图完整体
P-<平台>-3   本地化 / 无障碍 / 键盘
P-<平台>-4   打包 / 签名 / CI / 分发
P-<平台>-X   豁免清单（必须写 M1 四类理由之一）
```

---

### P-macOS · 已有，需回填

阶段一、二均已完成，但共享层重构后需回填，且有 parity gap。

#### 已发现的 parity gap 🔴

| Gap | 说明 | 来源 |
|---|---|---|
| ~~线型只有 3 种~~（误诊，已订正） | 底层 `Renderer::LineStyle` 枚举有 5 种，但**原版用户可见 UI 恰只有 3 种**——`EquationStylePanelControl` 的 `allStyles` 只列 `Solid/Dash/Dot`；`GetLinePattern`/`GetLineAutomationName` 对 `DashDot`/`DashDotDot` 无 case（落到 default = 实线）；resw 只有 `solid/dash/dotLineStyleAutomationName` 3 个名、无任何 `DashDot` 字符串。fork 的实线/虚线/点线**与原版 UI 完全一致** | `EquationStylePanelControl.xaml.cs:22-29,90-126` + resw |
| **单调性缺 `Constant`** | 原版 `FunctionMonotonicityType` 有 `Constant`，resw 有 `KGFMonotonicityConstant`；实测 `5` 显示「恒定」 | 枚举 + 截图 |
| 渐近线方向语义 | 枚举有 `AsymptoteType{PositiveInfinity, NegativeInfinity, AnyInfinity}`，但**实测 UI 不展示方向**（`e^x` 只写 `y = 0`） | 截图 |

→ 单调性 `Constant`**必须补**（已补，见下）；线型「gap」经核实为误诊——比对对象错为底层渲染器枚举，**原版 UI 只有 3 种线型，fork 已保真**，补 DashDot/DashDotDot 反而制造背离（违反移植保真目标，M4）；渐近线方向**不做**（原版 UI 不展示，照抄即可）。

#### 回填任务

- [x] 改用共享层规格表（键盘 / 单位 / 快捷键 / 色板 / 模式元数据）（2026-07-31 全部完成）：模式元数据 / `LayoutTier` 分档 / 图标语义名 / 14 色方程色板 / 单位换算表此前已由各自镜像表消费（见 §S6 验收）；本次补齐**最后一张**——键盘布局。新增 `KeyboardLayout.swift`（Swift 镜像五元组表 + `KeypadRenderer` 解析 + `KeypadGrid` 数据驱动渲染循环），四套键盘（标准/科学/程序员/换算）视图内 57 处 `CalcKey(` 手写调用全部退化为消费 `KeyboardLayout.{standard,scientific,programmer,converter}` 的单一渲染循环。严格零回归保真：标准模式字号仍由 `LayoutTier` 驱动（含 `compactFirstRow` 紧凑首行交换）、科学/程序员/换算字号为镜像常量、移位键字号按标签长度动态、`emphasized` 态随 `isInvChecked`、闪动仅标准模式、全部 disabled 谓词逐键映射 JSON 规则；`ScientificCalculatorView.functionColumn` 改为从 `KeyboardLayout.scientific` 派生（单一真相源）。`SpecTableTests.testKeyboardLayoutMirrorMatchesSpec` 双向锁定镜像表 ⇄ `spec/keyboard-layout.json`（kind/style/command/a11y/disabled/colSpan/invPair/行跨度守恒/紧凑首行）。零回归：`swift test` 126/126（含新增镜像测试）、engine-tests 全绿
- [ ] **平价测试退役**（与 Swift 首发实现退役绑定，D6 纪律）：`MarchingSquares.swift`（对拍 oracle）、`GraphingView`/`GraphingViewModel` 内残留 Swift 公式实现删除时，`GraphGeometryTests` 12 项平价断言同步处理——有独立行为价值的（`y=1/x` 断裂/抬笔、鞍点消歧、不等式三值覆盖、auto-fit 退化）翻译为 C 层直接行为断言，其余随实现删除
- [ ] **C 层直接测试缺口**（承接上条）：Swift oracle 退役后 C 层行为回归网不得留白——`graph_sample_curve` 断裂、`graph_marching_squares` 鞍点、`graph_inequality_regions` 三值输出需有**独立期望**的直接测试，不再依赖与 Swift 对拍；`GraphGeometryTests` 文件名与结构可随之改名（如 `GraphGeometryCApiTests`）
- [x] 改用 C ABI 门面（2026-07-31）：`CalcManagerBridge.mm` 不再直接持有 `std::unique_ptr<MacCalc::CalcSession>`，改持 `calc_session_t*` 并全程委托 `calc_c_api`——ctor 用 `calc_grouping_format` + `calc_locale_t`（UTF-8）注入区域，`calc_callbacks_t` 装配 11 个 C thunk（`user_data` 为未持有的 bridge，无保留环）转发回 ObjC block，33 个方法逐一改调 `calc_*`（返回 `char*` 经 `calc_string_free` 释放）。至此 `calc_c_api` 成为 CalcSession 的**唯一**包装，跨平台 C 契约由 macOS 生产路径实际消费验证（消灭 mm 与 c_api 两套平行门面的重复）。零回归：`swift test` 126/126、engine-tests、calc-smoke（经 C ABI 显示/历史/进制端到端）全绿
- [x] 图形几何改调共享层（2026-07-31）：生产路径的坐标变换（`toScreenX/Y`→`graph_to_screen_x/y`）、刻度步长（`niceStep`→`graph_nice_step`）、网格刻度枚举（`drawGrid`→`graph_ticks`）、显式曲线采样（`drawCurve`→`graph_sample_curve`）、隐式等值线追踪（`drawImplicit`→`graph_marching_squares`）、视窗平移/缩放/范围（`pan/zoom/zoom_at/applyRange`→对应 C ABI）全部改调 `graph_geometry.h`。`MarchingSquares.swift` 降级为对拍 oracle（`GraphGeometryTests`/`MacAppTests` 锁 C↔Swift 等价）。零回归：`swift test` 126/126、engine-tests、calc-smoke 全绿
- [x] `@Observable` 迁移（2026-07-31，S11：部署目标 13→14，4 个 ViewModel + 全部视图层，126 测试全绿）
- [x] ~~补 2 种线型~~ → 经核实无需补（2026-07-31）：原版 `EquationStylePanelControl` 用户可见 picker 只列 `Solid/Dash/Dot`，`DashDot`/`DashDotDot` 是底层渲染器枚举、UI 从不暴露（无 pattern、无 automation name、resw 无对应字符串）。fork 3 种线型即 UI 保真；补 2 种反成背离
- [x] 补单调性 `Constant`（2026-07-31，S3 重写附带：常函数短路径给出 `(-∞, +∞) 恒定`）
- [x] 分组模式改用结构（S8，2026-07-31：mm 桥经 MacCalc::Grouping + NumberFormatter 双组尺寸注入）
- [x] 14 函数回归测试全绿（2026-07-31，随 S3+S9 完成，见 `tests/kgf-regression/`）

**验收硬指标**：回填后 macOS **零功能回归**——这是共享层设计正确性的试金石。

#### 已有豁免（沿用，理由已记录）

| 特性 | 理由类别 |
|---|---|
| 按键声效 AuditoryFeedback | (1) 平台无对应物 |
| GraphingNumPad 触屏虚拟键盘 | (1) macOS 有实体键盘 + MathLive 虚拟键盘 |
| EULA / 服务协议 / 隐私声明 / 反馈 Hub | (1) 微软法务文书 |
| 汉堡导航 / TitleBar.xaml | (2) 交互 chrome 按 macOS 惯例重制 |
| 微软零售汇率端点 | (3) 无授权 |
| CompactOverlay 迷你键盘 | (1) Windows ApplicationView 覆盖态特有；macOS 惯例是 `NSWindow.level = .floating` 不改布局 |
| 千位分隔符开关 | **基线不存在**（原版 Settings.xaml 无此开关，分组来自 OS 区域设置） |

---

### P-Windows · UI 零成本，但需限定表述

**关键事实**：上游 CI 仍在最新 runner（`windows-2025-vs2026`，.NET 10.0.x）上成功构建 `.slnx`，矩阵含 x64/x86/ARM64 + 单元测试 + UI 测试。

**但必须准确表述**：它仍是 **UWP/XAML 工程**，不是 WinUI 3 / Windows App SDK。

> 「Windows UI 零成本」的准确含义是「**已有 UWP UI 可继续构建**」，
> 不是「已有现代桌面架构」。现代化是另一笔预算。

#### P-Windows-0 · 可行性验证
- [ ] 本机打开 `src/Calculator.slnx` 构建成功
- [ ] 记录所需 VS / SDK 版本

#### P-Windows-1/2 · 五模式 + 绘图
- [ ] **UI 一行不动**
- [ ] 实现 `IMathSolver` / `IGraphAnalyzer`（`src/GraphingInterfaces/`，1,069 行接口已由微软定义好）
- [ ] 替换 `src/GraphingImpl/Mocks/MathSolver.cpp` 桩实现
- [ ] 接 giac（复用 `GiacMathSolver` 的查询逻辑，从 Swift 翻回 C++）

**这一步的公开价值最高**：上游社区构建至今没有绘图功能（README 明说专有引擎不在仓库里、开发者构建用 mock）。完成后是**第一个带完整绘图的开源 Windows 计算器**。

#### P-Windows-4 · 分发
- [ ] GitHub Release（GPLv3 侧载无障碍）
- [ ] 不进 Microsoft Store（GPL 冲突）

**成本**：1–2 人周（UI 零成本，只写求解器接入）

---

### P-iOS/iPadOS

#### P-iOS-0 · 可行性验证
- [ ] SwiftUI 视图在 iOS 上编译
- [ ] giac 交叉编译 iOS arm64 + 模拟器切片 → XCFramework
- [ ] **gmp/mpfr/gettext 一并交叉编译**（当前 `Package.swift` 的 `-L/opt/homebrew/lib` 硬编码必须参数化）

#### P-iOS-1 · 五模式完整体
- AppKit → UIKit 映射：
  - `NSPasteboard` → `UIPasteboard`
  - `NSViewRepresentable` → `UIViewRepresentable`
  - `NSColor` → `UIColor`
  - `NSVisualEffectView` → `UIVisualEffectView` / `.regularMaterial`
  - `NSAccessibility.post` → `UIAccessibility.post`
  - `NSEvent` 监听 → `.onKeyPress`(iOS 17+) / `UIKeyCommand`
- **触屏适配是真工作量**：位翻转面板（64 个可点位）、单位换算双栏在 iPhone 竖屏必须重排
- 窗口概念消失：`Settings` scene → 应用内设置页；`.windowResizability` / 置顶 → 删除或改 iPad 多任务语义
- **豁免回收**：`GraphingNumPad`（macOS 豁免的触屏虚拟键盘）**在这里必须做回来**，理由类别 (1) 不再成立

#### P-iOS-2 · 绘图
- SwiftUI Canvas 直接复用
- 触屏缩放 / 平移手势替代鼠标

#### P-iOS-4 · 分发
- [ ] 完整版（giac，GPLv3）：未签名 ipa 走 GitHub Release
- [ ] lite 版（MIT）：保留可上架能力

**成本**：阶段一 2 人周｜阶段二 2–3 人周

---

### P-Android

#### 架构决定（已定）

- **UI：Jetpack Compose（Kotlin）**
- **逻辑：JNI 直连共享 C++**，不走 Swift-Android
  - 理由：Swift 6.3 虽有官方 Android SDK，但**不含 SwiftUI**、IDE 调试未完成。UI 无论如何要用 Compose 写，Kotlin + JNI 是更短路径，少一整条工具链风险
- **绘图：原生 Compose Canvas，不用 Skip.tools**
  - 理由：`skip-ui` 的 `Canvas.swift` / `GraphicsContext.swift` 主体整个被块注释掉、内部 `fatalError()` 占位。**证据充分，这条定死**

#### 设计语言：Material 3 Expressive

**参照物**：Google Calculator 9.0（2025-08 的 M3 Expressive 改版）——去掉模拟显示屏容器改扁平背景、数字用更窄字体、科学函数键改独立药丸形按钮并默认折叠、历史入口移到左上角。

| 元素 | macOS | Android |
|---|---|---|
| 按键形状 | Liquid Glass 胶囊 | M3 药丸形 + tonal 配色（M1 类别 (2)） |
| 运算符强调色 | 系统橙 | **Material You 动态取色（Monet）**，不硬编码 |
| 模式切换 | 顶栏钮 + Menu | NavigationBar / SegmentedButton |
| 历史面板 | 右侧停靠 / Popover | **BottomSheet** |
| 设置 | Settings scene ⌘, | Settings Activity |
| 触觉反馈 | macOS 已豁免 | **应该做**（`HapticFeedbackConstants`，平台惯例） |

#### 分发
- Play Store **接受 GPL**（已确证：KDE Connect GPL-3.0-only 在 AppGallery/Play 上架）→ **完整版可正常上架**

**成本**：阶段一 4–6 人周｜阶段二 4–6 人周

---

### P-Linux

#### 架构决定（已定）

- **Qt 6 Widgets**（不是 QML，不是 GTK4+libadwaita）
  - libadwaita **刻意不支持主题化**，在 KDE 上明显外星化，用户需 `GTK_THEME=Breeze` 这类非官方 hack 且随 GTK 更新易坏
  - Qt **有跨 DE 适配的意愿和机制**（QPA platform theme 插件体系）
  - Widgets 走系统 style 引擎（Breeze / Fusion / adwaita-qt），QML 默认自绘反而不原生
  - 附带：Qt 是 C++，直接吃共享层，零绑定层

#### 设计原则：主动放弃设计权

- **不定义任何自己的视觉语言**，用标准控件让 style 引擎决定圆角 / 阴影 / 配色 / 字体
- **绝不自绘按钮**——Liquid Glass、M3 药丸在这里都不移植。一自绘就在所有 DE 上都变成外来应用
- 强调色用 `QPalette::Highlight`
  - ⚠️ **但它不保证等于系统强调色**（GNOME/XFCE 下取决于 platform theme）→ 降级为「合理默认 + 允许应用内自选」
- 唯一自己决定的是**布局**，直接沿用 XAML 规格
- 遵守 freedesktop：`.desktop` 文件、XDG 目录、XDG Portal 文件对话框

#### giac
`apt install libgiac-dev` 现成，**连交叉编译都省了**。这是所有平台里 giac 最省事的一个。

#### 分发
Flathub / AUR，GPLv3 在这里是主流不是问题。

**成本**：阶段一 4–6 人周｜阶段二 3–4 人周

---

### P-HarmonyOS

#### 已实测的既成事实（不必重新验证）

| 项 | 结果 |
|---|---|
| SDK | **6.1.0.31 免登录下载**（`repo.huaweicloud.com/openharmony/os/6.1-Release/`，2.5 GB，另有 `L2-SDK-MAC-M1-PUBLIC` 专供 Apple Silicon） |
| 编译器 | **clang 15.0.4**（实测 `clang++ --version`） |
| 引擎编译 | **29/29 通过**（`--target=aarch64-linux-ohos -std=c++20`），产出 1.2 MB `libCalcManager.a` |
| 引擎运行 | 冒烟测试 3/3 PASS（qemu-aarch64） |
| musl | `wchar_t` = 4 字节；`setlocale(fr_FR.UTF-8)` → **NULL**；`wregex` 可用；异常（std / 自定义 / int）三种全部正确捕获 |
| GMP 6.3.0 | **交叉编译成功并执行正确**（需 `--disable-assembly` + 换 2025-07-10 版 `config.sub`） |
| MPFR 4.2.2 | **交叉编译成功并执行正确**，零额外坑 |
| gettext | **不需要**（现有 `build_giac.sh` 已有 `--disable-nls`） |
| vcpkg | 有 `arm64-ohos` triplet，但 gmp port 在 OHOS 上失败（ARM64 汇编）→ **走手工路径，35 秒编完两个库** |
| `tpc_c_cplusplus` | 264 个 port，只有 gmp 相关 |

#### ⚠️ 工程注意事项

**CI 缓存 OHOS SDK 时，别用会过滤 `build/` 目录的缓存规则**——`native/build/ohos.toolchain.cmake` 是交叉编译的关键文件。（本轮沙箱被此坑两次。）

#### P-OHOS-0 · 可行性验证（剩余）

- [ ] **giac 本体交叉编译**（依赖已就位，配方见下）
- [ ] XComponent + OH_Drawing 画一条 `y = sin(x)`，加拖动平移，看帧率（**需真机 / 模拟器，无法在沙箱验证**）
- [ ] 真机上补跑完整 71 例测试套件（qemu 下 42 PASS / 7 FAIL，归因未定，见 §5）

**giac 配方**：

```bash
N=<ohos-sdk>/native
export CC="$N/llvm/bin/clang --target=aarch64-linux-ohos --sysroot=$N/sysroot"
export CXX="$N/llvm/bin/clang++ --target=aarch64-linux-ohos --sysroot=$N/sysroot"
export AR=$N/llvm/bin/llvm-ar RANLIB=$N/llvm/bin/llvm-ranlib
export CFLAGS="-fPIC -O2" CXXFLAGS="-fPIC -O2"

# 每个 autotools 包解包后第一件事（否则 configure 拒绝 ohos）
curl -sLO https://raw.githubusercontent.com/autotools-mirror/autoconf/master/build-aux/config.sub
curl -sLO https://raw.githubusercontent.com/autotools-mirror/autoconf/master/build-aux/config.guess
chmod +x config.sub config.guess

# giac：复用现有 build_giac.sh 的 --disable-* 串，去掉 --disable-cocoa
./configure --host=aarch64-unknown-linux-ohos --disable-shared --enable-static \
    --disable-fltk --disable-gui --disable-ntl --disable-pari --disable-gsl \
    --disable-lapack --disable-ecm --disable-bernmm --disable-glpk --disable-ao \
    --disable-samplerate --disable-curl --disable-micropy --disable-quickjs \
    --disable-nls --disable-png --disable-dl \
    CPPFLAGS="-I$PREFIX/include" LDFLAGS="-L$PREFIX/lib"
make -C src -j$(nproc) libgiac.la      # 只编库，不编 GUI
```

方法论参照 Servo：建一个依赖 libgiac 的 dummy target，逐个修编译和链接错误。giac **没有手写汇编**，比 gmp 简单。

#### 分支

```
giac 编得出 → 完整版（含分析面板）
giac 编不出 → lite 版（绘图完整，无分析面板）
```

（你的判断：倾向能编出来，只有做了才知道。此分支为保险，非预期结果。）

#### P-OHOS-1/2 · UI

- **ArkTS / ArkUI**，声明式 + 响应式状态管理，`@State`/`@Link` 对应 SwiftUI 的 `@State`/`@Binding`——**从 SwiftUI 翻译过去心智负担是非 Apple 平台里最小的**
- **绘图走 XComponent + OH_Drawing**（type: SURFACE），C++ 直接画到 surface，绕开跨语言数据传输
  - API 19+ XComponent 支持 Native 侧注册触摸 / 鼠标 / 按键回调 → **缩放平移手势也在 C++ 闭环**
  - 依赖：`libace_napi.z.so` / `libace_ndk.z.so` / `libnative_window.so` / `libnative_drawing.so`
- **不要逐点跨 NAPI 传坐标**。若必须传批量数据，用 `napi_create_arraybuffer` + `Float32Array`（4000 点 ≈ 32 KB/帧）
- 多设备形态适配：断点 + 栅格（`GridRow`/`GridCol`），**不是四套 UI**，约 1.3–1.5 套的量
  - 注意：只选手机发布时，平板/PC 上搜不到；但选了手机可能以兼容模式分发到平板

#### STL 与链接

```
OHOS_STL = c++_static    ← 前提：锁死"只有一个业务 .so"
+ -fvisibility=hidden -fvisibility-inlines-hidden
+ 只导出 napi_module_register
```

一旦出现第二个 `.so`，必须全部切 `c++_shared`——否则两份 libc++ 全局状态 → **异常无法跨 .so 边界捕获**（对本引擎尤其致命）、`dynamic_cast` 失败。

#### 分发
- 侧载：实名开发者调试证书 1 年 / 100 台设备（未实名 14 天）
- ⚠️ **纯净模式**会拦截非市场来源，用户需手动关闭并输入锁屏密码
- AppGallery：条款偏可行（渠道风险提示 ≠ 用户权利限制，性质接近 Google Play），**已有 GPL 先例**（KDE Connect，AppGallery ID `C104724723`）

**成本**：阶段一 6–8 人周｜阶段二 4–6 人周｜giac 移植 1–2 人周

---

### P-Web

#### 技术选型（已定）

- **Lit（~5 KB）+ 全部 CSS 自写 + 原生 Canvas 2D**
  - Lit 是原生 Web Components 的薄封装，**零视觉**，只提供响应式属性 + 增量 diff——正好是"手搓不稳健"的两个来源
  - 纯 vanilla 的问题是**你会自己把 Lit 写一遍**
  - **拒绝任何现成组件库**（MUI / shadcn / Bootstrap）——那才是"平庸"的来源
  - 图表库一律不要（已有 marching squares / niceStep / 坐标变换）

#### 求解器：**lite 版**（唯一以 lite 为默认的主线平台）

理由：Web 是唯一零分发摩擦的平台，也是唯一真在乎体积的平台。

#### Emscripten 异常配置 🔴 重要纠正

**不能用 `-fno-exceptions`。**

引擎的错误处理是**结构性依赖异常**的：`CalcErr.h` 明说这些错误码是 "thrown by ratpak and caught by Calculator"，抛的是**裸 `uint32_t`**（不是 `std::exception`）。抛出点遍布 `rat.cpp` / `logic.cpp` / `fact.cpp` / `conv.cpp` / `scioper.cpp` / `exp.cpp` / `trans*.cpp` / `Rational.cpp`；捕获点在 `scioper.cpp` / `scifunc.cpp` / `Rational.cpp` / `RationalMath.cpp` / `scicomm.cpp`：

```cpp
catch (uint32_t dwErrCode) { DisplayError(dwErrCode); }
```

关掉异常 → 除零时不是显示 "Cannot divide by zero" 而是直接 abort。

| 模式 | 结论 |
|---|---|
| `-fno-exceptions` | ❌ 破坏引擎错误处理 |
| 默认 `DISABLE_EXCEPTION_CATCHING=1` | ❌ 同上 |
| `-fexceptions`（旧 JS 方案） | 🟡 可用但体积大、慢 |
| **`-fwasm-exceptions`（原生 WASM EH）** | ✅ **推荐**，Chrome 95+ / FF 100+ / Safari 15.2+ 全支持 |

**体积优化从别处找**：`-Oz`、`-flto`、`-DNDEBUG`、`--closure 1`、`-sMODULARIZE` + 按需实例化。

#### 设计：以 macOS 版视觉为基准做克制现代化

Web 是唯一必须自己做设计决策的平台（Windows 有 XAML、Apple 有 HIG、Android 有 M3、Linux 交给 DE）。

| 方面 | 做法 |
|---|---|
| 配色 | 保留 macOS 的灰阶层级逻辑，CSS 自定义属性 + `prefers-color-scheme` 双主题 |
| 材质 | **不模仿 Liquid Glass**（`backdrop-filter` 性能差且像廉价仿制），用纯色 / 微妙渐变 |
| 字体 | `system-ui` 栈——macOS 上是 SF、Windows 上是 Segoe、Android 上是 Roboto，**自动获得平台原生感** |
| 焦点态 | `:focus-visible` 环必须清晰（Web 无障碍硬要求，桌面 app 能偷懒，Web 不行） |
| 触摸 | 移动浏览器上按键最小 44×44 CSS px |
| 动效 | 全部包在 `@media (prefers-reduced-motion: no-preference)` |
| HiDPI | `devicePixelRatio` + `ResizeObserver`，每次 resize 后重设 transform |

#### 真正让它不像"在线计算器"的是行为，不是视觉

- **129 项键盘快捷键**——网页计算器几乎没人认真做键盘，这一条就足以拉开差距（注意 S12 的浏览器占用键）
- **URL 携带算式** `?e=sin(x)/x` 直接出图——**只有 Web 能做**
- **PWA 离线**，装到 Dock 后无浏览器 chrome
- **MathLive 在这里是原生的**（本来就是 Web Component），零代价

**成本**：阶段一 4–6 人周｜阶段二 3–4 人周

---

### P-CLI/TUI · 白送

`src/CalcManager/smoketest/main.cpp` 已是雏形。ratatui / ncurses，共享层的最小验证载体。

**成本**：2–4 人日

---

## 第五部分 · MathLive / WebView 决策

**现状**：全仓库只有 `MathInputField.swift`（91 行）用 WebKit，用途是 MathLive 公式编辑器。

**关键事实**：原版用的是 **`MathRichEditBox`**（原生富文本控件）。**MathLive + WebView 本身就是对 XAML 的偏离**，是当初为 macOS 便利做的选择。

**各平台原生数学输入控件调研结论**：Android / HarmonyOS / Qt / GTK **都没有系统级 MathLive 等价物**。Qt 有 JKQTMathText（可渲染 LaTeX 子集，但不是 WYSIWYG 编辑器）；GTK 有 GtkMathView（老旧，非 GTK4）。

**决定：分离"输入"与"渲染"**

| 平台 | 方案 | 理由 |
|---|---|---|
| Windows | 原版 `MathRichEditBox` | 对齐 XAML |
| Web | MathLive（原生 Web Component） | 零代价 |
| macOS | **保持现状**（MathLive + WKWebView） | 已跑通，不破坏可用的东西 |
| iOS / Android / 鸿蒙 / Linux | **原生文本框 + 线性语法 + 只读渲染** | 避免 WebView；Linux 尤其（QtWebEngine 是一整个 Chromium） |

线性语法（`x^2+3x-2`、`sqrt(x)`、`pi`）正是 Desmos 的输入方式，也是现有 ASCIIMath 归一化已在处理的格式。**在移动端比二维公式编辑器更好用**（不用在小屏上导航分式的分子分母）。

⚠️ 现有 TODO v1 的"待人工真机确认"清单里就有「MathLive 聚焦/输入体验」——说明 WebView 方案在 macOS 上可能已有摩擦。**决策前先在真机试一次。**

---

## 第六部分 · 跨平台功能矩阵

```
行 = 功能    列 = 平台    格 = ✅完成 / 🚧进行中 / ⬜未开始 / ❌豁免（附理由链接）
```

| 功能 | macOS | Win | iOS | Android | Linux | OHOS | Web |
|---|---|---|---|---|---|---|---|
| 标准模式 | ✅ | ✅原版 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 科学模式 | ✅ | ✅原版 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 程序员模式 | ✅ | ✅原版 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 日期计算 | ✅ | ✅原版 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 单位换算 | ✅ | ✅原版 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 绘图渲染 | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| **函数分析面板** | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | **❌lite** |
| 129 快捷键 | ✅ | ✅原版 | 🚧部分 | 🚧部分 | ⬜ | ⬜ | 🚧受限 |
| 60 语言 | ✅ | ✅原版 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 无障碍播报 | ✅ | ✅原版 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 自绘区无障碍 | ⬜ | ✅原版 | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 汇率 | ✅ | ❌端点 | ⬜ | ⬜ | ⬜ | ⚠️见下 | ⬜ |

---

## 第七部分 · 已知风险与待查

### 🟠 汇率 API 在中国大陆的可达性

现有三级降级链：

```
latest.currency-api.pages.dev  ← Cloudflare 官方说明 pages.dev 不在中国大陆提供服务
cdn.jsdelivr.net               ← 曾失去中国 ICP，有中国用户无法访问的实际报告
api.frankfurter.dev            ← 无中国可达性或 SLA 承诺
```

**鸿蒙用户几乎全在国内** → 货币类别大概率不可用。同样影响 iOS / Android 国行设备。

**对策**（不是找第四个源，而是改架构）：
1. App 内置带日期的汇率快照
2. 每次成功更新写入持久缓存
3. 超过阈值明确显示「最后更新于 …」
4. **多源竞速**而非串行长超时
5. 完全离线时**允许用旧数据换算，不直接禁用 UI**

**风险备忘**（沿用 TODO v1）：fawazahmed0 是个人项目曾被下架，缓存 + 兜底不可省；加密货币汇率必须显示时间戳。

### 🟡 7 个 qemu 测试失败（归因未定）

**现象**：引擎交叉编译到 aarch64-OHOS 后，qemu 下 71 例套件跑出 42 PASS / 7 FAIL，最后一个测试处挂起。同源码在 x86-64 Linux 上 71 PASS / 0 FAIL。

**已知线索**：
- 失败全集中在 `CalculatorManagerTest` 这一个 fixture（另外三个全绿）
- 该 fixture 是唯一用 static `shared_ptr` 跨测试共享状态的
- 5 个失败消息为空（`Assert::Raise(nullptr)`），2 个 "unknown exception"（shim 的 `catch(...)` 兜底 → 引擎抛了 `CALC_E_*`）
- **手工重跑失败测试的确切命令序列，引擎算得完全正确**（`123.456` 和 `3` 都对）

**两个假设**（待验证）：
1. **`long double` 平台差异**——MSVC 64 位 / x86-64 80 位 / aarch64 128 位软件模拟。若引擎依赖它，同一表达式在不同平台给出不同结果
2. 测试隔离缺陷——`Cleanup()` 未复位干净

**验证方法（本机十秒）**：
```bash
grep -rn "long double\|LDBL_\|%Lf\|strtold\|powl\|sqrtl\|sinl" src/CalcManager/
```

**注意**：不能在真机验证前声称"真机上会消失"。没有找到"qemu-user 导致 static `shared_ptr` 跨测试错误共享"的已知通用问题。

### 🟡 其余待查

| 项 | 为什么 |
|---|---|
| Skip.tools `Canvas.swift` 注释状态抽查 | 结论影响 Android 架构，值得亲眼确认（虽已有强证据） |
| ChebTools / Eigen 在各平台的实际编译 | 仅在 lite 版恢复分析能力时才需要（当前已归档） |
| 60 语言资源转换脚本 | 建立 ICU MessageFormat + CLDR 中间格式，再生成各平台格式。**不能正则盲换占位符** |
| 鸿蒙 CI（`hvigorw` 无头构建 + 签名注入） | 已知可行（ServoDemo 有 Linux 实践），需落地 |
| iOS 侧载现状（AltStore PAL / 欧盟 Web Distribution） | 影响完整版分发渠道 |

---

## 第八部分 · 废案索引

`docs/rejected/numeric-solver.md` —— MIT 数值求解器（2026-07 评估，未采用）

**一句话摘要**：为绕开 GPLv3 与 App Store 冲突而设计的宽松许可数值替代方案，因「对齐标准是符号形式（±√2、n₁∈ℤ 通解），数值方法原理上够不着」而否决，改为 lite 版整体不提供分析面板。

**已被主线吸收的部分**：区间算术（S4）、KGF 显示格式规格（S9）、原版三处 UI bug 及修正决定（S9）、QUADPACK 翻译注意事项、库许可证核实结论。

**重新启用的触发条件**：真要上 App Store 且用户明确需要分析面板 / 出现宽松许可的成熟 CAS / 某平台 giac 编不出来。

---

## 第九部分 · 推进顺序

```
第 0 阶段 · 共享层（4–6 人周）
  S1  两个 include 修复                    ← ✅ 完成（2026-07-31）
  S2  删除 GraphAnalyzer.swift             ← ✅ 完成（2026-07-31）
  S3  GiacMathSolver 诚实性加固            ← ✅ 完成（2026-07-31）
  S9  KGF 规格 + 14 函数回归测试           ← ✅ 完成（2026-07-31，随 S3 互为验收）
  S5  C ABI 门面                           ← ✅ 完成（2026-07-31）
  S6  规格表下沉                           ← ✅ 完成（2026-07-31）
  S7  图形几何下沉                         ← ✅ 完成（2026-07-31）
  S8  Locale 注入加固 + 分组模式修复       ← ✅ 完成（2026-07-31）
  S11 @Observable 迁移                     ← ✅ 完成（2026-07-31，部署目标 13→14）
  S4  区间算术                             ← ✅ 完成（2026-07-31）
       ↓
  验收硬指标：macOS 零功能回归 + 14 函数回归全绿

第 1 阶段 · Windows（1–2 人周）
  UI 零成本，是共享层设计的纯净试金石——
  设计错了会立刻暴露，而不是被"反正 UI 也要重写"掩盖

第 2 阶段 · iOS/iPadOS（4–5 人周）
  验证 SwiftUI 复用率 + 触屏适配
       ↓ visionOS 顺手评估（3–5 人日）

第 3 阶段起 · 按兴趣推进
  Android / Linux / HarmonyOS / Web
  （CLI/TUI 随时可插，2–4 人日）
```

**为什么第 1 阶段是 Windows**：它的 UI 成本是零，所以是一块纯净的试金石。如果共享层设计对了，接上求解器就能跑；如果设计错了，问题会立刻暴露。用它验证抽象，比用任何需要写 UI 的平台都干净。

---

**这份 TODO 的三个约束再强调一次**：M1（偏离必须属四类合法理由）、M3（完成度二值）、M4（诚实优先于完整）。前两条防偷懒，第三条防说谎。

