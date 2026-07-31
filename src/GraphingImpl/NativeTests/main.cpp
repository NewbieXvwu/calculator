// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Native 绘图实现（giac 后端）运行时验证（P-Windows-1/2）。
//
// 构建（Windows 测试机，需 vcvars64 环境 + libgiac_bridge.dll 就位）：
//   cl /nologo /EHsc /std:c++20 /W3 /utf-8 \
//       /I <repo>\src\GraphingImpl /I <repo>\src /I <repo>\src\MacBridge\include \
//       main.cpp <repo>\src\GraphingImpl\Native\*.cpp <repo>\src\MacBridge\graph_geometry.cpp \
//       /link d2d1.lib
//   运行前把 third_party\giac-win\bin\libgiac_bridge.dll 复制到 exe 同目录。
//
// 覆盖：DLL 加载、ParseInput 分类（显式/隐式/不等式/Unicode 归一化/语法拒绝）、
// 数值求值、CreateGrapher/变量、KGF 分析（domain/zeros/yint/parity）、
// Analyze 组装、渲染器视窗操作（range/scale/reset/pan）。

#include <windows.h>  // HRESULT（GraphingInterfaces 头文件依赖）

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

#include "Native/NativeMathSolver.h"
#include "Native/NativeGraph.h"
#include "Native/NativeGraphAnalyzer.h"
#include "Native/NativeGraphRenderer.h"
#include "Native/GiacBridgeLoader.h"

using namespace NativeGraphingImpl;

static int g_fail = 0;

static void check(bool cond, const char* what) {
    if (!cond) { printf("FAIL: %s\n", what); ++g_fail; }
    else { printf("ok  : %s\n", what); }
    fflush(stdout);
}

static void checkEq(double a, double b, const char* what) {
    if (std::abs(a - b) > 1e-9) { printf("FAIL: %s (got %f want %f)\n", what, a, b); ++g_fail; }
    else { printf("ok  : %s = %f\n", what, a); }
    fflush(stdout);
}

int main() {
    printf("=== NativeMathSolver runtime test ===\n");
    fflush(stdout);

    // 0. DLL 加载
    check(GiacBridgeLoader::Instance().IsLoaded(), "giac bridge dll loaded");
    fflush(stdout);

    // 1. ParseInput 分类
    MathSolver solver;
    int ec = 0, et = 0;

    {
        auto e = solver.ParseInput(L"y=x^2", ec, et);
        check(static_cast<bool>(e), "parse y=x^2");
        if (e) {
            auto* n = dynamic_cast<NativeExpression*>(e.get());
            check(n->GetKind() == NativeEquationKind::ExplicitFunction, "y=x^2 -> ExplicitFunction");
            auto v = n->EvaluateAt(3.0);
            check(v.has_value(), "eval y=x^2 @3");
            if (v) checkEq(*v, 9.0, "y=x^2 @3 == 9");
        }
    }
    {
        auto e = solver.ParseInput(L"x^2-2", ec, et);
        check(static_cast<bool>(e), "parse x^2-2");
        if (e) {
            auto* n = dynamic_cast<NativeExpression*>(e.get());
            check(n->GetKind() == NativeEquationKind::ExplicitFunction, "x^2-2 -> ExplicitFunction");
            auto v = n->EvaluateAt(2.0);
            if (v) checkEq(*v, 2.0, "x^2-2 @2 == 2");
        }
    }
    {
        auto e = solver.ParseInput(L"x^2+y^2=25", ec, et);
        check(static_cast<bool>(e), "parse x^2+y^2=25");
        if (e) {
            auto* n = dynamic_cast<NativeExpression*>(e.get());
            check(n->GetKind() == NativeEquationKind::ImplicitEquation, "implicit eq kind");
            auto v = n->EvaluateAt(3.0, 4.0);
            if (v) checkEq(*v, 0.0, "F(3,4) == 0");
        }
    }
    {
        auto e = solver.ParseInput(L"y<x^2", ec, et);
        check(static_cast<bool>(e), "parse y<x^2");
        if (e) {
            auto* n = dynamic_cast<NativeExpression*>(e.get());
            check(n->GetKind() == NativeEquationKind::Inequality, "inequality kind");
            check(n->GetInequalityRelation() == "less", "relation less");
            auto v = n->EvaluateAt(2.0, 3.0);  // F = y - x^2 = 3 - 4 = -1
            if (v) checkEq(*v, -1.0, "F=y-x^2 @(2,3) == -1");
        }
    }
    {
        auto e = solver.ParseInput(L"y\u2264x^2", ec, et);  // y≤x^2
        check(static_cast<bool>(e), "parse y<=x^2 (unicode)");
        if (e) {
            auto* n = dynamic_cast<NativeExpression*>(e.get());
            check(n->GetInequalityRelation() == "lessEq", "unicode <= normalized to lessEq");
        }
    }
    {
        auto e = solver.ParseInput(L"2+", ec, et);
        check(!static_cast<bool>(e), "parse 2+ rejected");
    }

    // 2. CreateGrapher + 变量
    {
        auto e = solver.ParseInput(L"y=sin(x)", ec, et);
        auto graph = solver.CreateGrapher(e.get());
        check(static_cast<bool>(graph), "create grapher");
        graph->TryInitialize(nullptr);
        auto vars = graph->GetVariables();
        check(vars.size() >= 1, "variables exist");
        auto r = graph->GetRenderer();
        check(static_cast<bool>(r), "renderer exists");
    }

    // 3. KGF 分析（最小子集）
    {
        auto e = solver.ParseInput(L"y=x^2-2", ec, et);
        check(static_cast<bool>(e), "parse y=x^2-2 for KGF");
        auto graph = solver.CreateGrapher(e.get());
        auto analyzer = graph->GetAnalyzer();
        check(static_cast<bool>(analyzer), "analyzer exists");
        bool varNotX = false;
        check(analyzer->CanFunctionAnalysisBePerformed(varNotX), "KGF applicable");
        check(!varNotX, "variable is x");
        analyzer->PerformFunctionAnalysis(0xFF);
        auto* na = dynamic_cast<GraphAnalyzer*>(analyzer.get());
        if (na) {
            printf("      domain: %ls\n", na->GetDomain().c_str());
            printf("      zeros : %ls\n", na->GetZeros().c_str());
            printf("      yint  : %ls\n", na->GetYIntercept().c_str());
            printf("      parity: %ls\n", na->GetParity().c_str());
            check(!na->GetZeros().empty(), "zeros computed");
            check(na->GetParity() == L"Even", "x^2-2 is even");
        }
        auto data = solver.Analyze(analyzer.get());
        check(!data.Zeros.empty(), "analyze() fills zeros");
    }

    // 4. 渲染器视窗操作
    {
        auto e = solver.ParseInput(L"y=x^2", ec, et);
        auto graph = solver.CreateGrapher(e.get());
        auto r = graph->GetRenderer();
        r->SetGraphSize(800, 600);
        double x0 = 0, x1 = 0, y0 = 0, y1 = 0;
        r->GetDisplayRanges(x0, x1, y0, y1);
        check(x0 == -10 && x1 == 10 && y0 == -10 && y1 == 10, "default range [-10,10]");
        r->ScaleRange(0, 0, 0.5);
        r->GetDisplayRanges(x0, x1, y0, y1);
        check(x1 - x0 == 10, "scale to half span");
        r->ResetRange();
        r->GetDisplayRanges(x0, x1, y0, y1);
        check(x0 == -10 && x1 == 10, "reset range");
        r->MoveRangeByRatio(1.0, 0.0);
        r->GetDisplayRanges(x0, x1, y0, y1);
        // 共享层 graph_pan 语义：dx 正 → 视窗左移（x_min -= dx，与 macOS 一致）。
        checkEq(x0, -30.0, "pan x by one span (viewport moves left)");
    }

    printf("=== RESULT: %s (%d failures) ===\n", g_fail == 0 ? "PASS" : "FAIL", g_fail);
    return g_fail == 0 ? 0 : 1;
}
