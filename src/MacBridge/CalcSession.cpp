// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "CalcSession.h"

#include <utility>
#include <vector>

#include "CalculatorManager.h"
#include "CalculatorResource.h"
#include "ExpressionCommandInterface.h"
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
            std::shared_ptr<std::vector<std::pair<std::wstring, int>>> lastTokens;
            std::shared_ptr<std::vector<std::shared_ptr<IExpressionCommand>>> lastCommands;
            bool isInError = false;

            void SetPrimaryDisplay(const std::wstring& text, bool isError) override
            {
                isInError = isError;
                if (callbacks.onPrimaryDisplay)
                {
                    callbacks.onPrimaryDisplay(text, isError);
                }
            }
            void SetIsInError(bool isInErrorState) override
            {
                isInError = isInErrorState;
                if (callbacks.onIsInError)
                {
                    callbacks.onIsInError(isInErrorState);
                }
            }
            void SetExpressionDisplay(
                std::shared_ptr<std::vector<std::pair<std::wstring, int>>> const& tokens,
                std::shared_ptr<std::vector<std::shared_ptr<IExpressionCommand>>> const& commands) override
            {
                lastTokens = tokens;
                lastCommands = commands;
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

    namespace
    {
        // Port of GetCommandsFromExpressionCommands (StandardCalculatorViewModel.cpp).
        std::vector<int> FlattenExpressionCommands(const std::vector<std::shared_ptr<IExpressionCommand>>& expressionCommands)
        {
            constexpr int kCommandDigit0 = static_cast<int>(CalculationManager::Command::Command0);
            std::vector<int> commands;
            for (const auto& command : expressionCommands)
            {
                switch (command->GetCommandType())
                {
                case CalculationManager::CommandType::UnaryCommand:
                {
                    auto spCommand = std::dynamic_pointer_cast<IUnaryCommand>(command);
                    for (int code : *spCommand->GetCommands())
                    {
                        commands.push_back(code);
                    }
                    break;
                }
                case CalculationManager::CommandType::BinaryCommand:
                    commands.push_back(std::dynamic_pointer_cast<IBinaryCommand>(command)->GetCommand());
                    break;
                case CalculationManager::CommandType::Parentheses:
                    commands.push_back(std::dynamic_pointer_cast<IParenthesisCommand>(command)->GetCommand());
                    break;
                case CalculationManager::CommandType::OperandCommand:
                {
                    auto spCommand = std::dynamic_pointer_cast<IOpndCommand>(command);
                    bool needSign = spCommand->IsNegative();
                    for (int code : *spCommand->GetCommands())
                    {
                        commands.push_back(code);
                        if (needSign && code != kCommandDigit0)
                        {
                            commands.push_back(static_cast<int>(CalculationManager::Command::CommandSIGN));
                            needSign = false;
                        }
                    }
                    break;
                }
                }
            }
            return commands;
        }

        std::shared_ptr<IOpndCommand> OperandCommandAtToken(
            const std::shared_ptr<std::vector<std::pair<std::wstring, int>>>& tokens,
            const std::shared_ptr<std::vector<std::shared_ptr<IExpressionCommand>>>& commands,
            unsigned int tokenPosition)
        {
            if (!tokens || !commands || tokenPosition >= tokens->size())
            {
                return nullptr;
            }
            int commandPosition = tokens->at(tokenPosition).second;
            if (commandPosition < 0 || static_cast<size_t>(commandPosition) >= commands->size())
            {
                return nullptr;
            }
            return std::dynamic_pointer_cast<IOpndCommand>(commands->at(commandPosition));
        }
    }

    bool CalcSession::IsTokenEditableOperand(unsigned int tokenPosition) const
    {
        return OperandCommandAtToken(m_impl->m_display.lastTokens, m_impl->m_display.lastCommands, tokenPosition) != nullptr;
    }

    bool CalcSession::UpdateOperandAtToken(unsigned int tokenPosition, const std::wstring& newText, bool scientificMode, bool fToEChecked)
    {
        using CalculationManager::Command;

        auto& display = m_impl->m_display;
        auto operandCommand = OperandCommandAtToken(display.lastTokens, display.lastCommands, tokenPosition);
        if (operandCommand == nullptr)
        {
            return false;
        }

        // Mirrors StandardCalculatorViewModel::UpdateOperand.
        auto commands = std::make_shared<std::vector<int>>();
        if (!newText.empty())
        {
            for (size_t i = 0; i < newText.length(); ++i)
            {
                int num = 0;
                wchar_t ch = newText[i];
                if (ch == L'.')
                {
                    num = static_cast<int>(Command::CommandPNT);
                }
                else if (ch == L'e')
                {
                    num = static_cast<int>(Command::CommandEXP);
                }
                else if (ch == L'-')
                {
                    num = static_cast<int>(Command::CommandSIGN);
                    if (i == 0)
                    {
                        if (!operandCommand->IsNegative())
                        {
                            operandCommand->ToggleSign();
                        }
                        continue;
                    }
                }
                else if (ch >= L'0' && ch <= L'9')
                {
                    num = static_cast<int>(Command::Command0) + (ch - L'0');
                }
                else
                {
                    return false;
                }
                commands->push_back(num);
            }
            if (newText[0] != L'-' && operandCommand->IsNegative())
            {
                operandCommand->ToggleSign();
            }
        }
        else
        {
            commands->push_back(0);
            if (operandCommand->IsNegative())
            {
                operandCommand->ToggleSign();
            }
        }
        operandCommand->SetCommands(commands);

        // Mirrors StandardCalculatorViewModel::Recalculate.
        auto& manager = m_impl->m_manager;
        Command currentDegreeMode = manager.GetCurrentDegreeMode();
        auto savedCommands = std::make_shared<std::vector<std::shared_ptr<IExpressionCommand>>>(*display.lastCommands);
        auto savedTokens = std::make_shared<std::vector<std::pair<std::wstring, int>>>(*display.lastTokens);
        std::vector<int> currentCommands = FlattenExpressionCommands(*display.lastCommands);

        manager.Reset(false);
        if (scientificMode)
        {
            manager.SendCommand(Command::ModeScientific);
        }
        if (fToEChecked)
        {
            manager.SendCommand(Command::CommandFE);
        }
        manager.SendCommand(currentDegreeMode);
        for (int command : currentCommands)
        {
            manager.SendCommand(static_cast<Command>(command));
        }

        if (display.isInError)
        {
            display.SetExpressionDisplay(savedTokens, savedCommands);
            return false;
        }
        return true;
    }
}
