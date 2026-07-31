// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include "GraphingInterfaces/IEquation.h"
#include "NativeExpression.h"

namespace NativeGraphingImpl
{
    // IEquationOptions 实现：每条方程的样式状态（颜色/线型/线宽/点半径）。
    // 默认值对齐原版（GraphControl 默认线宽 2、点半径 5）。
    class EquationOptions : public Graphing::IEquationOptions
    {
    public:
        EquationOptions()
            : m_color(Graphing::Color(0xFF, 0x4B, 0x00))
        {
        }

        Graphing::Color GetGraphColor() const override { return m_color; }
        void SetGraphColor(const Graphing::Color& color) override { m_color = color; }
        void ResetGraphColor() override { m_color = Graphing::Color(0xFF, 0x4B, 0x00); }

        Graphing::Renderer::LineStyle GetLineStyle() const override { return m_lineStyle; }
        void SetLineStyle(Graphing::Renderer::LineStyle value) override { m_lineStyle = value; }
        void ResetLineStyle() override { m_lineStyle = Graphing::Renderer::LineStyle::Solid; }

        float GetLineWidth() const override { return m_lineWidth; }
        void SetLineWidth(float value) override { m_lineWidth = value; }
        void ResetLineWidth() override { m_lineWidth = 2.0f; }

        float GetSelectedEquationLineWidth() const override { return m_selectedWidth; }
        void SetSelectedEquationLineWidth(float value) override { m_selectedWidth = value; }
        void ResetSelectedEquationLineWidth() override { m_selectedWidth = 3.0f; }

        float GetPointRadius() const override { return m_pointRadius; }
        void SetPointRadius(float value) override { m_pointRadius = value; }
        void ResetPointRadius() override { m_pointRadius = 5.0f; }

        float GetSelectedEquationPointRadius() const override { return m_selectedRadius; }
        void SetSelectedEquationPointRadius(float value) override { m_selectedRadius = value; }
        void ResetSelectedEquationPointRadius() override { m_selectedRadius = 7.0f; }

    private:
        Graphing::Color m_color;
        Graphing::Renderer::LineStyle m_lineStyle = Graphing::Renderer::LineStyle::Solid;
        float m_lineWidth = 2.0f;
        float m_selectedWidth = 3.0f;
        float m_pointRadius = 5.0f;
        float m_selectedRadius = 7.0f;
    };

    // IEquation 实现：绑定一条 NativeExpression + 样式。
    class Equation : public Graphing::IEquation
    {
    public:
        explicit Equation(std::shared_ptr<NativeExpression> expression)
            : m_expression(std::move(expression))
        {
        }

        std::shared_ptr<Graphing::IEquationOptions> GetGraphEquationOptions() const override
        {
            return m_options;
        }

        unsigned int GetGraphEquationID() const override { return m_expression->GetExpressionID(); }

        bool TrySelectEquation() override
        {
            m_selected = true;
            return true;
        }

        bool IsEquationSelected() const override { return m_selected; }

        // 访问底层表达式（避免与类型名 NativeExpression 冲突的命名）。
        const std::shared_ptr<NativeExpression>& GetNativeExpression() const { return m_expression; }

    private:
        std::shared_ptr<NativeExpression> m_expression;
        std::shared_ptr<EquationOptions> m_options = std::make_shared<EquationOptions>();
        bool m_selected = false;
    };
}
