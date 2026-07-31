// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

// 上游 IGraphRenderer.h 依赖 GraphingEnums.h 先见（include 顺序缺陷，
// 同 Mocks/GraphRenderer.h 的既有绕过方式）——必须最先包含。
#include "GraphingInterfaces/GraphingEnums.h"
#include "GraphingInterfaces/IMathSolver.h"
#include "NativeExpression.h"
#include "NativeGraphingOptions.h"
#include "NativeGraphAnalyzer.h"

namespace NativeGraphingImpl
{
    // IParsingOptions / IEvalOptions / IFormatOptions 的最小实现（选项当前
    // 均无引擎侧生效点；保留状态以对齐原版接口契约）。
    class ParsingOptionsImpl : public Graphing::IParsingOptions
    {
    public:
        void SetFormatType(Graphing::FormatType /*type*/) override {}
        void SetLocalizationType(Graphing::LocalizationType /*value*/) override {}
    };

    class EvalOptionsImpl : public Graphing::IEvalOptions
    {
    public:
        Graphing::EvalTrigUnitMode GetTrigUnitMode() const override { return m_unit; }
        void SetTrigUnitMode(Graphing::EvalTrigUnitMode value) override { m_unit = value; }

    private:
        Graphing::EvalTrigUnitMode m_unit = Graphing::EvalTrigUnitMode::Invalid;
    };

    class FormatOptionsImpl : public Graphing::IFormatOptions
    {
    public:
        void SetFormatType(Graphing::FormatType /*type*/) override {}
        void SetMathMLPrefix(const std::wstring& /*value*/) override {}
        void SetLocalizationType(Graphing::LocalizationType /*value*/) override {}
    };

    // IMathSolver 的 giac 后端（P-Windows-1/2 求值器 A 方案）。
    // 解析/求值/分析全部经 libgiac_bridge.dll（caseval），与 macOS 侧
    // GiacMathSolver/GiacEngine 同源，行为以 KGF 规格（spec/kgf-reference.md）对齐。
    class MathSolver : public Graphing::IMathSolver
    {
    public:
        MathSolver();
        ~MathSolver() override;

        Graphing::IParsingOptions& ParsingOptions() override { return m_parsingOptions; }
        Graphing::IEvalOptions& EvalOptions() override { return m_evalOptions; }
        Graphing::IFormatOptions& FormatOptions() override { return m_formatOptions; }

        std::unique_ptr<Graphing::IExpression> ParseInput(
            const std::wstring& input, int& errorCodeOut, int& errorTypeOut) override;

        void HRErrorToErrorInfo(HRESULT hr, int& errorCodeOut, int& errorTypeOut) override;

        std::shared_ptr<Graphing::IGraph> CreateGrapher(const Graphing::IExpression* expression) override;
        std::shared_ptr<Graphing::IGraph> CreateGrapher() override;

        std::wstring Serialize(const Graphing::IExpression* expression) override;

        Graphing::IGraphFunctionAnalysisData Analyze(const Graphing::Analyzer::IGraphAnalyzer* analyzer) override;

    private:
        ParsingOptionsImpl m_parsingOptions;
        EvalOptionsImpl m_evalOptions;
        FormatOptionsImpl m_formatOptions;
        std::shared_ptr<GraphingOptions> m_graphingOptions;
        std::shared_ptr<GraphAnalyzer> m_analyzer;
    };
}
