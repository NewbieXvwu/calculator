// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "pch.h"
#include "NativeGraphAnalyzer.h"
#include "GiacBridgeLoader.h"

#include <sstream>

namespace NativeGraphingImpl
{
    namespace
    {
        std::wstring FromUtf8(const std::string& s)
        {
            if (s.empty())
            {
                return {};
            }
            const int len = MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0);
            std::wstring out(static_cast<size_t>(len), L'\0');
            MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), len);
            return out;
        }

        // giac 结果文本 → 判定是否可信（特殊记号黑名单，对齐 macOS S3·R1）。
        bool IsTrustedResult(const std::string& s)
        {
            return s.find("GIAC_ERROR") == std::string::npos &&
                   s.find("bounded_function") == std::string::npos &&
                   s.find("undef") == std::string::npos &&
                   !s.empty();
        }
    }

    GraphAnalyzer::GraphAnalyzer(std::shared_ptr<NativeExpression> expression)
        : m_expression(std::move(expression))
    {
    }

    bool GraphAnalyzer::CanFunctionAnalysisBePerformed(bool& variableIsNotX)
    {
        variableIsNotX = m_expression->GetVariableNames() != "x";
        return m_expression->IsValid() && m_expression->GetKind() == NativeEquationKind::ExplicitFunction;
    }

    HRESULT GraphAnalyzer::PerformFunctionAnalysis(Graphing::Analyzer::NativeAnalysisType analysisType)
    {
        bool variableIsNotX = false;
        if (!CanFunctionAnalysisBePerformed(variableIsNotX))
        {
            // 非显式函数（隐式/不等式）不做 KGF——与 macOS/原版一致（原版 KGF
            // 仅适用于显式 y=f(x)）。调用方应先用 CanFunctionAnalysisBePerformed。
            m_tooComplex = static_cast<unsigned int>(-1);
            return S_OK;
        }

        if (analysisType & kTypeDomainRange)
        {
            AnalyzeDomainRange();
        }
        if (analysisType & kTypeZeros)
        {
            AnalyzeZerosAndIntercepts();
        }
        if (analysisType & kTypeExtrema)
        {
            AnalyzeExtrema();
        }
        if (analysisType & kTypeInflection)
        {
            AnalyzeInflectionPoints();
        }
        if (analysisType & kTypeAsymptotes)
        {
            AnalyzeAsymptotes();
        }
        if (analysisType & kTypeParity)
        {
            AnalyzeParity();
        }
        if (analysisType & kTypeMonotonicity)
        {
            AnalyzeMonotonicity();
        }
        if (analysisType & kTypePeriodicity)
        {
            AnalyzePeriodicity();
        }
        return S_OK;
    }

    HRESULT GraphAnalyzer::GetAnalysisTypeCaption(const Graphing::Analyzer::AnalysisType type, std::wstring& captionOut) const
    {
        // 对齐原版 GraphAnalyzer 的类型标题（resw GraphAnalysisType* 文案，
        // 具体本地化文案由 UI 层映射；此处给英文占位，同原版 en-US）。
        switch (type)
        {
        case Graphing::Analyzer::AnalysisType_Domain:
            captionOut = L"Domain";
            break;
        case Graphing::Analyzer::AnalysisType_Range:
            captionOut = L"Range";
            break;
        case Graphing::Analyzer::AnalysisType_Zeros:
            captionOut = L"X intercepts";
            break;
        case Graphing::Analyzer::AnalysisType_YIntercept:
            captionOut = L"Y intercept";
            break;
        case Graphing::Analyzer::AnalysisType_Minima:
            captionOut = L"Minima";
            break;
        case Graphing::Analyzer::AnalysisType_Maxima:
            captionOut = L"Maxima";
            break;
        case Graphing::Analyzer::AnalysisType_InflectionPoints:
            captionOut = L"Inflection points";
            break;
        case Graphing::Analyzer::AnalysisType_VerticalAsymptotes:
            captionOut = L"Vertical asymptotes";
            break;
        case Graphing::Analyzer::AnalysisType_HorizontalAsymptotes:
            captionOut = L"Horizontal asymptotes";
            break;
        case Graphing::Analyzer::AnalysisType_ObliqueAsymptotes:
            captionOut = L"Oblique asymptotes";
            break;
        case Graphing::Analyzer::AnalysisType_Parity:
            captionOut = L"Parity";
            break;
        case Graphing::Analyzer::AnalysisType_Monotonicity:
            captionOut = L"Monotonicity";
            break;
        case Graphing::Analyzer::AnalysisType_Period:
            captionOut = L"Periodicity";
            break;
        default:
            captionOut = L"";
            return E_INVALIDARG;
        }
        return S_OK;
    }

    HRESULT GraphAnalyzer::GetMessage(const Graphing::Analyzer::GraphAnalyzerMessage msg, std::wstring& msgOut) const
    {
        switch (msg)
        {
        case Graphing::Analyzer::GraphAnalyzerMessage_TheseFeaturesAreTooComplexToCalculate:
            msgOut = L"These features are too complex for the calculator to compute.";
            return S_OK;
        case Graphing::Analyzer::GraphAnalyzerMessage_NotAbleToCalculate:
            msgOut = L"Unable to calculate";
            return S_OK;
        case Graphing::Analyzer::GraphAnalyzerMessage_NoZeros:
            msgOut = L"No zeros";
            return S_OK;
        case Graphing::Analyzer::GraphAnalyzerMessage_NoYIntercept:
            msgOut = L"No y-intercept";
            return S_OK;
        case Graphing::Analyzer::GraphAnalyzerMessage_NoMinima:
            msgOut = L"No minima";
            return S_OK;
        case Graphing::Analyzer::GraphAnalyzerMessage_NoMaxima:
            msgOut = L"No maxima";
            return S_OK;
        case Graphing::Analyzer::GraphAnalyzerMessage_NoInflectionPoints:
            msgOut = L"No inflection points";
            return S_OK;
        case Graphing::Analyzer::GraphAnalyzerMessage_NoVerticalAsymptotes:
            msgOut = L"No vertical asymptotes";
            return S_OK;
        case Graphing::Analyzer::GraphAnalyzerMessage_NoHorizontalAsymptotes:
            msgOut = L"No horizontal asymptotes";
            return S_OK;
        case Graphing::Analyzer::GraphAnalyzerMessage_NoObliqueAsymptotes:
            msgOut = L"No oblique asymptotes";
            return S_OK;
        case Graphing::Analyzer::GraphAnalyzerMessage_None:
            msgOut = L"No data";
            return S_OK;
        default:
            msgOut = L"";
            return E_INVALIDARG;
        }
    }

    std::string GraphAnalyzer::Query(const std::string& giacExpr) const
    {
        std::string out;
        std::string warnings;
        if (!GiacBridgeLoader::Instance().Evaluate(giacExpr.c_str(), out, &warnings))
        {
            return {};
        }
        return IsTrustedResult(out) ? out : std::string{};
    }

    void GraphAnalyzer::AnalyzeDomainRange()
    {
        // 定义域：直接查 giac 的 domain（符号形式）。
        const std::string expr = "domain(" + m_expression->GetRawUtf8() + ")";
        const std::string raw = Query(expr);
        if (raw.empty())
        {
            m_tooComplex |= kTypeDomainRange;
            return;
        }
        // 归一化：giac 返回 "x^2-2 的定义域" 类文本（x 不等于 ±√2）。
        // 原版格式：x ∈ ℝ / x ≠ 0 / x ≥ 0。此处做最粗粒度归一化，详细格式
        // 对齐（KGF 回归）在 P-Windows 验证阶段补。
        m_domain = FromUtf8(raw);
        // 值域：R2 构造式（驻点值∪端点极限∪VA 单侧极限）在 Windows 侧
        // 同样复杂，本次诚实标 too complex（与 macOS S3 的 R2 同源）。
        m_tooComplex |= kTypeDomainRange;
    }

    void GraphAnalyzer::AnalyzeZerosAndIntercepts()
    {
        // 零点：solve(f=0,x)。原版格式：x = −√2 or x = 0 or x = √2（英文 or）。
        const std::string raw = Query("solve(" + m_expression->GetRawUtf8() + "=0,x)");
        if (raw.empty())
        {
            m_tooComplex |= kTypeZeros;
            return;
        }
        if (raw == "[]" || raw == "∅")
        {
            m_zeros = L"\u2205";  // ∅
        }
        else
        {
            // list[...] → 拆成 x = ... or x = ...（对齐原版分隔）。
            m_zeros = FromUtf8(raw);
            if (m_zeros.size() >= 5 && m_zeros.substr(0, 5) == L"list[")
            {
                m_zeros = m_zeros.substr(5, m_zeros.size() - 6);
            }
            std::wstring joined;
            size_t pos = 0;
            while (pos < m_zeros.size())
            {
                size_t comma = m_zeros.find(L',', pos);
                std::wstring item = m_zeros.substr(pos, comma == std::wstring::npos ? std::wstring::npos : comma - pos);
                if (!item.empty())
                {
                    if (!joined.empty())
                    {
                        joined += L" or ";
                    }
                    joined += L"x = " + item;
                }
                if (comma == std::wstring::npos)
                {
                    break;
                }
                pos = comma + 1;
            }
            m_zeros = joined.empty() ? L"\u2205" : joined;
        }

        // Y 截距：f(0)。
        const std::string yraw = Query("subst(" + m_expression->GetRawUtf8() + ",x=0)");
        if (yraw.empty())
        {
            m_tooComplex |= kTypeZeros;
        }
        else
        {
            m_yIntercept = FromUtf8(yraw);
        }
    }

    void GraphAnalyzer::AnalyzeExtrema()
    {
        // 极值：extrema(f,x)（giac 符号解）。输出 (x,y) 列表。
        const std::string raw = Query("extrema(" + m_expression->GetRawUtf8() + ",x)");
        if (raw.empty() || raw == "[]")
        {
            return;  // 无极值或查询失败——失败时保持空（UI 显示「无」），
                     // 但若含 GIAC_ERROR 已在 IsTrustedResult 过滤。
        }
        // giac 返回如 [[x1,y1],[x2,y2]]（极小+极大可能混排）。
        // 需区分 min/max：对每个候选点比较 f'' 符号或直接比较候选间——本次
        // 诚实处理：全部标 too complex，避免把符号解的点错分类（M4）。
        m_tooComplex |= kTypeExtrema;
    }

    void GraphAnalyzer::AnalyzeInflectionPoints()
    {
        // 拐点：f''=0 的解。本次仅做查询，输出格式对齐留待 KGF 对照。
        const std::string raw = Query("solve(diff(" + m_expression->GetRawUtf8() + ",x,2)=0,x)");
        if (raw.empty() || raw == "[]")
        {
            return;
        }
        // 数值/符号混合解在 Windows 侧暂不做过滤（bisection 拒收判据同 macOS
        // R4：stderr bisection 提示已由 Query 的 warnings 捕获，此处简化）。
        m_tooComplex |= kTypeInflection;
    }

    void GraphAnalyzer::AnalyzeAsymptotes()
    {
        // 垂直渐近线：denominator 零点（macOS S3 已验证的正确路径）。
        const std::string vraw = Query("solve(denom(normal(" + m_expression->GetRawUtf8() + "))=0,x)");
        if (vraw.empty() || vraw == "[]")
        {
            m_verticalAsymptotes.clear();
        }
        else
        {
            // list[2] → x = 2 形式（对齐原版方程形式）。
            m_verticalAsymptotes.clear();
            std::wstring inner = FromUtf8(vraw);
            if (inner.size() >= 5 && inner.substr(0, 5) == L"list[")
            {
                inner = inner.substr(5, inner.size() - 6);
            }
            size_t pos = 0;
            while (pos <= inner.size())
            {
                size_t comma = inner.find(L',', pos);
                std::wstring item = inner.substr(pos, comma == std::wstring::npos ? std::wstring::npos : comma - pos);
                if (!item.empty())
                {
                    m_verticalAsymptotes.push_back(L"x = " + item);
                }
                if (comma == std::wstring::npos)
                {
                    break;
                }
                pos = comma + 1;
            }
        }

        // 水平渐近线：limit 双侧。`+infinity` 记号需过滤（黑名单已含）。
        const std::string plus = Query("limit(" + m_expression->GetRawUtf8() + ",x,+inf)");
        const std::string minus = Query("limit(" + m_expression->GetRawUtf8() + ",x,-inf)");
        m_horizontalAsymptotes.clear();
        if (!plus.empty() && plus.find("infinity") == std::string::npos && plus != "+inf" && plus != "-inf")
        {
            m_horizontalAsymptotes.push_back(L"y = " + FromUtf8(plus));
        }
        if (!minus.empty() && minus.find("infinity") == std::string::npos && minus != "+inf" && minus != "-inf" && minus != plus)
        {
            m_horizontalAsymptotes.push_back(L"y = " + FromUtf8(minus));
        }
        // 斜渐近线：本次标 too complex（符号求斜渐近线需多步化简）。
        m_tooComplex |= kTypeAsymptotes;
    }

    void GraphAnalyzer::AnalyzeParity()
    {
        const std::string f = m_expression->GetRawUtf8();
        // f(x) - f(-x) == 0 → 偶；f(x) + f(-x) == 0 → 奇。
        const std::string even = Query("normal(" + f + "-subst(" + f + ",x=-x))");
        const std::string odd = Query("normal(" + f + "+subst(" + f + ",x=-x))");
        if (even == "0")
        {
            m_parity = L"Even";  // 原版：偶函数
        }
        else if (odd == "0")
        {
            m_parity = L"Odd";  // 原版：奇函数
        }
        else
        {
            m_parity = L"Neither even nor odd";  // 原版：非奇非偶
        }
    }

    void GraphAnalyzer::AnalyzeMonotonicity()
    {
        // 单调性：macOS S3·R3/R4 的坑（Auto assume 截断、bisection 冒充）在
        // Windows 侧同样存在且需同样的门控（warnings 含 "Auto assume"/bisection
        // → too complex）。本次诚实：整体标 too complex，待 KGF 回归对照时
        // 与 macOS 同构实现。
        m_tooComplex |= kTypeMonotonicity;
    }

    void GraphAnalyzer::AnalyzePeriodicity()
    {
        const std::string raw = Query("period(" + m_expression->GetRawUtf8() + ",x)");
        if (raw.empty())
        {
            return;
        }
        if (raw == "0")
        {
            // period()==0 → 任意周期/不适用 → 不显示周期字段（macOS R6）。
            m_periodicity.clear();
        }
        else if (raw.find("inf") != std::string::npos)
        {
            m_periodicity = L"Non-periodic";
        }
        else
        {
            m_periodicity = FromUtf8(raw);
        }
    }
}
