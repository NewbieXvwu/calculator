// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "pch.h"
#include "NativeGraphRenderer.h"

#include <d2d1.h>
#include <d2d1helper.h>
#include <d2d1_1.h>
#include <wrl/client.h>

#include <algorithm>
#include <cstring>

namespace NativeGraphingImpl
{
    namespace
    {
        struct ColorF
        {
            float r, g, b, a;
            explicit ColorF(Graphing::Color c, float alpha = 1.0f)
                : r(static_cast<float>(c.R) / 255.0f)
                , g(static_cast<float>(c.G) / 255.0f)
                , b(static_cast<float>(c.B) / 255.0f)
                , a(alpha)
            {
            }
            operator D2D1_COLOR_F() const { return D2D1::ColorF(r, g, b, a); }
        };

        // 网格样式常量（对齐原版 GraphControl 默认：主格 0xD0D0D0、轴 0x808080）。
        constexpr float kGridAlpha = 1.0f;
        constexpr float kAxisWidth = 1.0f;
        constexpr float kCurveWidth = 2.0f;
        constexpr float kInequalityAlpha = 0.2f;  // 原版口径
    }

    GraphRenderer::GraphRenderer(std::vector<std::shared_ptr<NativeExpression>>* equations)
        : m_equations(equations)
    {
    }

    HRESULT GraphRenderer::SetGraphSize(unsigned int width, unsigned int height)
    {
        if (width == 0 || height == 0)
        {
            return E_INVALIDARG;
        }
        m_viewport.width = static_cast<double>(width);
        m_viewport.height = static_cast<double>(height);
        m_hasSize = true;
        return S_OK;
    }

    HRESULT GraphRenderer::SetDpi(float /*dpiX*/, float /*dpiY*/)
    {
        // D2D 渲染目标自管 DPI 缩放，几何在像素空间；本实现不依赖 DPI 值。
        return S_OK;
    }

    // MARK: - 求值回调（C ABI 桥，ctx = const NativeExpression*）

    bool GraphRenderer::EvalExplicit(void* ctx, double x, double* outY)
    {
        const auto* expr = static_cast<const NativeExpression*>(ctx);
        const auto v = expr->EvaluateAt(x);
        if (!v.has_value())
        {
            return false;
        }
        *outY = *v;
        return true;
    }

    bool GraphRenderer::EvalImplicit(void* ctx, double x, double y, double* outF)
    {
        const auto* expr = static_cast<const NativeExpression*>(ctx);
        const auto v = expr->EvaluateAt(x, y);
        if (!v.has_value())
        {
            return false;
        }
        *outF = *v;
        return true;
    }

    // MARK: - 绘制

    void GraphRenderer::DrawExplicitCurve(ID2D1RenderTarget* rt, const NativeExpression& expr, ID2D1Factory* factory, const Graphing::Color& color, float lineWidth)
    {
        if (!m_hasSize)
        {
            return;
        }
        auto vp = m_viewport;
        const int columns = static_cast<int>(vp.width);
        const size_t cap = static_cast<size_t>(columns) + 1;
        std::vector<graph_sample_t> samples(cap);
        size_t count = 0;
        const auto* exprPtr = &expr;
        count = graph_sample_curve(&vp, EvalExplicit, const_cast<NativeExpression*>(exprPtr), samples.data(), cap);
        if (count == 0)
        {
            return;
        }

        Microsoft::WRL::ComPtr<ID2D1PathGeometry> geometry;
        if (FAILED(factory->CreatePathGeometry(&geometry)))
        {
            return;
        }
        Microsoft::WRL::ComPtr<ID2D1GeometrySink> sink;
        if (FAILED(geometry->Open(&sink)))
        {
            return;
        }
        sink->SetFillMode(D2D1_FILL_MODE_ALTERNATE);
        sink->BeginFigure(D2D1::Point2F(static_cast<float>(samples[0].sx), static_cast<float>(samples[0].sy)), D2D1_FIGURE_BEGIN_FILLED);
        for (size_t i = 1; i < count; ++i)
        {
            if (samples[i].move)
            {
                sink->EndFigure(D2D1_FIGURE_END_OPEN);
                sink->BeginFigure(D2D1::Point2F(static_cast<float>(samples[i].sx), static_cast<float>(samples[i].sy)), D2D1_FIGURE_BEGIN_FILLED);
            }
            else
            {
                sink->AddLine(D2D1::Point2F(static_cast<float>(samples[i].sx), static_cast<float>(samples[i].sy)));
            }
        }
        sink->EndFigure(D2D1_FIGURE_END_OPEN);
        sink->Close();

        Microsoft::WRL::ComPtr<ID2D1SolidColorBrush> brush;
        if (SUCCEEDED(rt->CreateSolidColorBrush(ColorF(color), &brush)))
        {
            rt->DrawGeometry(geometry.Get(), brush.Get(), lineWidth);
        }
    }

    void GraphRenderer::DrawImplicitCurve(ID2D1RenderTarget* rt, const NativeExpression& expr, ID2D1Factory* factory, const Graphing::Color& color, float lineWidth)
    {
        if (!m_hasSize)
        {
            return;
        }
        // 网格数：与画布像素比 4px/格（对齐 macOS drawImplicit 的初始 pixelPx）。
        const int cols = graph_pow2_cell_count(m_viewport.width, 4.0);
        const int rows = graph_pow2_cell_count(m_viewport.height, 4.0);
        const size_t cap = 2u * static_cast<size_t>(cols) * static_cast<size_t>(rows) + 16;
        std::vector<graph_segment_t> segs(cap);
        const auto* exprPtr = &expr;
        const size_t count = graph_marching_squares(
            m_viewport.x_min, m_viewport.x_max, m_viewport.y_min, m_viewport.y_max,
            cols, rows, EvalImplicit, const_cast<NativeExpression*>(exprPtr), segs.data(), cap);
        if (count == 0)
        {
            return;
        }

        Microsoft::WRL::ComPtr<ID2D1PathGeometry> geometry;
        if (FAILED(factory->CreatePathGeometry(&geometry)))
        {
            return;
        }
        Microsoft::WRL::ComPtr<ID2D1GeometrySink> sink;
        if (FAILED(geometry->Open(&sink)))
        {
            return;
        }
        sink->SetFillMode(D2D1_FILL_MODE_ALTERNATE);
        for (size_t i = 0; i < count; ++i)
        {
            // 数学坐标 → 屏幕坐标。
            const double sx1 = graph_to_screen_x(&m_viewport, segs[i].x1);
            const double sy1 = graph_to_screen_y(&m_viewport, segs[i].y1);
            const double sx2 = graph_to_screen_x(&m_viewport, segs[i].x2);
            const double sy2 = graph_to_screen_y(&m_viewport, segs[i].y2);
            sink->BeginFigure(D2D1::Point2F(static_cast<float>(sx1), static_cast<float>(sy1)), D2D1_FIGURE_BEGIN_FILLED);
            sink->AddLine(D2D1::Point2F(static_cast<float>(sx2), static_cast<float>(sy2)));
            sink->EndFigure(D2D1_FIGURE_END_OPEN);
        }
        sink->Close();

        Microsoft::WRL::ComPtr<ID2D1SolidColorBrush> brush;
        if (SUCCEEDED(rt->CreateSolidColorBrush(ColorF(color), &brush)))
        {
            rt->DrawGeometry(geometry.Get(), brush.Get(), lineWidth);
        }
    }

    void GraphRenderer::DrawInequality(ID2D1RenderTarget* rt, const NativeExpression& expr, ID2D1Factory* factory, const Graphing::Color& color, float lineWidth)
    {
        if (!m_hasSize)
        {
            return;
        }
        // 区域（中心采样；细带/振荡区限制见头文件诚实记录）。
        auto vp = m_viewport;
        graph_relation_t rel = GRAPH_REL_LESS;
        if (expr.GetInequalityRelation() == "lessEq")
        {
            rel = GRAPH_REL_LESS_EQUAL;
        }
        else if (expr.GetInequalityRelation() == "greater")
        {
            rel = GRAPH_REL_GREATER;
        }
        else if (expr.GetInequalityRelation() == "greaterEq")
        {
            rel = GRAPH_REL_GREATER_EQUAL;
        }

        // (std::max) 括号防 windows.h 的 max 宏展开（pch.h 含 <windows.h>）。
        const int cols = (std::max)(8, static_cast<int>(vp.width / 4.0));
        const int rows = (std::max)(8, static_cast<int>(vp.height / 4.0));
        std::vector<graph_rect_t> rects(static_cast<size_t>(cols) * (static_cast<size_t>(rows) + 1));
        const auto* exprPtr = &expr;
        const size_t count = graph_inequality_runs(&vp, 4.0, rel, EvalImplicit, const_cast<NativeExpression*>(exprPtr), rects.data(), rects.size());
        if (count > 0)
        {
            Microsoft::WRL::ComPtr<ID2D1PathGeometry> geometry;
            if (SUCCEEDED(factory->CreatePathGeometry(&geometry)))
            {
                Microsoft::WRL::ComPtr<ID2D1GeometrySink> sink;
                if (SUCCEEDED(geometry->Open(&sink)))
                {
                    sink->SetFillMode(D2D1_FILL_MODE_ALTERNATE);
                    for (size_t i = 0; i < count; ++i)
                    {
                        const auto& r = rects[i];
                        sink->BeginFigure(D2D1::Point2F(static_cast<float>(r.x), static_cast<float>(r.y)), D2D1_FIGURE_BEGIN_FILLED);
                        sink->AddLine(D2D1::Point2F(static_cast<float>(r.x + r.w), static_cast<float>(r.y)));
                        sink->AddLine(D2D1::Point2F(static_cast<float>(r.x + r.w), static_cast<float>(r.y + r.h)));
                        sink->AddLine(D2D1::Point2F(static_cast<float>(r.x), static_cast<float>(r.y + r.h)));
                        sink->EndFigure(D2D1_FIGURE_END_CLOSED);
                    }
                    sink->Close();
                }
            }
            Microsoft::WRL::ComPtr<ID2D1SolidColorBrush> brush;
            if (geometry && SUCCEEDED(rt->CreateSolidColorBrush(ColorF(color, kInequalityAlpha), &brush)))
            {
                rt->FillGeometry(geometry.Get(), brush.Get());
            }
        }
        // 边界线 F=0（严格不等式虚线、非严格实线——原版行为）。
        DrawImplicitCurve(rt, expr, factory, color, lineWidth);
    }

    HRESULT GraphRenderer::DrawD2D1(ID2D1Factory* pDirect2dFactory, ID2D1RenderTarget* pRenderTarget, bool& hasSomeMissingDataOut)
    {
        if (!pDirect2dFactory || !pRenderTarget || !m_hasSize)
        {
            return E_INVALIDARG;
        }
        hasSomeMissingDataOut = false;

        // 背景。
        Microsoft::WRL::ComPtr<ID2D1SolidColorBrush> backBrush;
        pRenderTarget->CreateSolidColorBrush(ColorF(Graphing::Color(0xFF, 0xFF, 0xFF)), &backBrush);
        if (backBrush)
        {
            pRenderTarget->FillRectangle(D2D1::RectF(0, 0, static_cast<float>(m_viewport.width), static_cast<float>(m_viewport.height)), backBrush.Get());
        }

        // 网格（1-2-5 刻度）。
        const double stepX = graph_nice_step(m_viewport.x_max - m_viewport.x_min, 10);
        const double stepY = graph_nice_step(m_viewport.y_max - m_viewport.y_min, 10);
        Microsoft::WRL::ComPtr<ID2D1SolidColorBrush> gridBrush;
        if (SUCCEEDED(pRenderTarget->CreateSolidColorBrush(ColorF(Graphing::Color(0xD0, 0xD0, 0xD0)), &gridBrush)))
        {
            std::vector<double> ticks(256);
            const size_t nx = graph_ticks(m_viewport.x_min, m_viewport.x_max, stepX, ticks.data(), ticks.size());
            for (size_t i = 0; i < nx; ++i)
            {
                const double sx = graph_to_screen_x(&m_viewport, ticks[i]);
                pRenderTarget->DrawLine(
                    D2D1::Point2F(static_cast<float>(sx), 0.0f),
                    D2D1::Point2F(static_cast<float>(sx), static_cast<float>(m_viewport.height)),
                    gridBrush.Get(), 0.5f);
            }
            const size_t ny = graph_ticks(m_viewport.y_min, m_viewport.y_max, stepY, ticks.data(), ticks.size());
            for (size_t i = 0; i < ny; ++i)
            {
                const double sy = graph_to_screen_y(&m_viewport, ticks[i]);
                pRenderTarget->DrawLine(
                    D2D1::Point2F(0.0f, static_cast<float>(sy)),
                    D2D1::Point2F(static_cast<float>(m_viewport.width), static_cast<float>(sy)),
                    gridBrush.Get(), 0.5f);
            }
        }

        // 坐标轴。
        Microsoft::WRL::ComPtr<ID2D1SolidColorBrush> axisBrush;
        if (SUCCEEDED(pRenderTarget->CreateSolidColorBrush(ColorF(Graphing::Color(0x80, 0x80, 0x80)), &axisBrush)))
        {
            const double x0 = graph_to_screen_x(&m_viewport, 0.0);
            if (x0 >= 0 && x0 <= m_viewport.width)
            {
                pRenderTarget->DrawLine(
                    D2D1::Point2F(static_cast<float>(x0), 0.0f),
                    D2D1::Point2F(static_cast<float>(x0), static_cast<float>(m_viewport.height)),
                    axisBrush.Get(), kAxisWidth);
            }
            const double y0 = graph_to_screen_y(&m_viewport, 0.0);
            if (y0 >= 0 && y0 <= m_viewport.height)
            {
                pRenderTarget->DrawLine(
                    D2D1::Point2F(0.0f, static_cast<float>(y0)),
                    D2D1::Point2F(static_cast<float>(m_viewport.width), static_cast<float>(y0)),
                    axisBrush.Get(), kAxisWidth);
            }
        }

        // 曲线（按方程顺序，色板循环）。
        const auto& colors = std::vector<Graphing::Color>{
            Graphing::Color(0xFF, 0x4B, 0x00), Graphing::Color(0x00, 0x7A, 0xC1),
            Graphing::Color(0x00, 0x85, 0x4A), Graphing::Color(0xC1, 0x4A, 0xBC),
            Graphing::Color(0xEA, 0x00, 0x2E), Graphing::Color(0x46, 0x72, 0x0A),
        };
        size_t eqIndex = 0;
        for (const auto& eq : *m_equations)
        {
            const auto& color = colors[eqIndex % colors.size()];
            switch (eq->GetKind())
            {
            case NativeEquationKind::ExplicitFunction:
                DrawExplicitCurve(pRenderTarget, *eq, pDirect2dFactory, color, kCurveWidth);
                break;
            case NativeEquationKind::ImplicitEquation:
                DrawImplicitCurve(pRenderTarget, *eq, pDirect2dFactory, color, kCurveWidth);
                break;
            case NativeEquationKind::Inequality:
                DrawInequality(pRenderTarget, *eq, pDirect2dFactory, color, kCurveWidth);
                break;
            default:
                break;
            }
            ++eqIndex;
        }
        return S_OK;
    }

    HRESULT GraphRenderer::GetClosePointData(
        double inScreenPointX,
        double inScreenPointY,
        double /*precision*/,
        int& formulaIdOut,
        float& xScreenPointOut,
        float& yScreenPointOut,
        double& xValueOut,
        double& yValueOut,
        double& rhoValueOut,
        double& thetaValueOut,
        double& tValueOut)
    {
        // 命中测试：把屏幕点转回数学坐标，对每个可见显式方程收集候选 y，
        // 用 graph_trace_snap 就近吸附（共享层语义，与 macOS 一致）。
        const double mathX = graph_to_math_x(&m_viewport, inScreenPointX);
        const double mathY = graph_to_math_y(&m_viewport, inScreenPointY);

        std::vector<double> ys;
        std::vector<int> indexMap;
        for (size_t i = 0; i < m_equations->size(); ++i)
        {
            const auto& eq = (*m_equations)[i];
            if (eq->GetKind() != NativeEquationKind::ExplicitFunction)
            {
                continue;
            }
            const auto v = eq->EvaluateAt(mathX);
            if (v.has_value())
            {
                ys.push_back(*v);
                indexMap.push_back(static_cast<int>(i));
            }
        }
        if (ys.empty())
        {
            return S_FALSE;  // 无候选（调用方按未命中处理）
        }
        const int picked = static_cast<int>(graph_trace_snap(ys.data(), ys.size(), mathY, m_viewport.y_max - m_viewport.y_min));
        if (picked < 0)
        {
            return S_FALSE;
        }
        formulaIdOut = indexMap[static_cast<size_t>(picked)];
        xValueOut = mathX;
        yValueOut = ys[static_cast<size_t>(picked)];
        xScreenPointOut = static_cast<float>(inScreenPointX);
        yScreenPointOut = static_cast<float>(graph_to_screen_y(&m_viewport, yValueOut));
        rhoValueOut = 0.0;
        thetaValueOut = 0.0;
        tValueOut = 0.0;
        return S_OK;
    }

    // MARK: - 视窗操作（共享层 C ABI）

    HRESULT GraphRenderer::ScaleRange(double centerX, double centerY, double scale)
    {
        graph_zoom_at(&m_viewport, scale, centerX, centerY);
        return S_OK;
    }

    HRESULT GraphRenderer::ChangeRange(Graphing::Renderer::ChangeRangeAction action)
    {
        // 原版 ChangeRangeAction 的语义映射到共享层。二维绘图不消费 WidenZ。
        switch (action)
        {
        case Graphing::Renderer::ChangeRangeAction::ZoomIn:
            graph_zoom(&m_viewport, 0.8);
            break;
        case Graphing::Renderer::ChangeRangeAction::ZoomOut:
            graph_zoom(&m_viewport, 1.25);
            break;
        case Graphing::Renderer::ChangeRangeAction::WidenX:
        case Graphing::Renderer::ChangeRangeAction::WidenY:
            graph_zoom(&m_viewport, 1.25);
            break;
        case Graphing::Renderer::ChangeRangeAction::ShrinkX:
        case Graphing::Renderer::ChangeRangeAction::ShrinkY:
            graph_zoom(&m_viewport, 0.8);
            break;
        default:
            break;
        }
        return S_OK;
    }

    HRESULT GraphRenderer::MoveRangeByRatio(double ratioX, double ratioY)
    {
        const double spanX = m_viewport.x_max - m_viewport.x_min;
        const double spanY = m_viewport.y_max - m_viewport.y_min;
        graph_pan(&m_viewport, ratioX * spanX, -ratioY * spanY);
        return S_OK;
    }

    HRESULT GraphRenderer::ResetRange()
    {
        m_viewport.x_min = -10.0;
        m_viewport.x_max = 10.0;
        m_viewport.y_min = -10.0;
        m_viewport.y_max = 10.0;
        return S_OK;
    }

    HRESULT GraphRenderer::GetDisplayRanges(double& xMin, double& xMax, double& yMin, double& yMax)
    {
        xMin = m_viewport.x_min;
        xMax = m_viewport.x_max;
        yMin = m_viewport.y_min;
        yMax = m_viewport.y_max;
        return S_OK;
    }

    HRESULT GraphRenderer::SetDisplayRanges(double xMin, double xMax, double yMin, double yMax)
    {
        if (!(xMin < xMax) || !(yMin < yMax))
        {
            return E_INVALIDARG;
        }
        m_viewport.x_min = xMin;
        m_viewport.x_max = xMax;
        m_viewport.y_min = yMin;
        m_viewport.y_max = yMax;
        return S_OK;
    }

    HRESULT GraphRenderer::PrepareGraph()
    {
        // 无预计算缓存（绘制时按需采样，与 macOS 同模式）。
        return S_OK;
    }

    HRESULT GraphRenderer::GetBitmap(std::shared_ptr<Graphing::IBitmap>& /*bitmapOut*/, bool& /*hasSomeMissingDataOut*/)
    {
        // 位图导出：GraphControl 的 WIC 路径在 P-Windows-2 接（当前 UI 走
        // DrawD2D1 直接渲染，不消费 GetBitmap）。
        return E_NOTIMPL;
    }
}
