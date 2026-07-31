// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include "GraphingInterfaces/IGraphingOptions.h"

namespace NativeGraphingImpl
{
    // IGraphingOptions 的完整实现：全部选项带默认值与状态。
    // 默认值对齐原版 GraphControl（x/y 默认 [-10,10]，14 色色板见
    // spec/graph-colors.json，线宽/半径默认取原版 GraphControl 常量）。
    class GraphingOptions : public Graphing::IGraphingOptions
    {
    public:
        GraphingOptions();

        void ResetMarkKeyGraphFeaturesData() override;

        bool GetMarkZeros() const override { return m_markZeros; }
        void SetMarkZeros(bool value) override { m_markZeros = value; }

        bool GetMarkYIntercept() const override { return m_markYIntercept; }
        void SetMarkYIntercept(bool value) override { m_markYIntercept = value; }

        bool GetMarkMinima() const override { return m_markMinima; }
        void SetMarkMinima(bool value) override { m_markMinima = value; }

        bool GetMarkMaxima() const override { return m_markMaxima; }
        void SetMarkMaxima(bool value) override { m_markMaxima = value; }

        bool GetMarkInflectionPoints() const override { return m_markInflectionPoints; }
        void SetMarkInflectionPoints(bool value) override { m_markInflectionPoints = value; }

        bool GetMarkVerticalAsymptotes() const override { return m_markVerticalAsymptotes; }
        void SetMarkVerticalAsymptotes(bool value) override { m_markVerticalAsymptotes = value; }

        bool GetMarkHorizontalAsymptotes() const override { return m_markHorizontalAsymptotes; }
        void SetMarkHorizontalAsymptotes(bool value) override { m_markHorizontalAsymptotes = value; }

        bool GetMarkObliqueAsymptotes() const override { return m_markObliqueAsymptotes; }
        void SetMarkObliqueAsymptotes(bool value) override { m_markObliqueAsymptotes = value; }

        unsigned long long GetMaxExecutionTime() const override { return m_maxExecutionTime; }
        void SetMaxExecutionTime(unsigned long long value) override { m_maxExecutionTime = value; }
        void ResetMaxExecutionTime() override { m_maxExecutionTime = kDefaultMaxExecutionTime; }

        std::vector<Graphing::Color> GetGraphColors() const override { return m_graphColors; }
        bool SetGraphColors(const std::vector<Graphing::Color>& colors) override
        {
            if (colors.empty())
            {
                return false;
            }
            m_graphColors = colors;
            return true;
        }
        void ResetGraphColors() override { m_graphColors = kDefaultColors; }

        Graphing::Color GetBackColor() const override { return m_backColor; }
        void SetBackColor(const Graphing::Color& value) override { m_backColor = value; }
        void ResetBackColor() override { m_backColor = kDefaultBackColor; }

        void SetAllowKeyGraphFeaturesForFunctionsWithParameters(bool kgf) override { m_allowKgf = kgf; }
        bool GetAllowKeyGraphFeaturesForFunctionsWithParameters() const override { return m_allowKgf; }
        void ResetAllowKeyGraphFeaturesForFunctionsWithParameters() override { m_allowKgf = false; }

        Graphing::Color GetZerosColor() const override { return m_zerosColor; }
        void SetZerosColor(const Graphing::Color& value) override { m_zerosColor = value; }
        void ResetZerosColor() override { m_zerosColor = kDefaultZerosColor; }

        Graphing::Color GetExtremaColor() const override { return m_extremaColor; }
        void SetExtremaColor(const Graphing::Color& value) override { m_extremaColor = value; }
        void ResetExtremaColor() override { m_extremaColor = kDefaultExtremaColor; }

        Graphing::Color GetInflectionPointsColor() const override { return m_inflectionColor; }
        void SetInflectionPointsColor(const Graphing::Color& value) override { m_inflectionColor = value; }
        void ResetInflectionPointsColor() override { m_inflectionColor = kDefaultInflectionColor; }

        Graphing::Color GetAsymptotesColor() const override { return m_asymptotesColor; }
        void SetAsymptotesColor(const Graphing::Color& value) override { m_asymptotesColor = value; }
        void ResetAsymptotesColor() override { m_asymptotesColor = kDefaultAsymptotesColor; }

        Graphing::Color GetAxisColor() const override { return m_axisColor; }
        void SetAxisColor(const Graphing::Color& value) override { m_axisColor = value; }
        void ResetAxisColor() override { m_axisColor = kDefaultAxisColor; }

        Graphing::Color GetBoxColor() const override { return m_boxColor; }
        void SetBoxColor(const Graphing::Color& value) override { m_boxColor = value; }
        void ResetBoxColor() override { m_boxColor = kDefaultBoxColor; }

        Graphing::Color GetGridColor() const override { return m_gridColor; }
        void SetGridColor(const Graphing::Color& value) override { m_gridColor = value; }
        void ResetGridColor() override { m_gridColor = kDefaultGridColor; }

        Graphing::Color GetFontColor() const override { return m_fontColor; }
        void SetFontColor(const Graphing::Color& value) override { m_fontColor = value; }
        void ResetFontColor() override { m_fontColor = kDefaultFontColor; }

        bool GetShowAxis() const override { return m_showAxis; }
        void SetShowAxis(bool value) override { m_showAxis = value; }
        void ResetShowAxis() override { m_showAxis = true; }

        bool GetShowGrid() const override { return m_showGrid; }
        void SetShowGrid(bool value) override { m_showGrid = value; }
        void ResetShowGrid() override { m_showGrid = true; }

        bool GetShowBox() const override { return m_showBox; }
        void SetShowBox(bool value) override { m_showBox = value; }
        void ResetShowBox() override { m_showBox = true; }

        bool GetForceProportional() const override { return m_forceProportional; }
        void SetForceProportional(bool value) override { m_forceProportional = value; }
        void ResetForceProportional() override { m_forceProportional = false; }

        std::wstring GetAliasX() const override { return m_aliasX; }
        void SetAliasX(const std::wstring& value) override { m_aliasX = value; }
        void ResetAliasX() override { m_aliasX = L"x"; }

        std::wstring GetAliasY() const override { return m_aliasY; }
        void SetAliasY(const std::wstring& value) override { m_aliasY = value; }
        void ResetAliasY() override { m_aliasY = L"y"; }

        Graphing::Renderer::LineStyle GetLineStyle() const override { return m_lineStyle; }
        void SetLineStyle(Graphing::Renderer::LineStyle value) override { m_lineStyle = value; }
        void ResetLineStyle() override { m_lineStyle = Graphing::Renderer::LineStyle::Solid; }

        std::pair<double, double> GetDefaultXRange() const override { return m_defaultXRange; }
        bool SetDefaultXRange(const std::pair<double, double>& minmax) override
        {
            if (!(minmax.first < minmax.second))
            {
                return false;
            }
            m_defaultXRange = minmax;
            return true;
        }
        void ResetDefaultXRange() override { m_defaultXRange = { -10.0, 10.0 }; }

        std::pair<double, double> GetDefaultYRange() const override { return m_defaultYRange; }
        bool SetDefaultYRange(const std::pair<double, double>& minmax) override
        {
            if (!(minmax.first < minmax.second))
            {
                return false;
            }
            m_defaultYRange = minmax;
            return true;
        }
        void ResetDefaultYRange() override { m_defaultYRange = { -10.0, 10.0 }; }

    private:
        static constexpr unsigned long long kDefaultMaxExecutionTime = 2000;  // ms，对齐原版
        // 14 色色板（与 spec/graph-colors.json 的 light 套一致，RRGGBB）。
        static const std::vector<Graphing::Color> kDefaultColors;
        static constexpr Graphing::Color kDefaultBackColor{ 0xFF, 0xFF, 0xFF };
        static constexpr Graphing::Color kDefaultZerosColor{ 0x00, 0x00, 0x00 };
        static constexpr Graphing::Color kDefaultExtremaColor{ 0x00, 0x00, 0x00 };
        static constexpr Graphing::Color kDefaultInflectionColor{ 0x00, 0x00, 0x00 };
        static constexpr Graphing::Color kDefaultAsymptotesColor{ 0x00, 0x00, 0x00 };
        static constexpr Graphing::Color kDefaultAxisColor{ 0x80, 0x80, 0x80 };
        static constexpr Graphing::Color kDefaultBoxColor{ 0x80, 0x80, 0x80 };
        static constexpr Graphing::Color kDefaultGridColor{ 0xD0, 0xD0, 0xD0 };
        static constexpr Graphing::Color kDefaultFontColor{ 0x00, 0x00, 0x00 };

        bool m_markZeros = false;
        bool m_markYIntercept = false;
        bool m_markMinima = false;
        bool m_markMaxima = false;
        bool m_markInflectionPoints = false;
        bool m_markVerticalAsymptotes = false;
        bool m_markHorizontalAsymptotes = false;
        bool m_markObliqueAsymptotes = false;
        unsigned long long m_maxExecutionTime = kDefaultMaxExecutionTime;
        std::vector<Graphing::Color> m_graphColors = kDefaultColors;
        Graphing::Color m_backColor = kDefaultBackColor;
        bool m_allowKgf = false;
        Graphing::Color m_zerosColor = kDefaultZerosColor;
        Graphing::Color m_extremaColor = kDefaultExtremaColor;
        Graphing::Color m_inflectionColor = kDefaultInflectionColor;
        Graphing::Color m_asymptotesColor = kDefaultAsymptotesColor;
        Graphing::Color m_axisColor = kDefaultAxisColor;
        Graphing::Color m_boxColor = kDefaultBoxColor;
        Graphing::Color m_gridColor = kDefaultGridColor;
        Graphing::Color m_fontColor = kDefaultFontColor;
        bool m_showAxis = true;
        bool m_showGrid = true;
        bool m_showBox = true;
        bool m_forceProportional = false;
        std::wstring m_aliasX = L"x";
        std::wstring m_aliasY = L"y";
        Graphing::Renderer::LineStyle m_lineStyle = Graphing::Renderer::LineStyle::Solid;
        std::pair<double, double> m_defaultXRange{ -10.0, 10.0 };
        std::pair<double, double> m_defaultYRange{ -10.0, 10.0 };
    };
}
