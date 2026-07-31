// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include <memory>
#include <optional>
#include <string>

#include "GraphingInterfaces/Common.h"

namespace NativeGraphingImpl
{
    // 表达式分类（对齐原版 EquationViewModel 的三类绘制路径）：
    //   显式 y=f(x)        → 逐列采样
    //   隐式 F(x,y)=0      → marching squares
    //   不等式 F(x,y) rel 0 → 区域着色 + 边界
    enum class NativeEquationKind
    {
        ExplicitFunction,
        ImplicitEquation,
        Inequality,
        // 参数方程 / 极坐标暂不支持（giac 侧可解析，渲染路径为 P-Windows-2 后续项）
        Unsupported,
    };

    // 一条已解析的绘图表达式。求值全部经 giac_bridge DLL（caseval）。
    // 与 macOS 侧 GraphExpression（自研 AST）是不同实现路径，行为以 KGF/原版规格对齐。
    class NativeExpression final : public Graphing::IExpression
    {
    public:
        NativeExpression(
            std::wstring raw,
            NativeEquationKind kind,
            std::string explicitRhs,   // 显式：等号右侧；隐式/不等式：F（已归一化为 lhs-rhs）
            std::string inequalityRelation,  // 不等式：less/lessEq/greater/greaterEq；其它为空
            std::string variableNames,       // 逗号分隔的变量名（x 或 x,y）
            bool isEmptySet);

        // 拷贝构造：Graph 持有表达式的独立副本（所有权语义，防止调用方
        // unique_ptr 析构后图内悬垂——见 NativeGraph.cpp）。
        NativeExpression(const NativeExpression& other);

        unsigned int GetExpressionID() const override { return m_id; }
        bool IsEmptySet() const override { return m_isEmptySet; }

        const std::wstring& GetRawText() const { return m_raw; }
        NativeEquationKind GetKind() const { return m_kind; }

        // UTF-8 形式的原始输入（giac 求值用）。
        const std::string& GetRawUtf8() const { return m_rawUtf8; }

        // 归一化主体（UTF-8）：显式 = 等号右侧；隐式/不等式 = (lhs)-(rhs)。
        // 分析/求值一律用 body，不得用原始输入（原始输入含 "y=" 前缀会被
        // giac 当赋值语句处理，导致 domain/solve 等命令失效甚至崩溃）。
        const std::string& GetBodyUtf8() const { return m_explicitRhs; }

        // 求值（数值）。显式：y=f(x)；隐式/不等式：F(x,y)。
        // 失败（未定义/解析失败/引擎错误）返回 nullopt。
        std::optional<double> EvaluateAt(double x, std::optional<double> y = std::nullopt) const;

        // giac 侧校验是否可解析（ParseInput 已调用一次，此处仅暴露结果）。
        bool IsValid() const { return m_valid; }
        const std::string& ValidationError() const { return m_validationError; }

        // 变量名列表（x、x,y 等）。
        const std::string& GetVariableNames() const { return m_variableNames; }

        // 不等式关系（仅 kind==Inequality 时非空）：less / lessEq / greater / greaterEq。
        const std::string& GetInequalityRelation() const { return m_inequalityRelation; }

    private:
        unsigned int m_id;
        std::wstring m_raw;
        std::string m_rawUtf8;
        NativeEquationKind m_kind;
        std::string m_explicitRhs;
        std::string m_inequalityRelation;
        std::string m_variableNames;
        bool m_isEmptySet;
        bool m_valid = false;
        std::string m_validationError;
    };
}
