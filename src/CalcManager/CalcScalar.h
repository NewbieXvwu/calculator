// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// D9 · 标量类型逃生通道：默认全平台统一 IEEE754 binary64。
// 真正保证跨平台一致性的是黄金测试（tests/golden，S10），typedef 只让切换便宜。
// CI 检查：`grep -rn "long double" src/ | grep -v CalcScalar.h` 必须为空。

#pragma once

#if defined(CALC_USE_EXTENDED_FLOAT)
#include <boost/multiprecision/cpp_bin_float.hpp>
using calc_float = boost::multiprecision::cpp_bin_float_double_extended;
#define CALC_FLOAT_NAME "double-double"
#else
using calc_float = double; // 默认：全平台一致
#define CALC_FLOAT_NAME "double"
#endif

static_assert(sizeof(double) == 8, "IEEE754 binary64 required");
