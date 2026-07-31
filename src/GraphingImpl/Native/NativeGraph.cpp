// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "pch.h"
#include "NativeGraph.h"

namespace NativeGraphingImpl
{
    Graph::Graph(std::shared_ptr<NativeExpression> expression)
        : m_graphingOptions(std::make_shared<GraphingOptions>())
    {
        if (expression)
        {
            // 深拷贝：Graph 持有表达式的独立副本，不依赖调用方的生命周期
            //（调用方的 unique_ptr/shared_ptr 析构不影响图内表达式）。
            m_nativeEquations.push_back(std::make_shared<NativeExpression>(*expression));
        }
        m_graphRenderer = std::make_shared<GraphRenderer>(&m_nativeEquations);
        m_analyzer = m_nativeEquations.empty() ? nullptr : std::make_shared<GraphAnalyzer>(m_nativeEquations.front());
    }

    std::optional<std::vector<std::shared_ptr<Graphing::IEquation>>> Graph::TryInitialize(const Graphing::IExpression* graphingExp)
    {
        if (graphingExp)
        {
            // 把新表达式加入方程集合（深拷贝，所有权独立）；返回方程列表给调用方。
            if (auto* native = dynamic_cast<NativeExpression*>(const_cast<Graphing::IExpression*>(graphingExp)))
            {
                bool already = false;
                for (const auto& e : m_nativeEquations)
                {
                    if (e->GetRawUtf8() == native->GetRawUtf8() && e->GetKind() == native->GetKind())
                    {
                        already = true;
                        break;
                    }
                }
                if (!already)
                {
                    m_nativeEquations.push_back(std::make_shared<NativeExpression>(*native));
                }
                m_analyzer = std::make_shared<GraphAnalyzer>(m_nativeEquations.back());
            }
            return std::nullopt;
        }

        // 空初始化：建立变量表（x 或 x,y 取决于方程）。
        m_variables.clear();
        bool needY = false;
        for (const auto& eq : m_nativeEquations)
        {
            if (eq->GetKind() != NativeEquationKind::ExplicitFunction)
            {
                needY = true;
            }
        }
        m_variables.push_back(std::make_shared<Variable>(L"x", 0));
        if (needY)
        {
            m_variables.push_back(std::make_shared<Variable>(L"y", 1));
        }
        m_initError = S_OK;
        return std::nullopt;
    }

    void Graph::SetArgValue(std::wstring variableName, double value)
    {
        m_argValues[variableName] = value;
    }
}
