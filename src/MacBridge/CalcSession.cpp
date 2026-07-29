// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "CalcSession.h"

#include <utility>
#include <vector>

#include "CalculatorManager.h"
#include "CalculatorResource.h"
#include "EngineStringsData.g.h"

namespace MacCalc
{
    namespace
    {
        class SessionResourceProvider final : public CalculationManager::IResourceProvider
        {
        public:
            explicit SessionResourceProvider(LocaleStrings locale)
                : m_locale(std::move(locale))
            {
            }

            std::wstring GetCEngineString(std::wstring_view id) override
            {
                if (id == L"sDecimal")
                {
                    return m_locale.decimalSeparator;
                }
                if (id == L"sThousand")
                {
                    return m_locale.thousandSeparator;
                }
                if (id == L"sGrouping")
                {
                    return m_locale.grouping;
                }
                const auto& table = EngineStringsEnUS();
                auto it = table.find(id);
                return it != table.end() ? std::wstring(it->second) : std::wstring{};
            }

        private:
            LocaleStrings m_locale;
        };

        class SessionDisplay final : public ICalcDisplay
        {
        public:
            SessionCallbacks callbacks;

            void SetPrimaryDisplay(const std::wstring& text, bool isError) override
            {
                if (callbacks.onPrimaryDisplay)
                {
                    callbacks.onPrimaryDisplay(text, isError);
                }
            }
            void SetIsInError(bool isInError) override
            {
                if (callbacks.onIsInError)
                {
                    callbacks.onIsInError(isInError);
                }
            }
            void SetExpressionDisplay(
                std::shared_ptr<std::vector<std::pair<std::wstring, int>>> const& tokens,
                std::shared_ptr<std::vector<std::shared_ptr<IExpressionCommand>>> const&) override
            {
                if (callbacks.onExpressionTokens && tokens)
                {
                    callbacks.onExpressionTokens(*tokens);
                }
            }
            void SetParenthesisNumber(unsigned int count) override
            {
                if (callbacks.onParenthesisCount)
                {
                    callbacks.onParenthesisCount(count);
                }
            }
            void OnNoRightParenAdded() override
            {
                if (callbacks.onNoRightParenAdded)
                {
                    callbacks.onNoRightParenAdded();
                }
            }
            void MaxDigitsReached() override
            {
                if (callbacks.onMaxDigitsReached)
                {
                    callbacks.onMaxDigitsReached();
                }
            }
            void BinaryOperatorReceived() override
            {
                if (callbacks.onBinaryOperatorReceived)
                {
                    callbacks.onBinaryOperatorReceived();
                }
            }
            void OnHistoryItemAdded(unsigned int index) override
            {
                if (callbacks.onHistoryItemAdded)
                {
                    callbacks.onHistoryItemAdded(index);
                }
            }
            void SetMemorizedNumbers(const std::vector<std::wstring>& values) override
            {
                if (callbacks.onMemorizedNumbers)
                {
                    callbacks.onMemorizedNumbers(values);
                }
            }
            void MemoryItemChanged(unsigned int index) override
            {
                if (callbacks.onMemoryItemChanged)
                {
                    callbacks.onMemoryItemChanged(index);
                }
            }
            void InputChanged() override
            {
                if (callbacks.onInputChanged)
                {
                    callbacks.onInputChanged();
                }
            }
        };
    }

    class CalcSession::Impl
    {
    public:
        explicit Impl(LocaleStrings locale)
            : m_resourceProvider(std::move(locale))
            , m_manager(&m_display, &m_resourceProvider)
        {
            m_manager.SetStandardMode();
        }

        SessionDisplay m_display;
        SessionResourceProvider m_resourceProvider;
        CalculationManager::CalculatorManager m_manager;
    };

    CalcSession::CalcSession(LocaleStrings locale)
        : m_impl(std::make_unique<Impl>(std::move(locale)))
    {
    }

    CalcSession::~CalcSession() = default;

    void CalcSession::SetCallbacks(SessionCallbacks callbacks)
    {
        m_impl->m_display.callbacks = std::move(callbacks);
    }

    void CalcSession::SendCommand(int command)
    {
        m_impl->m_manager.SendCommand(static_cast<CalculationManager::Command>(command));
    }

    void CalcSession::DisplayPasteError()
    {
        m_impl->m_manager.DisplayPasteError();
    }

    void CalcSession::Reset(bool clearMemory)
    {
        m_impl->m_manager.Reset(clearMemory);
    }

    void CalcSession::SetStandardMode()
    {
        m_impl->m_manager.SetStandardMode();
    }

    void CalcSession::SetScientificMode()
    {
        m_impl->m_manager.SetScientificMode();
    }

    void CalcSession::SetProgrammerMode()
    {
        m_impl->m_manager.SetProgrammerMode();
    }

    bool CalcSession::IsEngineRecording()
    {
        return m_impl->m_manager.IsEngineRecording();
    }

    bool CalcSession::IsInputEmpty()
    {
        return m_impl->m_manager.IsInputEmpty();
    }

    wchar_t CalcSession::DecimalSeparator()
    {
        return m_impl->m_manager.DecimalSeparator();
    }

    void CalcSession::SetPrecision(int precision)
    {
        m_impl->m_manager.SetPrecision(precision);
    }

    void CalcSession::UpdateMaxIntDigits()
    {
        m_impl->m_manager.UpdateMaxIntDigits();
    }

    void CalcSession::SetRadix(int radixType)
    {
        m_impl->m_manager.SetRadix(static_cast<RadixType>(radixType));
    }

    std::wstring CalcSession::GetResultForRadix(unsigned int radix, int precision, bool groupDigitsPerRadix)
    {
        return m_impl->m_manager.GetResultForRadix(radix, precision, groupDigitsPerRadix);
    }

    void CalcSession::MemorizeNumber()
    {
        m_impl->m_manager.MemorizeNumber();
    }

    void CalcSession::MemorizedNumberLoad(unsigned int index)
    {
        m_impl->m_manager.MemorizedNumberLoad(index);
    }

    void CalcSession::MemorizedNumberAdd(unsigned int index)
    {
        m_impl->m_manager.MemorizedNumberAdd(index);
    }

    void CalcSession::MemorizedNumberSubtract(unsigned int index)
    {
        m_impl->m_manager.MemorizedNumberSubtract(index);
    }

    void CalcSession::MemorizedNumberClear(unsigned int index)
    {
        m_impl->m_manager.MemorizedNumberClear(index);
    }

    void CalcSession::MemorizedNumberClearAll()
    {
        m_impl->m_manager.MemorizedNumberClearAll();
    }

    std::vector<HistoryEntry> CalcSession::GetHistoryEntries() const
    {
        std::vector<HistoryEntry> entries;
        for (const auto& item : m_impl->m_manager.GetHistoryItems())
        {
            entries.push_back({ item->historyItemVector.expression, item->historyItemVector.result });
        }
        return entries;
    }

    bool CalcSession::RemoveHistoryItem(unsigned int index)
    {
        return m_impl->m_manager.RemoveHistoryItem(index);
    }

    void CalcSession::ClearHistory()
    {
        m_impl->m_manager.ClearHistory();
    }
}
