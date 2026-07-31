// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "pch.h"
#include "NativeMathSolver.h"
#include "NativeGraph.h"
#include "GiacBridgeLoader.h"

#include <cwctype>
#include <memory>
#include <string>
#include <vector>

namespace NativeGraphingImpl
{
    namespace
    {
        // 归一化 Unicode 关系符：≤ → <=，≥ → >=，≠ → 失败。
        void NormalizeRelations(std::wstring& s)
        {
            size_t pos = 0;
            while ((pos = s.find(L"\u2264", pos)) != std::wstring::npos)
            {
                s.replace(pos, 1, L"<=");
                pos += 2;
            }
            pos = 0;
            while ((pos = s.find(L"\u2265", pos)) != std::wstring::npos)
            {
                s.replace(pos, 1, L">=");
                pos += 2;
            }
        }

        // 顶层关系运算符定位（不在函数调用括号内的第一个 = < >）。
        // 返回运算符位置；找不到返回 npos。
        size_t FindTopLevelRelation(const std::wstring& s, std::wstring& opOut)
        {
            int depth = 0;
            for (size_t i = 0; i < s.size(); ++i)
            {
                const wchar_t c = s[i];
                if (c == L'(' || c == L'[')
                {
                    ++depth;
                }
                else if (c == L')' || c == L']')
                {
                    --depth;
                    if (depth < 0)
                    {
                        depth = 0;  // 容忍多余右括号（giac 会报错，走验证）
                    }
                }
                else if (depth == 0)
                {
                    if (c == L'=')
                    {
                        opOut = L"=";
                        return i;
                    }
                    if (c == L'<' || c == L'>')
                    {
                        // 双字符运算符（<= / >=）？
                        if (i + 1 < s.size() && s[i + 1] == L'=')
                        {
                            opOut = (c == L'<') ? L"<=" : L">=";
                            return i;
                        }
                        opOut = std::wstring(1, c);
                        return i;
                    }
                }
            }
            return std::wstring::npos;
        }

        // 去除首尾空白。
        std::wstring Trim(const std::wstring& s)
        {
            const size_t b = s.find_first_not_of(L" \t\r\n");
            if (b == std::wstring::npos)
            {
                return {};
            }
            const size_t e = s.find_last_not_of(L" \t\r\n");
            return s.substr(b, e - b + 1);
        }
    }

    MathSolver::MathSolver()
        : m_graphingOptions(std::make_shared<GraphingOptions>())
    {
    }

    MathSolver::~MathSolver() = default;

    std::unique_ptr<Graphing::IExpression> MathSolver::ParseInput(
        const std::wstring& input, int& errorCodeOut, int& errorTypeOut)
    {
        errorCodeOut = 0;
        errorTypeOut = 0;

        std::wstring text = input;
        NormalizeRelations(text);
        text = Trim(text);
        if (text.empty())
        {
            errorCodeOut = 1;  // 空输入
            return nullptr;
        }

        // 分类：显式 y=f(x) / 隐式 F(x,y)=0 / 不等式 F rel 0。
        std::wstring op;
        const size_t opPos = FindTopLevelRelation(text, op);
        std::wstring lhs, rhs;
        NativeEquationKind kind = NativeEquationKind::ExplicitFunction;
        std::wstring rel;

        if (opPos != std::wstring::npos)
        {
            lhs = Trim(text.substr(0, opPos));
            rhs = Trim(text.substr(opPos + op.size()));
            if (rhs.empty())
            {
                errorCodeOut = 2;  // 缺右侧
                return nullptr;
            }
            if (op == L"=")
            {
                // y = f(x) → 显式；否则隐式 F(x,y)=0。
                const bool lhsIsY = (lhs == L"y") || (lhs.size() >= 3 && lhs.substr(0, 2) == L"y(" && lhs.back() == L')');
                if (lhsIsY)
                {
                    kind = NativeEquationKind::ExplicitFunction;
                }
                else
                {
                    kind = NativeEquationKind::ImplicitEquation;
                }
            }
            else
            {
                // 不等式：y < f(x) 或 F(x,y) < 0 形式。
                kind = NativeEquationKind::Inequality;
                rel = (op == L"<") ? L"less" : ((op == L">") ? L"greater" : ((op == L"<=") ? L"lessEq" : L"greaterEq"));
                if (lhs != L"y")
                {
                    // F(x,y) rel 0 形式：保持 F = lhs - rhs 语义，关系方向不变。
                    // 注意：y < f(x) 写成 F = y - f(x) < 0；F(x,y) < 0 写成
                    // F 原样 - 0。两种输入统一为「F 的符号判定」。
                }
            }
        }
        else
        {
            // 无关系运算符：纯表达式。含 y 视为隐式 F(x,y)=0（如 x^2+y^2-25），
            // 否则显式 y=f(x)（如 x^2-2）。
            text.find(L'y') != std::wstring::npos ? kind = NativeEquationKind::ImplicitEquation : kind = NativeEquationKind::ExplicitFunction;
        }

        // 构造 F 主体（归一化为「左侧减右侧」形式，供求值/分析）。
        std::wstring body;
        std::wstring vars = L"x";
        switch (kind)
        {
        case NativeEquationKind::ExplicitFunction:
            body = (opPos == std::wstring::npos) ? text : rhs;
            break;
        case NativeEquationKind::ImplicitEquation:
            // F = (lhs) - (rhs)；无运算符时 F = 原文本。
            body = (opPos == std::wstring::npos) ? text : (L"(" + lhs + L")-(" + rhs + L")");
            vars = L"x,y";
            break;
        case NativeEquationKind::Inequality:
            // F = (lhs) - (rhs)；y < f(x) → y - f(x)，符号判定关系方向不变。
            body = L"(" + lhs + L")-(" + rhs + L")";
            vars = L"x,y";
            break;
        default:
            errorCodeOut = 3;  // 不支持的类别
            return nullptr;
        }

        // UTF-8 转换后构造 NativeExpression（构造内做 giac 校验）。
        std::string utf8Body;
        {
            const int len = WideCharToMultiByte(CP_UTF8, 0, body.data(), static_cast<int>(body.size()), nullptr, 0, nullptr, nullptr);
            utf8Body.resize(static_cast<size_t>(len));
            WideCharToMultiByte(CP_UTF8, 0, body.data(), static_cast<int>(body.size()), utf8Body.data(), len, nullptr, nullptr);
        }
        std::string utf8Rel;
        {
            const int len = WideCharToMultiByte(CP_UTF8, 0, rel.data(), static_cast<int>(rel.size()), nullptr, 0, nullptr, nullptr);
            utf8Rel.resize(static_cast<size_t>(len));
            WideCharToMultiByte(CP_UTF8, 0, rel.data(), static_cast<int>(rel.size()), utf8Rel.data(), len, nullptr, nullptr);
        }
        std::string utf8Vars;
        {
            const int len = WideCharToMultiByte(CP_UTF8, 0, vars.data(), static_cast<int>(vars.size()), nullptr, 0, nullptr, nullptr);
            utf8Vars.resize(static_cast<size_t>(len));
            WideCharToMultiByte(CP_UTF8, 0, vars.data(), static_cast<int>(vars.size()), utf8Vars.data(), len, nullptr, nullptr);
        }

        auto expr = std::make_unique<NativeExpression>(input, kind, utf8Body, utf8Rel, utf8Vars, false);
        if (!expr->IsValid())
        {
            errorCodeOut = 4;  // giac 校验失败（语法错误）
            return nullptr;
        }
        return expr;
    }

    void MathSolver::HRErrorToErrorInfo(HRESULT hr, int& errorCodeOut, int& errorTypeOut)
    {
        errorCodeOut = static_cast<int>(hr & 0xFFFF);
        errorTypeOut = 0;
    }

    std::shared_ptr<Graphing::IGraph> MathSolver::CreateGrapher(const Graphing::IExpression* expression)
    {
        std::shared_ptr<NativeExpression> native;
        if (const auto* n = dynamic_cast<const NativeExpression*>(expression))
        {
            native = std::const_pointer_cast<NativeExpression>(std::shared_ptr<const NativeExpression>(n, [](const NativeExpression*) {}));
        }
        // 空表达式 → 空图（Graph 内部深拷贝表达式，不持有裸指针）。
        return std::make_shared<Graph>(native);
    }

    std::shared_ptr<Graphing::IGraph> MathSolver::CreateGrapher()
    {
        return std::make_shared<Graph>();
    }

    std::wstring MathSolver::Serialize(const Graphing::IExpression* expression)
    {
        if (const auto* n = dynamic_cast<const NativeExpression*>(expression))
        {
            return n->GetRawText();
        }
        return {};
    }

    Graphing::IGraphFunctionAnalysisData MathSolver::Analyze(const Graphing::Analyzer::IGraphAnalyzer* analyzer)
    {
        // 从 NativeGraphAnalyzer 读取结果，组装 IGraphFunctionAnalysisData。
        // 字段语义对齐 IMathSolver.h 注释与 macOS GiacMathSolver 输出。
        Graphing::IGraphFunctionAnalysisData data;
        const auto* native = dynamic_cast<const GraphAnalyzer*>(analyzer);
        if (!native)
        {
            return data;
        }
        data.Domain = native->GetDomain();
        data.Range = native->GetRange();
        data.Zeros = native->GetZeros();
        data.YIntercept = native->GetYIntercept();
        data.Minima = native->GetMinima();
        data.Maxima = native->GetMaxima();
        data.InflectionPoints = native->GetInflectionPoints();
        data.VerticalAsymptotes = native->GetVerticalAsymptotes();
        data.HorizontalAsymptotes = native->GetHorizontalAsymptotes();
        data.ObliqueAsymptotes = native->GetObliqueAsymptotes();
        data.MonotoneIntervals.clear();
        data.TooComplexFeatures = static_cast<int>(native->GetTooComplexFeatures());
        // 奇偶性/周期映射到整数枚举（原版 GraphEnums：Parity 0=odd 1=even 2=neither）。
        if (native->GetParity() == L"Even")
        {
            data.Parity = 1;
        }
        else if (native->GetParity() == L"Odd")
        {
            data.Parity = 0;
        }
        else if (!native->GetParity().empty())
        {
            data.Parity = 2;
        }
        // 周期方向：PeriodicityDirection 0=无/不可用 1=周期 2=非周期。
        if (native->GetPeriodicity() == L"Non-periodic")
        {
            data.PeriodicityDirection = 2;
        }
        else if (!native->GetPeriodicity().empty())
        {
            data.PeriodicityDirection = 1;
            data.PeriodicityExpression = native->GetPeriodicity();
        }
        return data;
    }
}
