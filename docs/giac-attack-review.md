# giac 攻击性审查汇总（五 Agent 聚合）

> 本文档固化 2026-08-01 五轮并行攻击审查的全部发现、修复状态与验证方法，
> 防止上下文丢失。审查对象：MacCalculator 的 giac CAS 集成
> （libgiac.a + src/MacGiacBridge/GiacBridge.mm + src/MacApp/Services/GiacMathSolver.swift
> + Tools/giac-patches/ 模块裁剪补丁体系 + src/GraphingImpl/GiacBridge/ Windows 桥）。

## 0. 环境与方法（复现基线）

- 全模块引擎：`/tmp/icas_full`（链接仓库 `third_party/giac/lib/libgiac.a`）
- 裁剪引擎：`/tmp/icas_prune_v5`（build-all 配置：禁 14 模块保留 plot，最新 stub）
- 官方基准：`/tmp/giac-fork/build-full/src/icas`、`/tmp/giac-fork/build-all/src/icas`
- signal-off 引擎：`/tmp/icas_sigoff`（仅禁 signal，验证 extrema 修复）
- 用法：`icas file.cas < /dev/null 2>err`（每行一条命令以 `;` 结尾）
- 行为测试资产：`/Users/newbiexvwu/calculator/Tools/giac-tests/*.cas`（16 行为 + 5 App 命令集）
- 官方 check 套件：`giac-2.1.0/check/`（testcas 等 7 件 vs 官方 .out）
- 构建 flags（验证过的）：`CPPFLAGS="-I/opt/homebrew/include" CXXFLAGS="-g -O2 -U_GLIBCXX_ASSERTIONS -DUSE_OBJET_BIDON -fno-strict-aliasing -DGIAC_GENERIC_CONSTANTS -DTIMEOUT" LDFLAGS="-L/opt/homebrew/lib" LIBS="-lpthread -lm -lgmp -lmpfr -lgmpxx -lintl -framework Accelerate"`
- icas 测试工具必须带完整宏编译（缺 `-DHAVE_CONFIG_H -DIN_GIAC` 会导致 ODR 违规/UB，曾误报 solve 丢根）：
  `g++ -DHAVE_CONFIG_H -DIN_GIAC -I. -I src -I.. -I/opt/homebrew/include -g -O2 -U_GLIBCXX_ASSERTIONS -DUSE_OBJET_BIDON -fno-strict-aliasing -DGIAC_GENERIC_CONSTANTS -DTIMEOUT -include unistd.h src/icas.cc src/Xcas1.cc -o /tmp/icas_XXX -L src/.libs -lgiac -L/opt/homebrew/lib -lgmp -lmpfr -lgmpxx -lintl -framework Accelerate`

---

## 1. Agent A —— 模糊/病态输入攻击（/tmp/giac-attack/report.md）

**方法**：2 万次随机表达式 fuzz + 384 次系统性套件（挂起 36/边界 52/解析器 67/内存 21/状态污染 16）+ 350 次补充；5s 超时判定挂起；1GB ulimit 测 OOM。

### 崩溃（P0，双引擎均复现 SIGSEGV）

- **C1 `factor(1e-12*x)`**：系数 ≤1e-12 段错误。根因链：
  `is_integral`（usual.cc:6832-6851）用 epsilon 版 `is_zero`（fabs<=1e-12，gen.cc:9321）判整数 →
  `1e-12` 被误判为整数并**就地变异为 0**（indice=tmp 副作用）→ `gcd(1e-12,1e-12)=0`（错误值）→
  `do_factor`（gausspol.cc:7145）对零多项式空 `coord` **无守卫** `coord.front()` → NULL 解引用。
  附带错误值：`gcd(1e-12,1e-12)=0`、`content(1e-12*x)=0`、`sign(1e-12)=0.0`（应 1）。
  修复方向：is_integral 精确比较 + 去掉变异副作用 + do_factor 空向量守卫。
- **C2 `sqrt(1e-7*x+i)`**：段错误。根因：`normalize_sqrt→sym2rxroot→rsqff`（sym2poly.cc:1000）
  `p1*pow(it->fact.coord.front().value,...)`——sqff 对近似系数多项式产生**空 coord 因子**，
  `coord.front()` UB → `pow` 首行 `base==zero` 空指针解引用。
  修复方向：rsqff/sqff_evident_primitive 对空 coord 加守卫。

### 挂起（>30s，双引擎，建议宿主层超时兜底）

- H1 `expand((a+b+…+h)^50)` 组合爆炸（2.6 亿项）
- H2 `perm(10^7,5*10^6)` 病态慢路径（同类 5 万级 0.03s，10^7 级 >60s 超线性退化）
- H3/H4/H5/H6 随机 fuzz 病态组合（`sqrt(acos(7),0randi,-1e308lcm13)` 等，参数畸形+符号搜索爆炸）

### 其他

- 内存：1GB 下无 OOM 崩溃；`factorial(10^7)` 优雅 undef；`seq(10^8)` full 生成 800MB / prune 拒绝 ✓
- 解析器：67 条畸形输入（控制字符/代理对/emoji/10 万字符）零崩溃 ✓
- 状态污染：16 组序列无污染；唯一轻微 `purge(y)` 后 assume 条目残留
- 错误结果：`(-1)^0.5=undef`（设计取舍）、`1e-8e8` 解析歧义（e8 当标识符）
- 结论：prune 裁剪未引入额外漏洞（两引擎崩溃/挂起一致）

## 2. Agent B —— Swift 集成注入/并发攻击（/tmp/giac-attack/GIAC_ATTACK_REPORT.md）

**方法**：静态审查 + 动态验证（复制 GraphExpression/GiacMathSolver 到 /tmp 编译完整 analyze() harness，仓库 8/8 单测对照）。

### 严重度 1（注入）

- **1.1【已防御】** 文本注入：37 向量（`;`/`:=`/`sto`/`assume`/引号/反引号/`$`/`%`）全被 GraphExpression 白名单解析器 REJECTED ✓
- **1.2【高危·潜在】`ask()` 裸 caseval 原语**（GiacMathSolver.swift:1003）：`ask("sto(5,x)")` 后 `analyze("x^2")` → **range=[25,+∞)、yInt=25 静默错误答案**（实测）。全应用唯一能携带任意串到 giac 的漏斗。修复：白名单化 + 强制 analysisLock。
- **1.3【中危】数字溢出序列化 `inf`**：`1e999` → Double +inf → giacForm 输出 `"inf"` → 常函数捷径（无白名单）→ **range={+infinity}、yInt=+infinity 自信错误答案**。修复：giacString 对 !isFinite 返回 nil + 捷径过白名单。
- **1.4【低危】`y` 变量混入查询**：`analyze("x+y")` → zeros=["-y"]。UI 已挡（隐式方程路由），API 可达。修复：analyze 入口校验。

### 严重度 2（并发）

- **2.1【中危】`ask()` 无锁共享 session**：预算互吞/撕裂读（静态成立，时序敏感）。
- **2.2【已防御】** 并发 analyze 串行化正确；defer 复位顺序正确；无重入；锁序无死锁 ✓
- **2.3【低危】** GiacBridge fd 2 捕获窗口跨线程副作用（见 Agent E B-2）

### 严重度 3（状态泄漏）——全部已防御 ✓

- 异常/崩溃路径 defer/@finally 覆盖；purge/assume 配对动态验证通过；预算耗尽不残留

### 严重度 4（DoS/解析）

- **4.1【高危】栈溢出崩溃（无输入上限）**：渲染路径 `1+1+…` 约 150k 字符主线程 SIGSEGV（GraphExpression.swift:123-161 递归）；解析路径深括号约 2500 层（5k 字符）512KB 分析线程 SIGBUS；粘贴即崩。修复：输入长度上限（如 2k）+ 深度限制（如 200 层）。
- **4.2【中危】单查询无超时**：预算只在查询前门控；giac -DTIMEOUT 默认 15s/条；最坏 100×15s 且 analysisLock 全局串行。修复：giac `timeout N` 命令（gen.cc:16990）。
- **4.3【低危】zeros 无白名单**：只过 isParametric+数量上限，不过 isDisplayableFinite。修复：补白名单。
- **4.4【信息】** 附带发现：`domain(tan(x))` 周期截断 → VA 探针只找到 π/2 一个 → VA 列表不完整仍展示（诚实性缺口）。

## 3. Agent C —— 配置矩阵攻击（/tmp/giac-attack-matrix/REPORT.md）

**方法**：24 组合 ×（configure+make+链接+21 测试），真实构建。

### 链接矩阵结果

| 组合 | 结果 | 根因 |
|---|---|---|
| plot / plot+plot3d / all15 / rpnonly | **编译失败** | 缺陷 A：stub 缺 `at_barycentre`（giac_stubs.cc 抄 plot.cc:17337 表时漏掉，全库唯一无头文件声明的 at_*） |
| iofmt / iofmt+help | **链接失败** | 缺陷 B：stub 缺 `gen _latex`（graphe.cc:1955 引用，tex.cc 定义） |
| desolve / maple+desolve | **链接失败** | 缺陷 C：stub 缺 `is_constant_wrt_vars`（optimization.o 8 处引用，desolve.cc:2513） |
| kextra+quickjs | **链接失败** | 缺陷 F：stub 缺 `js_add_graphic`（qjsgiac.c:262 引用，graphic.c:76 定义） |
| 其余 16 组合 | ✓ | — |

### 非预期功能回归

- **缺陷 D（proba 裁剪）**：`solve(x^2=2^x)` 报错（LambertW stub 返回错误 → solve.cc:678-716 指数方程分支失败）。full 返回 3 个 LambertW 解。**存在于 build-all 已验证配置中（fork 归为"预期"实为缺陷）**。
- **缺陷 E（signal 裁剪）**：`extrema(f,x)` **静默返回 [[],[]]**（to_real_number/is_real_vector stub 错误 → 临界点全被过滤，无任何提示）。连带 generr 系列错误类型语义损坏（generrtype 应 gentypeerr 却 gensizeerr）、print_error/print_warning no-op 吞警告。**fork 从未跑 App 命令集，从未被发现**。

### 修复状态

- ✅ A/B/C/F 已补 stub（at_barycentre/_latex/is_constant_wrt_vars/js_add_graphic）
- ✅ D 已照抄 LambertW×2（moyal.cc:4238/4310）
- ✅ E 已照抄 to_real_number/is_real_vector/is_logical/generr 四件套/print_error/print_warning
- ⏳ 矩阵重跑验证（signal-off 已构建出 /tmp/icas_sigoff）

## 4. Agent D —— 数值/精度攻击（/tmp/giac-attack/REPORT.md）

**根因线索**：giac 实数在 Digits≥15 时切换"尾数形式"（0.xxx…eN），特殊变量 setter 对尾数 (int) 转换取 0/错值。默认 Digits=12（非上游 20）。

### 错误数值

- **1.1 `x/x=0.999…9`**（Digits=30 等）：`x:=evalf(pi,30); x/x` ≠ 1、`==1` false、`exact()` 返回 1（掩盖）。失败位数集 {25,26,27,28,30,35,43,200,400,1000} 无规律。影响：Swift 相等性判定需容差（已有 near() ✓）。
- **1.2 混合精度**：`Digits:=100; 1/3.0` → 0.333…32149（第 15 位起错，double 路径零填充）；（1/3.0)*3 ≠ 1。
- **1.3 `exact()` 精度坍缩**：`exact(evalf(pi,1000))` → 4272943/1360120（12.5 位连分数重建，987 位丢失）；仅有理数往返安全（exact(evalf(1/3))=1/3 ✓）。
- **1.4 科学计数法丢精度**：`1e16+1=1e16`（double 路径 1 ULP=2）；整数形式正确。

### 精度污染（静默）

- **2.1 `approx_mode:=1` + Digits≥15 → 会话损坏**：`approx_mode:=0` 失效（保持开）+ 所有 `Digits:=N` 静默冻结。App 不设 approx_mode（安全）；all_trig_solutions 复位不受影响 ✓。
- **2.2 `Digits:=<实数>` 静默忽略/垃圾值**（`Digits:=evalf(pi,50)` 无效、`Digits:=evalf(1.5,30)` → 1）。
- **2.3 混合 double/real 精度坍缩**（`y*0.5*2` 在 Digits=1000 只出 14 位）。
- **2.4 `complex_mode:=1` 静默无效**（setter 打印 RHS 后丢弃）。

### 不一致（部分为误判）

- **3.1 prune 缺 `length`【误判】**：length 是 **MAPLE 模块命令**（maple.cc:936），裁剪 MAPLE 后原样 = 预期裁剪语义（full 正常 3/1）。
- **3.2 `gamma/zeta/evalff` 小写【误判】**：上游 giac 2.1.0 本来就没有小写命令（full 也原样）；App 用 Gamma/Zeta 大写即可。
- **3.3 is_prime 1/2 双约定【数学正确】**：2=已证明素数（小），1=Miller-Rabin 大概率（大）；Carmichael 数全部正确拒绝。App 判定需同时接受 1 与 2。

### 边界（记录）

1e308*10→inf 静默溢出；1e-308 次正规下溢；-0.0 符号丢失（1/(-0.0)=+inf）；0.1+0.2=0.3 ✓；evalf(pi,1000) 正确 ✓；200 条随机数值命令两引擎逐字节一致 ✓。

## 5. Agent E —— 桥稳定性攻击（/tmp/giac-attack/report-bridge-attack.md）

**方法**：用真实 GiacBridge.mm 编译独立测试二进制实测（/tmp/giac-attack/attack、t5b-t10）；Windows 桥纯代码推理。

### P0 崩溃/砖化（全部指向 giac TIMEOUT 机制缺陷）

- **A-1 重复超时 → 进程 SIGABRT（3/3 复现）**：`timeout 2` + 连续 `seq(k^2,k,1,500000000)` 慢查询被 watchdog 取消；第 2 次超时后 `threads=2`（被取消的 worker 没死透），第 3 次崩溃。根因：gen.cc:16783-16801 `thread_caseval` 设 **PTHREAD_CANCEL_ASYNCHRONOUS**，异步取消投递在 open()/dyld 中途 → `_pthread_exit_if_canceled` EXC_BREAKPOINT；且不 join（gen.cc:17023-17058 注释 "// does not work"）→ 泄漏线程与下次 caseval 并发访问全局 context → 数据竞争。
- **A-2 递归超时 → 引擎永久砖化（一次输入杀光全部算术）**：`timeout 1` + `f(n):=f(n+1);f(0)` → `GIAC_ERROR: Timeout` 后 `1+1`/`2^10`/`3*4`/`expand`/`ifte` 全部 "Too many recursions"，1000 个 solve 不自愈，直到重启。根因链：① prog.cc:1571-1578 递归深度检查 `stackaddr==0` 恒 false（caseval 裸 pthread_create 不设 thread_param）→ 无限递归不受限；② 每层 `sst_at_stack.push_back`（prog.cc:1592）被 async cancel 截断永不 pop → 残留百万条脏条目；③ gen.cc:2376-2378 门禁 `sst_at_stack.size()>=19` → 全部算术拒绝。
- **A-3 bad_alloc 必然杀进程（代码路径证明）**：`protectevalorevalf` 只 catch `std::runtime_error`（prog.cc:10295-10301）；`thread_caseval` 无 try/catch → worker 内 bad_alloc → `std::terminate` → SIGABRT。`1$10^9` 被 LIST_SIZE_LIMIT=5e8 拦截（实测），但小内存设备上远低于上限即可触发。

### P1

- **B-1 15s 冻结**：默认超时 15s，实测单次 evaluate 阻塞 20.2s（锁内，UI 冻结，桥无兜底）。修复：桥层 `timeout N`。
- **B-2 fd 2 劫持进程级污染（30/30 实测）**：捕获窗口内其他线程 fputs/cerr/NSLog 全进 warnings（390/399 条），约 2% 被 EAGAIN 丢弃；App 诊断日志被吞。修复：根治=子进程；过渡=内容过滤或 iostream 层（注意 W-2 的 UB）。

### P2

- **B-3 history 无上限**：5000 次 evaluate RSS +8.1MB（1.6KB/次线性）。桥无法干预，需周期重建 context。
- **B-4 每 evaluate 一个 pthread**：14ms/次下限。
- **B-5 警告洪泛只捕获开头 64KB**：最新（最相关）警告丢失且截断在消息中间。macOS 管道容量实测 64KB（非注释所写 16KB）。
- **B-6 捕获窗口内其他线程 stderr 部分丢失**（~2%）。

### Windows 桥静态

- W-1 通过：copyOut cap==1 边界 ✓、异常恢复顺序 ✓、锁嵌套 ✓、catch 作用域 ✓
- **W-2 `std::cerr.rdbuf()` 是进程级全局（污染 + UB 数据竞争）**：非桥线程写 cerr → 进 oss 当 warnings；并发读写 iostream 是未定义行为。头文件已记录"一并进入"但未提 UB。
- **W-3 同款 TIMEOUT 异步取消缺陷**（winpthreads 基于 SuspendThread 更糟：可能杀在 CRT/堆锁内 → 全局堆损坏/其他线程死锁）。
- **W-4 ostringstream 无上限**（恶意 GB 级警告 → 慢速 OOM）。

### 正向确认

并发 2×500 次 0 错乱 ✓；fd 5000 次零泄漏 ✓；badbit 恢复 10/10 ✓；Unicode 全过零崩溃 ✓；60k 层括号/30k 层 abs 解析有防护 ✓。

---

## 6. 修复状态追踪

### 已完成 ✅

| # | 项 | 文件 | 验证 |
|---|---|---|---|
| 1 | 缺陷 A at_barycentre | giac_stubs.cc | 编译 ✓ |
| 2 | 缺陷 B _latex | giac_stubs.cc | 编译 ✓ |
| 3 | 缺陷 C is_constant_wrt_vars | giac_stubs.cc | 编译 ✓ |
| 4 | 缺陷 F js_add_graphic（KEXTRA 段） | giac_stubs.cc | 编译 ✓ |
| 5 | 缺陷 D LambertW×2 照抄 | giac_stubs.cc | solve(x^2=2^x) 与 full 逐字一致 ✓ |
| 6 | 缺陷 E to_real_number/is_real_vector/is_logical/generr 四件套/print_error/print_warning | giac_stubs.cc | 编译 ✓，signal-off 待验证 |
| 7 | 此前轮次：isalphan/poisson_cdf/randNorm/randpoisson/rgamma/unif_rand/exp_rand/get_path/remove_path/plot_sommets/set_assumptions/gen2tex/default_helpfile/randdiscrete/at_TeX token/__getKey | giac_stubs.cc | 21 文件 0 差异 ✓ |
| 8 | Windows 桥 rdbuf 方案（H3/H4/H5） | giac_bridge.cpp/.h | 语法 ✓ |
| 9 | macOS 桥 @try/@finally + clearerr（S1） | GiacBridge.mm | 测试 ✓ |
| 10 | GiacMathSolver S1 常函数捷径 / H1 parseDomain / H2 VA 解耦 / M1 周期数值解 / M2 purge / M3 值域查表 | GiacMathSolver.swift | 125 测试全过 ✓ |

### 已完成（第二轮修复，全部验证）✅

| # | 项 | 验证 |
|---|---|---|
| 11 | 缺陷 A/B/C/F 缺失符号（at_barycentre/_latex/is_constant_wrt_vars/js_add_graphic） | 配置矩阵组合恢复构建 ✓ |
| 12 | 缺陷 D LambertW×2 照抄 | solve(x^2=2^x) 与 full 逐字一致 ✓ |
| 13 | 缺陷 E signal 系列（to_real_number/is_real_vector/is_logical/generr 四件套/print_error/print_warning） | signal-off 配置 extrema 与 full 一致、21 文件 0 差异 ✓ |
| 14 | C1 factor(1e-12*x) 崩溃：is_integral 精确比较 + do_factor 两处空向量守卫（gausspol.cc:7145/7161） | 3 条/4 条连跑不崩 ✓ |
| 15 | C2 sqrt(1e-7*x+i) 崩溃：rsqff 空因子守卫（sym2poly.cc:1000） | 不崩 ✓ |
| 16 | A-2 递归砖化：thread_caseval 每调用设置 thread_param stackaddr（&tpp 栈上地址，注意引用陷阱）+ prog.cc NULL 守卫 | f(0) 递归超时后 1+1=2 ✓（曾 SIGBUS/永久砖化） |
| 17 | A-1 重复超时 SIGABRT：interrupted + trylock 轮询 2s + 兜底 cancel + join | 3 次重复超时无 SIGABRT，每次后引擎正常 ✓ |
| 18 | A-3 bad_alloc 杀进程：thread_caseval catch(std::exception/catch(...)) | 代码路径 ✓ |
| 19 | 栈溢出 DoS：GraphExpression maxInputLength=2000 + maxParseDepth=200 | 150k 字符/2500 层不再崩 ✓ |
| 20 | ask() 白名单+锁；常函数捷径/zeros 白名单；giacString inf/nan 显式化 | 125 测试全过 ✓ |
| 21 | 桥层 timeout N 兜底（GiacBridge.mm dispatch_once 惰性设置 5s） | 已实现（后续发现锁内文件 IO 会触发 giac 解析器时序问题——已移除诊断日志，timeout 设置保留） |
| 22 | core-fixes.patch 补丁体系（usual/gausspol/sym2poly/gen/prog 5 文件 git 格式） | 干净树 patch -p1 应用成功 ✓ |

**重要教训（排查记录）**：KGF 测试曾 98 失败（查询全部原样回显 = giac 解析器状态损坏）——
根因是**调试用诊断日志（锁内 NSFileHandle 文件 IO）改变了 caseval 调用时序**，触发 giac
解析器偶发失败；移除日志后 125 测试全过。核心源码修复本身不影响（二分验证：干净库 +
诊断日志同样失败；修复库 + 无日志通过）。

**第二轮补修（回应"不修=偷懒"质疑，全部验证）**：

| # | 项 | 修复 | 验证 |
|---|---|---|---|
| 23 | factor(1e-12*x)=0 | **根因**：`tensor(v,d)` 构造用 is_zero（epsilon）丢弃 1e-12 系数 → Tlgcd 内容空 → factor 组装 0。**修复**：poly.h tensor 构造 is_zero→is_exactly_zero（仅 Tlgcd 传任意值，其余调用传 1/0 不受影响） | factor(1e-12*x)=1e-12*x ✓、content=1e-12 ✓ |
| 24 | 1e16+1=1e16（D1.4，App 可达） | GraphExpression giacString 整数阈值 1e15→9.2e18（Int64 上限），科学计数法字面量改走精确整数路径 | 21 文件 0 差异 ✓ |
| 25 | D2.1/2.2 approx_mode/Digits 尾数截断 | prog.cc `_Digits`/`_approx_mode` setter 对 _REAL（mantissa 形式）完整值转换（evalf_double+round）+ 溢出守卫 | approx_mode:=0 恢复、Digits:=30 不再冻结、Digits:=evalf(1.5,30)=2 ✓ |
| 26 | fd 2 污染（B-2）+ 警告洪泛尾部（B-5） | GiacBridge.mm：求值期间 pthread drain 线程持续读管道（保住尾部）+ 内容过滤（只留 giac 特征行 periodic/assume/approx/bisection/warning/error）+ 尾部 256KB 上限 | 警告捕获正常、125 测试全过 ✓ |
| 27 | Windows W-2/W-4 | giac_bridge.cpp：捕获内容同样过滤 + 64KB 尾部保留（防 GB 级慢速 OOM + 防伪造警告） | 语法 ✓ |
| 28 | VA 周期截断（4.4） | **核实已被 H2 的 326 行守卫覆盖**（tan domain autoAssumed → domainInfo=nil → VA too complex，KGF 基线确认） | 无需新增修改 |

**第三轮补修（"仍不修"项的更好方案，全部验证）**：

| # | 项 | 更好的方案 | 验证 |
|---|---|---|---|
| 29 | gcd 浮点（gcd(0.3,0.5)=1 错） | gen::gcd 加 _DOUBLE___DOUBLE_ 分支：float2rational 连分数（找回用户意图的十进制分数）+ 非 FRAC 时回退 double2frac（15 位十进制精确分数），恒等式 gcd(a/b,c/d)=gcd(a,c)/lcm(b,d) | gcd(0.3,0.5)=1/10 ✓、gcd(0.25,0.5)=1/4 ✓、factor(0.3*x+0.5)=1/10*(3.0*x+5.0) ✓ |
| 30 | x/x≠1（高精度除法末位误差） | rdiv 开头相等非零短路（a==b → 1） | x/x=1、x/x==1=true ✓ |
| 31 | exact 坍缩（evalf(pi,1000)→12 位） | exact 的 _REAL 分支：prec>53 时 mpfr 尾数精确分数展开（z×2^n 精确除法；**教训**：real2int 用 _iquo 截断会丢分数部分，且 sscanf %lf 吃 e 指数需手动解析）；低精度保留连分数（1/3、1/10 仍找回） | exact(evalf(pi,1000)) 输出 1000 位精确分数 ✓、exact(evalf(1/3))=1/3 ✓ |
| 32 | 挂起类 | 核实：GraphExpression 输入白名单（单变量+14 函数+2000 字符/200 层）使其 App 不可达；桥层 timeout 兜底 CLI（A-1/A-2 修复后安全） | 无需更多 |
| 33 | history 增长 | 核实：App 单次 analyze ~30 查询（增长 ~50KB），5000 次才 8MB——App 会话内可忽略 | 无需更多 |

**第四轮：拆"隐藏炸弹"（引擎层彻底修复，非 App 规避）**：

**二进制噪声真相**：gen 结构的 type 字段占用 double 的**低 5 位**（位域），double 实际
只有 **48 位有效尾数**——`1e15+1` 的 bit0 被 type 吃掉 → `1e16+1-1e16 = 0.0`、
`1e16+1==1e16 = true`（静默错误）；`1e-12` 的二进制表示本非精确 10^-12 → 任何
double/mpfr 级算法恢复不出十进制 gcd。

| # | 修复 | 验证 |
|---|---|---|
| 34 | 解析器：**整数科学计数法（1e15/1e16）→ 精确 _ZINT** | 1e16+1=10000000000000001 ✓、1e16+1-1e16=1 ✓、==false ✓ |
| 35 | 解析器：**负指数整数科学计数法（1e-12）→ 精确 _FRAC**（1/10^12） | gcd(1e-12,2e-12)=1/10^12 ✓、1e-12+2e-12=3/10^12 ✓、factor(1e-12*x)=x/10^12（干净）✓ |
| 36 | 解析器：**带小数点科学计数法（1.5e-3）→ _REAL（mpfr 十进制，精度 ≥53 比特）**——40 比特比 double 还差（evalf(1.5e-10,30) 噪声尾数） | evalf(1.5e-10,30) 输出 53 比特等价精度 ✓ |
| 37 | gcd 的 _REAL__REAL 分支：mpfr_get_str 十进制 → 分数精确 gcd（修 gen(s1,10) 的垃圾指针——10 被当 context 指针） | gcd(_REAL 对) 不再崩溃 ✓ |

**第五轮："开脱"质疑的证据链与补修**：

| 质疑项 | 证据 | 结论 |
|---|---|---|
| 1e-99==0.1e-99 false 是"表示限制"？ | 实测：**修复前也 false**（fork 旧库）；数学上 `0.1e-99 = 10^-100 ≠ 10^-99 = 1e-99`（**本来就不相等**） | **我表述错误**（不是表示限制，是数学不等）；非回归 ✓ |
| 普通小数（0.1）有炸弹？ | 实测 30 位：0.1+0.2-0.3=0.0、0.7+0.1=0.8、==true、exact(0.1)=1/10——48 位噪声（~1e-16 相对）被 giac 的 epsilon（1e-12）完全吸收 | **无炸弹**（实测证据）✓ |
| 1/3.0 混合精度"App 不可达"就够？ | 不够——**已修**：rdiv 的 _REAL__DOUBLE_/_DOUBLE___REAL_/_DOUBLE___DOUBLE_/_DOUBLE___INT_/_INT___DOUBLE_ 在 Digits>15 时把 double 提升到当前 Digits 精度（real_object(gen, prec)）——深挖发现 `1/3.0` 解析为 _FRAC，其 evalf 路径 num.evalf 已提升 _REAL 而 den 保持 _DOUBLE_ → 混合降级 double（0.333...32149 零填充） | Digits:=100 下 `1/3.0`=100 位精确、`(1/3.0)*3`=1.000...、`1.0/7` 精确循环小数 ✓ |

**剩余显示差异（24 行，全部为格式且数值相等）**：09_precision/11_app/app_full_test3——
新库按 evalf 请求位数显示（1.00000000010000000000000000000 30 位 vs 旧 10 位）、
整数 vs 科学计数法格式（10000000001 vs 0.100000000010000000000000000000e11）；
`1e-99==0.1e-99` 数学上不等（见上表）。check 套件 7/7 零差异、Swift 125 全过。

### 进行中 ⏳

- 配置矩阵全 24 组合重跑确认（stub 修复后各组合构建已部分验证：build-all/signal-off 通过）

### 待办 🔲（按优先级）

| 优先级 | 项 | 方向 |
|---|---|---|
| P0 | C1 factor(1e-12*x) 崩溃 | usual.cc is_integral 精确比较+去变异；gausspol.cc do_factor 空向量守卫 |
| P0 | C2 sqrt(1e-7*x+i) 崩溃 | sym2poly.cc rsqff/sqff 空因子守卫 |
| P0 | A-2 递归砖化 | prog.cc:1574 thread_param 初始化（或删死路径）+ 超时后清 sst_at_stack |
| P0 | A-1 重复超时 SIGABRT | 超时路径改"置标志+join+二次兜底"；取消后健康自检 |
| P0 | A-3 bad_alloc 杀进程 | thread_caseval 包 catch(...) |
| P1 | 栈溢出 DoS（4.1） | GraphExpression 输入长度/深度限制 |
| P1 | ask() 白名单+锁（1.2/2.1） | GiacMathSolver.swift |
| P1 | 常函数捷径/zeros 白名单 + inf/nan 拒绝（1.3/4.3） | GiacMathSolver.swift + GraphExpression.swift |
| P1 | 单查询超时（4.2/B-1） | 桥层 timeout N |
| P1 | y 变量校验（1.4） | analyze 入口 |
| P2 | B-3 history 增长 | 周期重建 context（评估） |
| P2 | B-5 警告截断 | 读端 drain + 环形缓冲（评估） |
| P2 | W-4 oss 上限 | giac_bridge.cpp |
| P2 | VA 周期截断诚实性（4.4） | GiacMathSolver.swift |
| P2 | purge 清 assume（Agent A） | giac 源码（评估） |
| 信息 | 数值缺陷 1.1-2.4（Agent D） | giac 内部数值引擎，App 层容差规避；记录文档 |
| 信息 | 挂起 H1-H6 | 宿主层超时兜底（timeout N） |

### 验证清单（每次改动后）

1. 裁剪库 21 文件 vs build-all 基准 0 差异
2. 全模块库 21 文件 vs build-full 基准 0 差异
3. 官方 check 套件 7/7 零差异
4. 攻击用例回归：factor(1e-12*x) 不崩、sqrt(1e-7*x+i) 不崩、solve(x^2=2^x) 正常、extrema 不静默、递归超时后 1+1 正常
5. `swift test` 全量（125 个）
6. 配置矩阵 24 组合构建全绿

## 7. 已知 giac 上游本征行为（无需修复，记录）

- 小写 gamma/zeta/evalff 命令不存在（用 Gamma/Zeta 大写）
- is_prime 返回 1/2 双约定（数学正确）
- 1e308*10 静默溢出为 inf；1e-308 以下次正规
- `(-1)^0.5 = undef`（近似指数保守处理）
- 默认 Digits=12（非上游 20）——构建配置差异
