// Smoke test: verify CalcManager engine works on macOS.
// Computes 1 + 2 = and 2 * 8 = via CalculatorManager, checks display output.

#include <iostream>
#include <string>
#include <vector>
#include <memory>

#include "CalculatorManager.h"
#include "CalculatorResource.h"

using namespace CalculationManager;

class SmokeDisplay : public ICalcDisplay
{
public:
    std::wstring primary;

    void SetPrimaryDisplay(const std::wstring& text, bool /*isError*/) override
    {
        primary = text;
    }
    void SetIsInError(bool /*isInError*/) override
    {
    }
    void SetExpressionDisplay(
        std::shared_ptr<std::vector<std::pair<std::wstring, int>>> const& /*tokens*/,
        std::shared_ptr<std::vector<std::shared_ptr<IExpressionCommand>>> const& /*commands*/) override
    {
    }
    void SetParenthesisNumber(unsigned int /*count*/) override
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
    void OnHistoryItemAdded(unsigned int /*addedItemIndex*/) override
    {
    }
    void SetMemorizedNumbers(const std::vector<std::wstring>& /*memorizedNumbers*/) override
    {
    }
    void MemoryItemChanged(unsigned int /*indexOfMemory*/) override
    {
    }
    void InputChanged() override
    {
    }
};

class SmokeResourceProvider : public IResourceProvider
{
public:
    std::wstring GetCEngineString(std::wstring_view id) override
    {
        if (id == L"sDecimal")
        {
            return L".";
        }
        if (id == L"sThousand")
        {
            return L",";
        }
        if (id == L"sGrouping")
        {
            return L"3;0";
        }
        return std::wstring{};
    }
};

int main()
{
    SmokeDisplay display;
    SmokeResourceProvider resourceProvider;
    CalculatorManager manager(&display, &resourceProvider);

    manager.SetStandardMode();

    int failures = 0;
    auto check = [&](const wchar_t* label, const std::wstring& expected) {
        bool ok = display.primary == expected;
        std::wcout << (ok ? L"PASS" : L"FAIL") << L": " << label << L" -> \"" << display.primary << L"\" (expected \""
                   << expected << L"\")" << std::endl;
        if (!ok)
        {
            failures++;
        }
    };

    manager.SendCommand(Command::Command1);
    manager.SendCommand(Command::CommandADD);
    manager.SendCommand(Command::Command2);
    manager.SendCommand(Command::CommandEQU);
    check(L"1 + 2 =", L"3");

    manager.Reset();
    manager.SendCommand(Command::Command2);
    manager.SendCommand(Command::CommandMUL);
    manager.SendCommand(Command::Command8);
    manager.SendCommand(Command::CommandEQU);
    check(L"2 * 8 =", L"16");

    manager.Reset();
    manager.SendCommand(Command::Command1);
    manager.SendCommand(Command::Command0);
    manager.SendCommand(Command::CommandDIV);
    manager.SendCommand(Command::Command3);
    manager.SendCommand(Command::CommandEQU);
    check(L"10 / 3 =", L"3.333333333333333");

    return failures == 0 ? 0 : 1;
}
