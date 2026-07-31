// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include <map>
#include <memory>
#include <optional>
#include <vector>

// 上游 IGraphRenderer.h 依赖 GraphingEnums.h 先见（include 顺序缺陷）。
#include "GraphingInterfaces/GraphingEnums.h"
#include "GraphingInterfaces/IGraph.h"
#include "NativeExpression.h"
#include "NativeGraphingOptions.h"
#include "NativeGraphRenderer.h"
#include "NativeGraphAnalyzer.h"
#include "NativeEquation.h"

namespace NativeGraphingImpl
{
    // IGraph 的 giac 后端：持有方程集合、渲染器、分析器与绘图选项。
    class Graph : public Graphing::IGraph
    {
    public:
        explicit Graph(std::shared_ptr<NativeExpression> expression = nullptr);

        std::optional<std::vector<std::shared_ptr<Graphing::IEquation>>> TryInitialize(const Graphing::IExpression* graphingExp = nullptr) override;

        HRESULT GetInitializationError() const override { return m_initError; }

        Graphing::IGraphingOptions& GetOptions() override { return *m_graphingOptions; }

        std::vector<std::shared_ptr<Graphing::IVariable>> GetVariables() override { return m_variables; }

        void SetArgValue(std::wstring variableName, double value) override;

        std::shared_ptr<Graphing::Renderer::IGraphRenderer> GetRenderer() const override { return m_graphRenderer; }

        bool TryResetSelection() override { return true; }

        std::shared_ptr<Graphing::Analyzer::IGraphAnalyzer> GetAnalyzer() const override { return m_analyzer; }

        // 供渲染器/分析器访问内部方程（Native 层内部接口）。
        const std::vector<std::shared_ptr<NativeExpression>>& NativeEquations() const { return m_nativeEquations; }
        const std::map<std::wstring, double>& ArgValues() const { return m_argValues; }

    private:
        class Variable : public Graphing::IVariable
        {
        public:
            explicit Variable(const std::wstring& name, int id)
                : m_name(name)
                , m_id(id)
            {
            }
            int GetVariableID() const override { return m_id; }
            const std::wstring& GetVariableName() override { return m_name; }

        private:
            std::wstring m_name;
            int m_id;
        };

        std::vector<std::shared_ptr<Graphing::IVariable>> m_variables;
        std::vector<std::shared_ptr<NativeExpression>> m_nativeEquations;
        std::map<std::wstring, double> m_argValues;
        std::shared_ptr<GraphingOptions> m_graphingOptions;
        std::shared_ptr<GraphRenderer> m_graphRenderer;
        std::shared_ptr<GraphAnalyzer> m_analyzer;
        HRESULT m_initError = S_OK;
    };
}
