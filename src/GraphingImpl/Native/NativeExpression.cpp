// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "pch.h"
#include "NativeExpression.h"
#include "GiacBridgeLoader.h"

#include <charconv>
#include <cstdlib>
#include <sstream>

namespace NativeGraphingImpl
{
    namespace
    {
        unsigned int g_nextExpressionId = 0;

        // UTF-8 ↔ UTF-16（Windows CRT，2/4 字节 wchar_t 均适用）。
        std::string ToUtf8(const std::wstring& w)
        {
            if (w.empty())
            {
                return {};
            }
            const int len = WideCharToMultiByte(CP_UTF8, 0, w.data(), static_cast<int>(w.size()), nullptr, 0, nullptr, nullptr);
            std::string out(static_cast<size_t>(len), '\0');
            WideCharToMultiByte(CP_UTF8, 0, w.data(), static_cast<int>(w.size()), out.data(), len, nullptr, nullptr);
            return out;
        }

        std::wstring FromUtf8(const std::string& s)
        {
            if (s.empty())
            {
                return {};
            }
            const int len = MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0);
            std::wstring out(static_cast<size_t>(len), L'\0');
            MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), len);
            return out;
        }

        // 解析 giac evalf 输出为 double。处理：
        //   "7.0" / "1.4142135623731" / "1.5e+12" / "-2.5e-3" 常规数值
        //   "inf"/"+infinity"/"-infinity"/"undef"/"NaN" 特殊记号 → nullopt
        std::optional<double> ParseNumeric(const std::string& s)
        {
            std::string t = s;
            // 去掉首尾空白
            size_t b = t.find_first_not_of(" \t\r\n");
            size_t e = t.find_last_not_of(" \t\r\n");
            if (b == std::string::npos)
            {
                return std::nullopt;
            }
            t = t.substr(b, e - b + 1);

            // 特殊记号黑名单（对齐 macOS GiacMathSolver 的记号黑名单，M4）。
            if (t == "inf" || t == "+inf" || t == "-inf" || t == "+infinity" || t == "-infinity" ||
                t == "undef" || t == "NaN" || t == "nan" || t.find("bounded_function") != std::string::npos)
            {
                return std::nullopt;
            }
            double v = 0;
            const auto [ptr, ec] = std::from_chars(t.data(), t.data() + t.size(), v);
            if (ec == std::errc() && ptr == t.data() + t.size())
            {
                return v;
            }
            // 兜底：strtod（处理 giac 可能输出的 C 风格形式）。
            char* end = nullptr;
            v = std::strtod(t.c_str(), &end);
            if (end == t.c_str() + t.size())
            {
                return v;
            }
            return std::nullopt;
        }
    }

    NativeExpression::NativeExpression(
        std::wstring raw,
        NativeEquationKind kind,
        std::string explicitRhs,
        std::string inequalityRelation,
        std::string variableNames,
        bool isEmptySet)
        : m_id(++g_nextExpressionId)
        , m_raw(std::move(raw))
        , m_rawUtf8(ToUtf8(m_raw))
        , m_kind(kind)
        , m_explicitRhs(std::move(explicitRhs))
        , m_inequalityRelation(std::move(inequalityRelation))
        , m_variableNames(std::move(variableNames))
        , m_isEmptySet(isEmptySet)
    {
        // giac 校验：对归一化后的主体做一次符号化简，任何 GIAC_ERROR 或
        // 空结果都视为解析失败。校验表达式不依赖具体变量值。
        const std::string check = "normal(" + m_explicitRhs + ")";
        std::string out;
        std::string warnings;
        if (GiacBridgeLoader::Instance().Evaluate(check.c_str(), out, &warnings))
        {
            m_valid = out.find("GIAC_ERROR") == std::string::npos && !out.empty();
            if (!m_valid)
            {
                m_validationError = out;
            }
        }
        else
        {
            m_validationError = out;
        }
        // giac 对不完整语法（尾随操作符，如 "2+"）惰性返回原样文本且不报错，
        // 语法层面直接拦截（不依赖 giac 行为）。
        if (m_valid && !m_explicitRhs.empty())
        {
            const char last = m_explicitRhs.back();
            if (last == '+' || last == '-' || last == '*' || last == '/' || last == '^' || last == '=')
            {
                m_valid = false;
                m_validationError = "trailing operator";
            }
        }
    }

    NativeExpression::NativeExpression(const NativeExpression& other)
        : m_id(++g_nextExpressionId)
        , m_raw(other.m_raw)
        , m_rawUtf8(other.m_rawUtf8)
        , m_kind(other.m_kind)
        , m_explicitRhs(other.m_explicitRhs)
        , m_inequalityRelation(other.m_inequalityRelation)
        , m_variableNames(other.m_variableNames)
        , m_isEmptySet(other.m_isEmptySet)
        , m_valid(other.m_valid)
        , m_validationError(other.m_validationError)
    {
        // 拷贝不重新触发 giac 校验（原对象已校验过，结果原样继承）。
    }

    std::optional<double> NativeExpression::EvaluateAt(double x, std::optional<double> y) const
    {
        if (!m_valid)
        {
            return std::nullopt;
        }
        // 构造 giac 数值求值表达式：evalf(subst(<body>,x=<x>[,y=<y>]))
        std::ostringstream oss;
        oss << "evalf(subst(" << m_explicitRhs << ",x=" << std::to_string(x);
        if (y.has_value())
        {
            oss << ",y=" << std::to_string(*y);
        }
        oss << "))";

        std::string out;
        std::string warnings;
        if (!GiacBridgeLoader::Instance().Evaluate(oss.str().c_str(), out, &warnings))
        {
            return std::nullopt;
        }
        return ParseNumeric(out);
    }
}
