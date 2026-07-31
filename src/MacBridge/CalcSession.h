// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Pure C++ facade over CalculationManager::CalculatorManager.
// Deliberately includes no engine headers so that Objective-C++ consumers
// never mix engine globals (e.g. Ratpack's `pi`) with Apple SDK headers.

#pragma once

#include <functional>
#include <memory>
#include <string>
#include <utility>
#include <vector>

namespace MacCalc
{
    // 分组模式结构（S8）：存结构而非字符串，避免各平台手拼 "3;0" 漂移。
    // 印度拉克/克若尔制 = {3, 2, true}；西语 minimumGroupingDigits=2 之类
    // 引擎暂不消费（GroupDigits 无此概念），先如实承载，消费方迁移见 TODO S8。
    struct Grouping
    {
        int primary = 3;
        int secondary = 0;  // 0 = 与 primary 相同（无独立次级组）
        bool repeatSecondary = true;
        int minimumGroupingDigits = 1;

        // 引擎 sGrouping 字符串（CCalcEngine::DigitGroupingStringToGroupingVector
        // 的输入）：尾随 ";0" 表示末组无限重复。"3;0"、"3;2;0"、"3"、""（不分组）。
        std::wstring EngineString() const;
    };

    struct LocaleStrings
    {
        std::wstring decimalSeparator = L".";
        std::wstring thousandSeparator = L",";
        std::wstring grouping = L"3;0";
    };

    struct HistoryEntry
    {
        std::wstring expression;
        std::wstring result;
    };

    // Mirrors ICalcDisplay; every hook is optional.
    struct SessionCallbacks
    {
        std::function<void(const std::wstring& text, bool isError)> onPrimaryDisplay;
        std::function<void(bool isInError)> onIsInError;
        // Token pairs are (text, commandIndex); commandIndex < 0 means not editable.
        std::function<void(const std::vector<std::pair<std::wstring, int>>& tokens)> onExpressionTokens;
        std::function<void(unsigned int count)> onParenthesisCount;
        std::function<void()> onNoRightParenAdded;
        std::function<void()> onMaxDigitsReached;
        std::function<void()> onBinaryOperatorReceived;
        std::function<void(unsigned int index)> onHistoryItemAdded;
        std::function<void(const std::vector<std::wstring>& values)> onMemorizedNumbers;
        std::function<void(unsigned int index)> onMemoryItemChanged;
        std::function<void()> onInputChanged;
    };

    class CalcSession
    {
    public:
        explicit CalcSession(LocaleStrings locale);
        ~CalcSession();

        CalcSession(const CalcSession&) = delete;
        CalcSession& operator=(const CalcSession&) = delete;

        void SetCallbacks(SessionCallbacks callbacks);
        void SendCommand(int command);
        void DisplayPasteError();
        void Reset(bool clearMemory = true);
        void SetStandardMode();
        void SetScientificMode();
        void SetProgrammerMode();

        bool IsEngineRecording();
        bool IsInputEmpty();
        wchar_t DecimalSeparator();
        void SetPrecision(int precision);
        void UpdateMaxIntDigits();
        // radixType: 0=Hex 1=Decimal 2=Octal 3=Binary (RadixType.h)
        void SetRadix(int radixType);
        std::wstring GetResultForRadix(unsigned int radix, int precision, bool groupDigitsPerRadix);

        // Memory
        void MemorizeNumber();
        void MemorizedNumberLoad(unsigned int index);
        void MemorizedNumberAdd(unsigned int index);
        void MemorizedNumberSubtract(unsigned int index);
        void MemorizedNumberClear(unsigned int index);
        void MemorizedNumberClearAll();

        // History (current mode)
        std::vector<HistoryEntry> GetHistoryEntries() const;
        bool RemoveHistoryItem(unsigned int index);
        void ClearHistory();

        // Expression token editing (mirrors StandardCalculatorViewModel::UpdateOperand + Recalculate).
        bool IsTokenEditableOperand(unsigned int tokenPosition) const;
        bool UpdateOperandAtToken(unsigned int tokenPosition, const std::wstring& newText, bool scientificMode, bool fToEChecked);

    private:
        class Impl;
        std::unique_ptr<Impl> m_impl;
    };
}
