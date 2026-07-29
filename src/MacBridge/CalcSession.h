// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Pure C++ facade over CalculationManager::CalculatorManager.
// Deliberately includes no engine headers so that Objective-C++ consumers
// never mix engine globals (e.g. Ratpack's `pi`) with Apple SDK headers.

#pragma once

#include <functional>
#include <memory>
#include <string>

namespace MacCalc
{
    struct LocaleStrings
    {
        std::wstring decimalSeparator = L".";
        std::wstring thousandSeparator = L",";
        std::wstring grouping = L"3;0";
    };

    class CalcSession
    {
    public:
        using DisplayCallback = std::function<void(const std::wstring& text, bool isError)>;

        explicit CalcSession(LocaleStrings locale);
        ~CalcSession();

        CalcSession(const CalcSession&) = delete;
        CalcSession& operator=(const CalcSession&) = delete;

        void SetDisplayCallback(DisplayCallback callback);
        void SendCommand(int command);
        void Reset();
        void SetStandardMode();
        void SetScientificMode();

    private:
        class Impl;
        std::unique_ptr<Impl> m_impl;
    };
}
