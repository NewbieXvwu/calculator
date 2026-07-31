// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include <memory>
#include <vector>

#include "GraphingInterfaces/GraphingEnums.h"  // ChangeRangeAction 等（IGraphRenderer.h 依赖先见）
#include "GraphingInterfaces/IGraphRenderer.h"
#include "NativeExpression.h"

// 共享层图形几何（S7，graph_geometry.h 的 C ABI）——本渲染器的几何数学来源。
#include "MacBridge/include/graph_geometry.h"

namespace NativeGraphingImpl
{
    // IGraphRenderer 的 Direct2D 实现（P-Windows-1/2 渲染后端）。
    // 几何（坐标变换/刻度/采样/marching squares/区间/吸附）全部复用共享层
    // graph_geometry C ABI（与 macOS 生产路径同源）；本文件只做 D2D 图元
    // 组装与视窗状态持有。
    //
    // 诚实记录（P-Windows 阶段性范围）：
    //   1. 不等式区域：用 graph_inequality_runs（中心点采样），细带/振荡区会丢
    //      （macOS S4 已用 Tupper 三值修复）。Windows 侧 Tupper 版（需 giac
    //      interval 三值回调）列为 P-Windows-2 优先项——在升级前，区域着色
    //      与 macOS 修复前同级的旧行为，且 F=0 边界线始终用 marching squares
    //      补画（细带不会完全不可见）。
    //   2. 显式曲线仍为逐列采样（graph_sample_curve），列区间升级同 macOS N1
    //      决策的第二阶段。
    class GraphRenderer : public Graphing::Renderer::IGraphRenderer
    {
    public:
        explicit GraphRenderer(std::vector<std::shared_ptr<NativeExpression>>* equations);

        HRESULT SetGraphSize(unsigned int width, unsigned int height) override;
        HRESULT SetDpi(float dpiX, float dpiY) override;

        HRESULT DrawD2D1(ID2D1Factory* pDirect2dFactory, ID2D1RenderTarget* pRenderTarget, bool& hasSomeMissingDataOut) override;
        HRESULT GetClosePointData(
            double inScreenPointX,
            double inScreenPointY,
            double precision,
            int& formulaIdOut,
            float& xScreenPointOut,
            float& yScreenPointOut,
            double& xValueOut,
            double& yValueOut,
            double& rhoValueOut,
            double& thetaValueOut,
            double& tValueOut) override;

        HRESULT ScaleRange(double centerX, double centerY, double scale) override;
        HRESULT ChangeRange(Graphing::Renderer::ChangeRangeAction action) override;
        HRESULT MoveRangeByRatio(double ratioX, double ratioY) override;
        HRESULT ResetRange() override;
        HRESULT GetDisplayRanges(double& xMin, double& xMax, double& yMin, double& yMax) override;
        HRESULT SetDisplayRanges(double xMin, double xMax, double yMin, double yMax) override;
        HRESULT PrepareGraph() override;

        HRESULT GetBitmap(std::shared_ptr<Graphing::IBitmap>& bitmapOut, bool& hasSomeMissingDataOut) override;

        // 视窗结构（渲染与命中共用）。
        graph_viewport_t Viewport() const { return m_viewport; }

    private:
        // C 回调：显式/隐式求值（graph_eval_fn / graph_eval2_fn）。
        static bool EvalExplicit(void* ctx, double x, double* outY);
        static bool EvalImplicit(void* ctx, double x, double y, double* outF);
        // C 回调：命中测试候选 y 收集（在 GetClosePointData 内联实现）。

        // 画一条显式曲线（逐列采样）。
        void DrawExplicitCurve(ID2D1RenderTarget* rt, const NativeExpression& expr, ID2D1Factory* factory, const Graphing::Color& color, float lineWidth);
        // 画一条隐式曲线（marching squares）。
        void DrawImplicitCurve(ID2D1RenderTarget* rt, const NativeExpression& expr, ID2D1Factory* factory, const Graphing::Color& color, float lineWidth);
        // 画不等式区域（中心采样）+ 边界线。
        void DrawInequality(ID2D1RenderTarget* rt, const NativeExpression& expr, ID2D1Factory* factory, const Graphing::Color& color, float lineWidth);

        std::vector<std::shared_ptr<NativeExpression>>* m_equations;  // 非拥有（Graph 持有）
        graph_viewport_t m_viewport{ -10.0, 10.0, -10.0, 10.0, 1.0, 1.0 };
        bool m_hasSize = false;
    };
}
