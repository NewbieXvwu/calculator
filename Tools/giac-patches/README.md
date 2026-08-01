# Giac 模块裁剪补丁体系（calculator fork）

本目录是 /tmp/giac-fork 工作成果的落仓版本：在不改官方源码语义的前提下，
为 giac 2.1.0 提供**模块级裁剪**（configure 选项），并把裁剪后的跨模块
引用转发到核心实现（giac_stubs.cc），保证 App 行为与裁剪前完全一致。

## 文件说明

| 文件 | 内容 |
|---|---|
| `configure.ac` | 新增 15 个 `--disable-giac-*` 选项（GIAC_MODULE_OPTION 宏），每个选项定义 `GIAC_NO_XXX` 宏 + AM_CONDITIONAL |
| `src/Makefile.am` | 源码列表按模块条件化：核心源码固定编译，各模块源码在对应条件为真时追加 |
| `src/giac_stubs.cc` | 跨模块转发实现（~3083 行）：被裁剪模块的函数 stub 转发到核心实现，含头注释跨模块依赖文档 |
| `DIFF_REPORT.md` | build-all（裁剪）vs build-full（完整）全量对比报告：16 文件 1000+ 命令 |
| `gen_ats.py` | at_* 词法器注册缺失自动补齐重扫描脚本 |

## 模块选项（configure.ac）

```
--disable-giac-graph    图论（graphe/graphtheory/optimization/lpsolve）
--disable-giac-plot     绘图（plot）
--disable-giac-plot3d   3D 绘图（plot3d）
--disable-giac-help     help 数据库
--disable-giac-ti89     TI-89 模拟
--disable-giac-rpn      RPN 模式
--disable-giac-iofmt    MathML/TeX/Markup 输出
--disable-giac-extlib   CoCoA/PARI 绑定
--disable-giac-proba    概率统计（proba/moyal）
--disable-giac-quater   四元数
--disable-giac-isom     等距变换
--disable-giac-maple    Maple 语法兼容
--disable-giac-desolve  微分方程求解
--disable-giac-signal   信号处理
--disable-giac-kextra   内核附加（kdisplay/kadd/graphic）
```

默认全部启用 = 官方等价行为。App 验证过的裁剪配置（build-all）：
`--disable-giac-graph --disable-giac-plot3d --disable-giac-help --disable-giac-ti89
 --disable-giac-rpn --disable-giac-iofmt --disable-giac-extlib --disable-giac-proba
 --disable-giac-quater --disable-giac-isom --disable-giac-maple --disable-giac-desolve
 --disable-giac-signal --disable-giac-kextra`（保留 plot）

## 构建要求（重要）

1. **-DGIAC_GENERIC_CONSTANTS 必须**：否则 `cst_i` 等 alias 常量在 arm64 上损坏
   （实测 `arg(1+i)` 输出 `atan(65536)` 并卡死）。
2. 修改 configure.ac 后必须 `autoreconf -fi` 重新生成 configure/Makefile.in。
3. 链接需要 `-L$(brew --prefix)/lib` + `-lgmp -lmpfr -lgmpxx -lintl -framework Accelerate`。

## 使用

```bash
# 官方等价（全模块）：
Tools/build_giac.sh

# 裁剪（App 验证配置）：
Tools/build_giac.sh 2.1.0 --disable-giac-ti89 --disable-giac-maple ...

# 重新启用某模块：去掉对应 --disable-giac-XXX 重新构建即可。
```

## 验证资产（Tools/giac-tests/）

- `01_arith.cas` … `16_rand.cas`：16 文件 ~1000 命令行为套件（裁剪 vs 完整双向 diff）
- `app_full_test*.cas`、`m_appfull.cas`：App 命令集（GiacMathSolver 实际查询）
- `m_verify.cas`：assume/type/Beta 修复验证

已知预期差异（模块裁剪官方语义）：禁用模块命令原样/报错、extrema 报错（依赖 EXTLIB
Groebner，官方无该模块时同样报错）、rand 随机序列。
