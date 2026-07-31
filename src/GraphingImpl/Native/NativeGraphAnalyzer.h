// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include "GraphingInterfaces/IGraphAnalyzer.h"
#include "NativeExpression.h"

namespace NativeGraphingImpl
{
    // IGraphAnalyzer 的 giac 后端：关键图形特征（KGF）分析。
    // 查询模式对齐 macOS GiacMathSolver（caseval 逐字段查询），
    // 显示规格以 spec/kgf-reference.md 为准。诚实性原则（M4）：
    // 任何字段无法可靠计算时走 TooComplexFeatures 通道，绝不静默给近似值。
    //
    // 本实现为 P-Windows-2 的阶段性交付：先覆盖定义域/截距/奇偶性/渐近线/
    // 单调性/周期/极值/拐点的符号查询，trig 通解族等 S3 记录的「暂不做」
    // 项同样暂缓（与 macOS 同源，行为以 KGF 回归测试为准）。
    class GraphAnalyzer : public Graphing::Analyzer::IGraphAnalyzer
    {
    public:
        explicit GraphAnalyzer(std::shared_ptr<NativeExpression> expression);

        bool CanFunctionAnalysisBePerformed(bool& variableIsNotX) override;
        HRESULT PerformFunctionAnalysis(Graphing::Analyzer::NativeAnalysisType analysisType) override;
        HRESULT GetAnalysisTypeCaption(const Graphing::Analyzer::AnalysisType type, std::wstring& captionOut) const override;
        HRESULT GetMessage(const Graphing::Analyzer::GraphAnalyzerMessage msg, std::wstring& msgOut) const override;

        // KGF 结果访问（渲染层/UI 层消费）。字段空串表示未计算/无值；
        // 走 TooComplexFeatures 的字段以 "TOO_COMPLEX" 标记（调用方映射文案）。
        const std::wstring& GetDomain() const { return m_domain; }
        const std::wstring& GetRange() const { return m_range; }
        const std::wstring& GetZeros() const { return m_zeros; }
        const std::wstring& GetYIntercept() const { return m_yIntercept; }
        const std::vector<std::wstring>& GetMinima() const { return m_minima; }
        const std::vector<std::wstring>& GetMaxima() const { return m_maxima; }
        const std::vector<std::wstring>& GetInflectionPoints() const { return m_inflectionPoints; }
        const std::vector<std::wstring>& GetVerticalAsymptotes() const { return m_verticalAsymptotes; }
        const std::vector<std::wstring>& GetHorizontalAsymptotes() const { return m_horizontalAsymptotes; }
        const std::vector<std::wstring>& GetObliqueAsymptotes() const { return m_obliqueAsymptotes; }
        const std::wstring& GetParity() const { return m_parity; }
        const std::wstring& GetMonotonicity() const { return m_monotonicity; }
        const std::wstring& GetPeriodicity() const { return m_periodicity; }
        unsigned int GetTooComplexFeatures() const { return m_tooComplex; }

        // 判定/播报位标志（对齐原版 PerformAnalysisType 位，见
        // GraphingEnums.h：Domain=0x01 Range=0x02 Parity=0x04
        // InterceptionPoints=0x08 CriticalPoints=0x10 Asymptotes=0x20
        // Monotonicity=0x40 Period=0x80）。
        static constexpr unsigned int kTypeDomainRange = 0x03;
        static constexpr unsigned int kTypeZeros = 0x08;
        static constexpr unsigned int kTypeExtrema = 0x10;
        static constexpr unsigned int kTypeInflection = 0x10;
        static constexpr unsigned int kTypeAsymptotes = 0x20;
        static constexpr unsigned int kTypeParity = 0x04;
        static constexpr unsigned int kTypeMonotonicity = 0x40;
        static constexpr unsigned int kTypePeriodicity = 0x80;

    private:
        // 单字段 giac 查询：返回原始结果文本；失败返回空串。
        std::string Query(const std::string& giacExpr) const;

        // 把 giac 结果解析为字段值；无法可靠解析时置 too complex 位。
        void AnalyzeDomainRange();
        void AnalyzeZerosAndIntercepts();
        void AnalyzeExtrema();
        void AnalyzeInflectionPoints();
        void AnalyzeAsymptotes();
        void AnalyzeParity();
        void AnalyzeMonotonicity();
        void AnalyzePeriodicity();

        std::shared_ptr<NativeExpression> m_expression;
        std::wstring m_domain;
        std::wstring m_range;
        std::wstring m_zeros;
        std::wstring m_yIntercept;
        std::vector<std::wstring> m_minima;
        std::vector<std::wstring> m_maxima;
        std::vector<std::wstring> m_inflectionPoints;
        std::vector<std::wstring> m_verticalAsymptotes;
        std::vector<std::wstring> m_horizontalAsymptotes;
        std::vector<std::wstring> m_obliqueAsymptotes;
        std::wstring m_parity;
        std::wstring m_monotonicity;
        std::wstring m_periodicity;
        unsigned int m_tooComplex = 0;
    };
}
