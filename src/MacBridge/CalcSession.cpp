// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "CalcSession.h"

#include <utility>
#include <vector>

#include "CalculatorManager.h"
#include "CalculatorResource.h"

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
                return {};
            }

        private:
            LocaleStrings m_locale;
        };

        class SessionDisplay final : public ICalcDisplay
        {
        public:
            CalcSession::DisplayCallback callback;

            void SetPrimaryDisplay(const std::wstring& text, bool isError) override
            {
                if (callback)
                {
                    callback(text, isError);
                }
            }
            void SetIsInError(bool) override
            {
            }
            void SetExpressionDisplay(
                std::shared_ptr<std::vector<std::pair<std::wstring, int>>> const&,
                std::shared_ptr<std::vector<std::shared_ptr<IExpressionCommand>>> const&) override
            {
            }
            void SetParenthesisNumber(unsigned int) override
            {
            }
            void OnNoRightParenAdded() override
            {
            }
            void MaxDigitsReached() override
            {
            }
            void BinaryOperatorReceived() override
            {
            }
            void OnHistoryItemAdded(unsigned int) override
            {
            }
            void SetMemorizedNumbers(const std::vector<std::wstring>&) override
            {
            }
            void MemoryItemChanged(unsigned int) override
            {
            }
            void InputChanged() override
            {
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

    void CalcSession::SetDisplayCallback(DisplayCallback callback)
    {
        m_impl->m_display.callback = std::move(callback);
    }

    void CalcSession::SendCommand(int command)
    {
        m_impl->m_manager.SendCommand(static_cast<CalculationManager::Command>(command));
    }

    void CalcSession::Reset()
    {
        m_impl->m_manager.Reset();
    }

    void CalcSession::SetStandardMode()
    {
        m_impl->m_manager.SetStandardMode();
    }

    void CalcSession::SetScientificMode()
    {
        m_impl->m_manager.SetScientificMode();
    }
}
