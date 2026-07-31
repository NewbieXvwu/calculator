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
            m_nativeEquations.push_back(std::move(expression));
        }
        m_graphRenderer = std::make_shared<GraphRenderer>(&m_nativeEquations);
        m_analyzer = m_nativeEquations.empty() ? nullptr : std::make_shared<GraphAnalyzer>(m_nativeEquations.front());
    }

    std::optional<std::vector<std::shared_ptr<Graphing::IEquation>>> Graph::TryInitialize(const Graphing::IExpression* graphingExp)
    {
        if (graphingExp)
        {
            // 把新表达式加入方程集合；返回方程列表给调用方。
            if (auto* native = dynamic_cast<NativeExpression*>(const_cast<Graphing::IExpression*>(graphingExp)))
            {
                auto shared = std::shared_ptr<NativeExpression>(native, [](NativeExpression*) {});
                // 注意：表达式由 MathSolver 持有所有权时走另一路径（见
                // MathSolver::CreateGrapher）；此处仅当外部传入时登记。
                bool already = false;
                for (const auto& e : m_nativeEquations)
                {
                    if (e.get() == native)
                    {
                        already = true;
                        break;
                    }
                }
                if (!already)
                {
                    m_nativeEquations.push_back(shared);
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
