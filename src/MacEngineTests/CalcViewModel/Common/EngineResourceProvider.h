// Portable stand-in for CalcViewModel/Common/EngineResourceProvider.h.
// Serves the en-US engine strings generated from CEngineStrings.resw,
// with en-US number formatting, matching what the upstream tests expect.

#pragma once

#include <string>
#include <string_view>

#include "CalcManager/CalculatorResource.h"
#include "EngineStringsData.g.h"

namespace CalculatorApp::ViewModel::Common
{
    class EngineResourceProvider : public CalculationManager::IResourceProvider
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

            const auto& table = MacCalc::EngineStringsEnUS();
            auto it = table.find(id);
            return it != table.end() ? std::wstring(it->second) : std::wstring();
        }
    };
}
