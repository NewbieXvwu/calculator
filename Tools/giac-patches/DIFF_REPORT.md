# GIAC 裁剪构建 (build-all) vs 完整构建 (build-full) 全量对比测试报告

测试环境: icas 2.1.0, 每行一个命令(带 ;), 对比 stdout(过滤时间戳), 逐行 diff。
16 个测试文件, 约 1000+ 条命令, 覆盖 12 个功能面。

## 总览

| 文件 | 状态 | 差异命令数 |
|---|---|---|
| 01_arith | DIFF | 1 (trunc) |
| 02_poly | 一致 | 0 |
| 03_calc | DIFF | 8 (sum三角, taylor×7) |
| 04_solve | DIFF | ~26 (solve, csolve, desolve) |
| 05_linalg | DIFF | 3 (norm矩阵, newList, abs矩阵) |
| 06_special | DIFF | ~15 (Beta化简, Beta错误, bessel) |
| 07_trig | 一致 | 0 |
| 08_complex | DIFF | 9 (csolve×8, abs矩阵) |
| 09_precision | 一致 | 0 (高精度/大数/浮点全部一致) |
| 10_expr | DIFF | ~35 (nops, assume, evalc×30) |
| 11_app | DIFF | 16 (assume, extrema预期) |
| 12_boundary | 一致 | 0 |
| 13_boundary | DIFF | 1 (trunc(inf)) |
| 14_syntax | 一致 | 0 |
| 15_unicode | 一致 | 0 (含 π √ ∑ 等 Unicode 输入) |
| 16_rand | DIFF | randpoly(缺陷) + 随机序列(预期) |

is_prime(97)/is_prime(2^127-1)/is_prime(561) 两构建输出完全一致(2,1,0)。
09_precision(约130条evalf用例, 含1000位π) 零差异。

## 一、非预期缺陷(App 会真实遇到, 按严重度排序)

### 缺陷1 [严重] assume 带类型参数损坏 — App 命令集必用
- `assume(x,integer)` → all: **空输出**; full: `integer`
- `assume(x,real)` / `assume(y,real)` → all: **"Invalid purgenoassume 0 Error: Bad Argument Value Error: Bad Argument Value"**; full: `real`
- `assume(x,complex)` → all: 空; full: `complex`
- 根因: `at_real` 在 giac_stubs.cc:1569 被 stub 成 STUB_TI89_PTR(TI89 模块禁用), giac_assume(usual.cc:5024) 中 `a2==at_real` 恒假, 走错误分支 → 报错/空。
- App 的 assume 类型查询(integer/real/complex)全部失效。

### 缺陷2 [严重] type()/DOM_INT 打印为空
- `type(2)` → all: **空行**; full: `integer`
- `DOM_INT` → all: 空; full: `integer`; `integer` → all: 空
- 根因: gen::print 对 _INT_TYPE 走 `localize(printint32(...))`(gen.cc:14575), 而 build-all 中 GIAC_NO_HELP stub 的 `localize()` 返回**空串**(giac_stubs.cc:2537 `return std::string();`)。
- 连带影响: assume(x,integer) 返回值打印为空(与缺陷1叠加)。
- App 若调用 type() 会静默得到空字符串。

### 缺陷3 [严重] 静默未求值命令清单(无错误提示, App 难发现失败)
以下命令在 build-all 中**静默返回未求值原样表达式, 无任何错误消息**:
- `csolve`(复数方程求解, TI89模块): csolve(x^2+1) → `csolve(x^2+1)`
- `desolve`/`laplace`/`ztrans`/`invlaplace`(DESOLVE模块): desolve(y'=y,y,x) → `desolve(0=y,y,x)` (参数被求值变形!)
- `nops`(表达式结构, Maple模块): nops(x^2+2*x+1) → `nops(x^2+2*x+1)`
- `evalc`(复数化简, Maple模块): 30个用例全部未求值
- `trunc`(取整, Maple模块): trunc(-3.9) → `trunc(-3.9)`; trunc(inf) → undef(full: +infinity)
- `newList`(TI89模块): newList(4) → `newList(4)`
- `randpoly`(TI89模块): randpoly(3) → `randpoly(3)`
- `besselJ/Y/I/K`(proba模块): besselJ(0,0) → `besselJ(0,0)` — 用户预期"应报禁用", 实际静默
- `taylor` 4参数形式: taylor(sin(x),x,0,6) → `taylor(sin(x),x,0,6)`; 3参数形式 taylor(sin(x),x=0,6) 正常可用
- GF/companion 同属此类(用户已知预期)

注意: 与 extrema 的明确报错不同, 这些命令**完全无提示**, App 无法区分"计算失败"和"表达式未求值"。

### 缺陷4 [高] Beta(2,3,x) 返回错误数值 1/12(静默错值)
- `Beta(2,3,x)`(不完全Beta) → all: **`1/12`**(错误!丢弃第3参数); full: `Beta(2,3,x)`(未求值)
- 根因: giac_stubs.cc:239 stub `_Beta` 对 3 参数情况只调 `Beta(v[0],v[1])` 忽略第3参数
- 比未求值更危险: **静默给出错值**。
- 另: `Beta(1/2,1/2)` all 未化简(返回 Gamma 乘积形式), full 化简为 `pi` — 化简程度差异。

### 缺陷5 [中] 核心命令对特定输入报禁用模块错误(报错明确, 但功能缺失)
- `sum(sin(k*x),k,1,n)` → all: "Maple syntax module is disabled..."; full: 解析结果
- `solve(sin(x)+cos(x)=1)` → all: "Probability and statistics module is disabled..."; full: LambertW 解
- `norm([[1,2],[3,4]])`(矩阵范数) → all: "RPN mode module is disabled..."; full: 5.46498570422
- `abs([[1+i,2],[3,4-i]])`(矩阵abs) → all: "RPN mode module is disabled..."; full: 5.628888624
- 向量 norm/norm(v,1)/norm(v,2)/norm(v,inf) 正常。

### 缺陷6 [低] 其他
- `diff(floor(x))` 等 diff/limit 含 floor/abs/sign/dirac/heaviside: 两构建一致(未列出, 无差异)
- 04_solve 中 desolve 所有用例: all 输出未求值且 `y'` 被求值成 0(参数变形), 不崩溃 ✓(符合"禁用"预期, 但静默)

## 二、预期差异(用户已声明, 验证通过)

1. **extrema** (11_app): all 报 "extrema requires the external CAS module (Groebner basis engine), which is disabled in this build Error: Bad Argument Value" — 文档化语义 ✓ (full 中报 "Error: Bad Argument Type", 两构建都报错)
2. **rand 随机序列** (16_rand): rand/alea/randmatrix/randvector/randperm 输出不同 — 预期 ✓
3. **is_prime GMP**: 实测完全一致(无差异)
4. **GF/companion**: 静默未求值(禁用模块) — 用户已知

## 三、附加发现(与裁剪无关, 但影响对比方法/参考构建)

### 发现A [full构建挂起] — 不影响 build-all 用户
`solve(sin(x)>1/2,x)` 之后接 `csolve(sin(x)=2)` 在 **full 上无限挂起**(>240秒无输出), build-all 立即返回(因 csolve stub)。
- 触发组合: solve(三角不等式) + csolve(三角方程)。单独跑两者都正常。
- 04_solve 测试文件因此在 full 上无法完整跑完(需移除该组合)。
- 这是 full 的状态污染/死循环 bug, build-all 因 csolve 不可用而免疫。

## 四、结论 — App 实际缺陷清单

| # | 命令 | 现象 | 严重度 | 根因 |
|---|---|---|---|---|
| 1 | assume(x,real/complex/integer) | 报错/空输出 | 严重 | at_real 被 TI89 stub 覆盖 |
| 2 | type()/DOM_INT | 空输出 | 严重 | localize() stub 返回空串 |
| 3 | csolve | 静默未求值 | 高 | TI89 stub 无提示 |
| 4 | desolve/laplace/ztrans | 静默未求值+参数变形 | 高 | DESOLVE stub 无提示 |
| 5 | nops/evalc/trunc | 静默未求值 | 高 | Maple stub 无提示 |
| 6 | besselJ/Y/I/K | 静默未求值(非报禁用) | 高 | proba stub 无提示 |
| 7 | newList/randpoly | 静默未求值 | 中 | TI89 stub |
| 8 | Beta(a,b,x) | 返回错误数值 1/12 | 高 | stub 丢弃第3参数 |
| 9 | sum(三角级数) | 报错 "Maple module disabled" | 中 | 内部依赖 Maple |
| 10 | solve(三角+指数混合) | 报错 "proba module disabled" | 中 | LambertW 依赖 proba |
| 11 | norm(矩阵)/abs(矩阵) | 报错 "RPN module disabled" | 中 | 内部依赖 RPN |
| 12 | taylor 4参数形式 | 静默未求值(3参数正常) | 低 | TI89 stub |

**推荐**:
1. assume/type 两个缺陷(1,2)会直接影响 App 的 assume 与类型查询, 建议修复:
   - localize() stub 应返回原串(而非空串)
   - at_real/at_complex/at_integer 不应被 stub 覆盖(或 giac_assume 改用类型枚举比较)
2. 静默未求值类命令(3-7)建议仿照 extrema 增加显式报错消息, 否则 App 无法感知失败。
3. Beta(2,3,x)(8)必须修复——当前会静默返回错误数值。
4. 精度面(09_precision)、Unicode(15)、病态(12)、语法(14)、多项式(02)、三角(07) 全部零差异, 可放心。
