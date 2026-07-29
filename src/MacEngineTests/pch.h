// Portable replacement for CalculatorUnitTests/pch.h so the upstream
// engine test sources compile unmodified on macOS. Copied test sources
// in this directory resolve #include "pch.h" here.

#pragma once

#define UNIT_TESTS

#include <cassert>
#include <string>
#include <bitset>
#include <memory>
#include <vector>
#include <map>
#include <list>
#include <stack>
#include <deque>
#include <regex>
#include <unordered_map>
#include <mutex>
#include <locale>
#include <sstream>

#include "sal_cross_platform.h"

// CalcManager Headers
#include "CalcManager/ExpressionCommand.h"
#include "CalcManager/CalculatorResource.h"
#include "CalcManager/CalculatorManager.h"
#include "CalcManager/UnitConverter.h"

// Empty namespace so upstream "using namespace Platform;" (C++/CX) compiles.
namespace Platform
{
}

// Portable subset of CalculatorUnitTests/Helpers.h (the original pulls in
// CalcViewModel/WinRT types that the engine tests do not need).
namespace CalculatorUnitTests
{
#define StandardModePrecision 16
#define ScientificModePrecision 32
#define ProgrammerModePrecision 64

    namespace UtfUtils
    {
        constexpr wchar_t MUL = 0x00d7; // Multiplication Symbol
        constexpr wchar_t LRE = 0x202a; // Left-to-Right Embedding
        constexpr wchar_t PDF = 0x202c; // Pop Directional Formatting
        constexpr wchar_t LRO = 0x202d; // Left-to-Right Override
    }
}

#include <CppUnitTest.h>

#define VERIFY_ARE_EQUAL(__f1, __f2, ...)                                                                                                                      \
    {                                                                                                                                                          \
        Microsoft::VisualStudio::CppUnitTestFramework::Assert::IsTrue((__f1) == (__f2), ##__VA_ARGS__);                                                        \
    }

#define VERIFY_ARE_NOT_EQUAL(__f1, __f2, ...)                                                                                                                  \
    {                                                                                                                                                          \
        Microsoft::VisualStudio::CppUnitTestFramework::Assert::IsTrue((__f1) != (__f2), ##__VA_ARGS__);                                                        \
    }

#define VERIFY_IS_TRUE(__operation, ...)                                                                                                                       \
    {                                                                                                                                                          \
        Microsoft::VisualStudio::CppUnitTestFramework::Assert::IsTrue((__operation), ##__VA_ARGS__);                                                           \
    }

#define VERIFY_IS_FALSE(__operation, ...)                                                                                                                      \
    {                                                                                                                                                          \
        Microsoft::VisualStudio::CppUnitTestFramework::Assert::IsFalse((__operation), ##__VA_ARGS__);                                                          \
    }

#define VERIFY_IS_LESS_THAN(__expectedLess, __expectedGreater, ...)                                                                                            \
    {                                                                                                                                                          \
        Microsoft::VisualStudio::CppUnitTestFramework::Assert::IsTrue((__expectedLess) < (__expectedGreater), ##__VA_ARGS__);                                  \
    }

#define VERIFY_IS_GREATER_THAN(__expectedGreater, __expectedLess, ...)                                                                                         \
    {                                                                                                                                                          \
        Microsoft::VisualStudio::CppUnitTestFramework::Assert::IsTrue((__expectedGreater) > (__expectedLess), ##__VA_ARGS__);                                  \
    }
