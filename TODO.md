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
- 只换"皮肤"层：SF Pro、系统强调色、`Material` 材质、跟随系统深浅色；
  用原生 SwiftUI 控件默认观感，**不模仿 Fluent**。
- macOS 惯例替换交互 chrome：
  - 汉堡导航 → `NavigationSplitView` 侧栏或工具栏模式切换；
  - 键盘快捷键进菜单栏（原版键盘映射表照搬）;
  - 置顶小窗（Always-on-Top）→ `NSWindow.level` 浮动窗口。
- `src/Calculator/DesignData/` 有现成设计时数据，用作 `#Preview` 素材。
- 本地化：海量 `.resw` 资源写脚本转 `.strings`/`.xcstrings`。

---

## 三、实施阶段（按序）

### Phase 0：骨架（1–2 周）
- [ ] 创建 Xcode 工程（SwiftUI App，macOS target）
- [x] 为 `CalcManager` 写 CMake 构建，在 macOS 编译通过
      （已完成：`src/CalcManager/CMakeLists.txt`；PPL 依赖用 `ppltasks_cross_platform.h` 垫片解决；
      冒烟测试 `smoketest/main.cpp` 在 arm64 通过：1+2=3、2*8=16、10/3=3.333333333333333）
- [x] **排查 `wchar_t` 坑**：macOS 上 4 字节 vs Windows 2 字节，全库重度使用 `std::wstring`，
      逐处核查 UTF-16 假设（Uno 移植踩过，可参考其补丁）
      （已完成：全库无 `sizeof(wchar_t)` 假设、无代理对处理、无 UINT16 强转；
      仅有 ASCII 范围的 `wchar_t` 运算（`CalcInput.cpp:63`），4 字节下安全。
      结论：引擎宽度无关，字符串转换统一在 Swift 桥接层处理）
- [ ] Swift/C++ interop 或 ObjC++ 桥接层，跑通"引擎算出 1+1"
- [ ] 迁移 `CalculatorUnitTests` 中引擎相关单测（转 XCTest 或保留 googletest）

### Phase 1：标准 + 科学模式（3–5 周）
- [ ] Swift 重写 `StandardCalculatorViewModel` 核心逻辑
- [ ] 标准模式 UI（含历史/内存面板）
- [ ] 科学模式 UI（含 F-E 切换、角度模式等）
- [ ] 键盘映射 + 菜单栏快捷键
- [ ] 复制/粘贴（对照 `CopyPasteManager` 的解析规则）
- [ ] 无障碍（VoiceOver，对照原版 Narrator/`NarratorAnnouncement` 行为）

### Phase 2：程序员 + 日期计算（2–3 周）
- [ ] 程序员模式（进制转换、位运算、位翻转面板）
- [ ] 日期计算模式

### Phase 3：单位/汇率换算器（2–3 周）
- [ ] Swift 重写 `UnitConverterViewModel` + `UnitConverterDataLoader`
- [ ] 汇率：按上文决策接 fawazahmed0 + Frankfurter 兜底 + 缓存
- [ ] 货币元数据改用 `Foundation.Locale`

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
