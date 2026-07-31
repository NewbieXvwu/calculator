// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "pch.h"
#include "MathSolver.h"
#include "Mocks/Graph.h"

#if defined(USE_NATIVE_GRAPHING_IMPL)
#include "Native/NativeMathSolver.h"
#endif

using namespace std;

namespace Graphing
{
    unique_ptr<IMathSolver> IMathSolver::CreateMathSolver()
    {
#if defined(USE_NATIVE_GRAPHING_IMPL)
        // P-Windows-1/2：真实 giac 后端（libgiac_bridge.dll）。
        return make_unique<NativeGraphingImpl::MathSolver>();
#else
        // 默认 mock（UseMockGraphingImpl=true 的既有行为，README 的开发者构建路径）。
        return make_unique<MockGraphingImpl::MathSolver>();
#endif
    }
}

// Mock 路径的 CreateGrapher 实现（IMathSolver 纯虚接口的 stub，原文件保留）。
shared_ptr<Graphing::IGraph> MockGraphingImpl::MathSolver::CreateGrapher()
{
    return make_shared<MockGraphingImpl::Graph>();
}

shared_ptr<Graphing::IGraph> MockGraphingImpl::MathSolver::CreateGrapher(const Graphing::IExpression* /*expression*/)
{
    return make_shared<MockGraphingImpl::Graph>();
}
