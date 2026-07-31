// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "pch.h"
#include "NativeGraphingOptions.h"

namespace NativeGraphingImpl
{
    // 14 色方程色板（与 spec/graph-colors.json light 套一致）。
    // 值来自原版 GraphingSettings 的默认颜色序列（RRGGBB）。
    const std::vector<Graphing::Color> GraphingOptions::kDefaultColors = {
        Graphing::Color{ 0xFF, 0x4B, 0x00 },  // orange
        Graphing::Color{ 0x00, 0x7A, 0xC1 },  // blue
        Graphing::Color{ 0x00, 0x85, 0x4A },  // green
        Graphing::Color{ 0xC1, 0x4A, 0xBC },  // purple
        Graphing::Color{ 0xEA, 0x00, 0x2E },  // red
        Graphing::Color{ 0x46, 0x72, 0x0A },  // dark green
        Graphing::Color{ 0x00, 0x83, 0xC8 },  // light blue
        Graphing::Color{ 0x99, 0x50, 0x00 },  // dark orange
        Graphing::Color{ 0x00, 0x00, 0x9A },  // dark blue
        Graphing::Color{ 0x00, 0xB4, 0x8A },  // teal
        Graphing::Color{ 0x60, 0x00, 0x00 },  // dark red
        Graphing::Color{ 0x8E, 0x8E, 0x00 },  // olive
        Graphing::Color{ 0x1C, 0x00, 0x8D },  // indigo
        Graphing::Color{ 0x00, 0x51, 0x87 },  // steel blue
    };

    GraphingOptions::GraphingOptions()
    {
        ResetMarkKeyGraphFeaturesData();
    }

    void GraphingOptions::ResetMarkKeyGraphFeaturesData()
    {
        m_markZeros = false;
        m_markYIntercept = false;
        m_markMinima = false;
        m_markMaxima = false;
        m_markInflectionPoints = false;
        m_markVerticalAsymptotes = false;
        m_markHorizontalAsymptotes = false;
        m_markObliqueAsymptotes = false;
    }
}
