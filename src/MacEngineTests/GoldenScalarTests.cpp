// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S10 · 黄金测试：tests/golden/scalar_vectors.txt 是跨平台唯一事实来源。
// 所有平台（x86-64 / aarch64 / WASM）跑同一份向量，要求逐位一致——
// 不一致 = 移植 bug，不是"平台差异"。
//
// 向量类型（竖线分隔三段）：
//   E <mode> | <引擎命令 token 序列> | <期望主显示串>
//   D        | <RPN：IEEE 保证正确舍入的运算 + - * / sqrt neg> | <期望十六进制浮点>
//   R <base> | <程序员模式数字输入>       | <radix>=<期望> 列表（空格分隔）
// D 段只收录 IEEE754 要求正确舍入的运算（含 strtod 十进制→binary64 转换），
// libm 超越函数不在此列（各平台实现末位可差 1 ulp，锁不住）；超越函数经
// E 段引擎向量覆盖——Ratpack 泰勒级数是纯整数运算，全平台逐位确定。

#include "pch.h"

#include <CppUnitTest.h>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

#include "CalcManager/CalculatorManager.h"
#include "CalcViewModel/Common/EngineResourceProvider.h"
#include "Ratpack/ratpak.h"

using namespace CalculationManager;
using namespace CalculatorApp::ViewModel::Common;
using namespace std;
using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace GoldenTests
{
    // 最小 ICalcDisplay：只留主显示。
    class GoldenDisplay final : public ICalcDisplay
    {
    public:
        void SetPrimaryDisplay(const wstring& text, bool isError) override
        {
            m_display = text;
            m_isError = isError;
        }
        void SetIsInError(bool isError) override
        {
            m_isError = isError;
        }
        void SetExpressionDisplay(
            _Inout_ shared_ptr<vector<pair<wstring, int>>> const& /*tokens*/,
            _Inout_ shared_ptr<vector<shared_ptr<IExpressionCommand>>> const& /*commands*/) override
        {
        }
        void SetMemorizedNumbers(const vector<wstring>& /*numbers*/) override
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
        void OnHistoryItemAdded(_In_ unsigned int /*addedItemIndex*/) override
        {
        }
        void MemoryItemChanged(unsigned int /*indexOfMemory*/) override
        {
        }
        void InputChanged() override
        {
        }

        const wstring& Display() const
        {
            return m_display;
        }
        bool IsError() const
        {
            return m_isError;
        }

    private:
        wstring m_display;
        bool m_isError = false;
    };

    namespace
    {
        // __FILE__ 是编译期绝对路径（SPM 传绝对路径），据此定位仓库内向量文件，
        // 与 cwd 无关（本地任意目录 / CI 仓库根都能跑）。
        string VectorsPath()
        {
            string self = __FILE__;
            const size_t slash = self.find_last_of('/');
            return self.substr(0, slash) + "/../../tests/golden/scalar_vectors.txt";
        }

        const map<string, Command>& TokenMap()
        {
            static const map<string, Command> tokens = {
                { "0", Command::Command0 },     { "1", Command::Command1 },     { "2", Command::Command2 },
                { "3", Command::Command3 },     { "4", Command::Command4 },     { "5", Command::Command5 },
                { "6", Command::Command6 },     { "7", Command::Command7 },     { "8", Command::Command8 },
                { "9", Command::Command9 },     { "a", Command::CommandA },     { "b", Command::CommandB },
                { "c", Command::CommandC },     { "d", Command::CommandD },     { "e", Command::CommandE },
                { "f", Command::CommandF },     { ".", Command::CommandPNT },   { "+", Command::CommandADD },
                { "-", Command::CommandSUB },   { "*", Command::CommandMUL },   { "/", Command::CommandDIV },
                { "=", Command::CommandEQU },   { "sqrt", Command::CommandSQRT }, { "sqr", Command::CommandSQR },
                { "cube", Command::CommandCUB }, { "rec", Command::CommandREC }, { "fac", Command::CommandFAC },
                { "sin", Command::CommandSIN }, { "cos", Command::CommandCOS }, { "tan", Command::CommandTAN },
                { "ln", Command::CommandLN },   { "log", Command::CommandLOG }, { "powe", Command::CommandPOWE },
                { "pow10", Command::CommandPOW10 }, { "pi", Command::CommandPI }, { "neg", Command::CommandSIGN },
                { "open", Command::CommandOPENP }, { "close", Command::CommandCLOSEP },
                { "rad", Command::CommandRAD }, { "deg", Command::CommandDEG }, { "grad", Command::CommandGRAD },
                { "exp", Command::CommandEXP }, { "pwr", Command::CommandPWR }, { "mod", Command::CommandMOD },
                { "back", Command::CommandBACK }, { "ce", Command::CommandCENTR }, { "clear", Command::CommandCLEAR },
            };
            return tokens;
        }

        vector<string> Split(const string& text, char sep)
        {
            vector<string> parts;
            string part;
            istringstream stream(text);
            while (getline(stream, part, sep))
            {
                parts.push_back(part);
            }
            return parts;
        }

        vector<string> Words(const string& text)
        {
            vector<string> words;
            istringstream stream(text);
            string word;
            while (stream >> word)
            {
                words.push_back(word);
            }
            return words;
        }

        string Trim(const string& text)
        {
            const size_t first = text.find_first_not_of(" \t");
            if (first == string::npos)
            {
                return "";
            }
            const size_t last = text.find_last_not_of(" \t");
            return text.substr(first, last - first + 1);
        }

        wstring Widen(const string& text)
        {
            return wstring(text.begin(), text.end());
        }

        string Narrow(const wstring& text)
        {
            string result;
            for (wchar_t ch : text)
            {
                result += ch < 128 ? static_cast<char>(ch) : '?';
            }
            return result;
        }

        [[noreturn]] void FailLine(int lineNo, const string& detail)
        {
            wostringstream message;
            message << L"scalar_vectors.txt line " << lineNo << L": " << Widen(detail).c_str();
            Assert::Fail(message.str().c_str());
        }

        // D 段 RPN：仅 IEEE 正确舍入运算。数字用 strtod（十进制/0x 十六进制均可）。
        double EvalRpn(const vector<string>& tokens, int lineNo)
        {
            vector<double> stack;
            auto pop = [&](const char* op) {
                if (stack.empty())
                {
                    FailLine(lineNo, string("RPN stack underflow at ") + op);
                }
                const double value = stack.back();
                stack.pop_back();
                return value;
            };
            for (const auto& token : tokens)
            {
                if (token == "+" || token == "-" || token == "*" || token == "/")
                {
                    const double b = pop(token.c_str());
                    const double a = pop(token.c_str());
                    stack.push_back(token == "+" ? a + b : token == "-" ? a - b : token == "*" ? a * b : a / b);
                }
                else if (token == "sqrt")
                {
                    stack.push_back(sqrt(pop("sqrt")));
                }
                else if (token == "neg")
                {
                    stack.push_back(-pop("neg"));
                }
                else
                {
                    char* end = nullptr;
                    const double value = strtod(token.c_str(), &end);
                    if (end == nullptr || *end != '\0')
                    {
                        FailLine(lineNo, "bad RPN token: " + token);
                    }
                    stack.push_back(value);
                }
            }
            if (stack.size() != 1)
            {
                FailLine(lineNo, "RPN stack not reduced to one value");
            }
            return stack.back();
        }

        string HexFloat(double value)
        {
            char buffer[64];
            snprintf(buffer, sizeof(buffer), "%a", value);
            return buffer;
        }

        bool SameBits(double a, double b)
        {
            uint64_t ba = 0;
            uint64_t bb = 0;
            memcpy(&ba, &a, sizeof(ba));
            memcpy(&bb, &b, sizeof(bb));
            return ba == bb;
        }
    }

    TEST_CLASS(GoldenScalarTests)
    {
    public:
        TEST_CLASS_INITIALIZE(CommonSetup)
        {
            s_display = make_shared<GoldenDisplay>();
            s_resourceProvider = make_shared<EngineResourceProvider>();
            s_manager = make_shared<CalculatorManager>(s_display.get(), s_resourceProvider.get());
        }

        TEST_METHOD(GoldenVectors)
        {
            ifstream file(VectorsPath());
            Assert::IsTrue(file.is_open(), L"tests/golden/scalar_vectors.txt not found");

            s_mismatches.clear();
            string line;
            int lineNo = 0;
            int vectors = 0;
            while (getline(file, line))
            {
                lineNo++;
                const string trimmed = Trim(line);
                if (trimmed.empty() || trimmed[0] == '#')
                {
                    continue;
                }
                vector<string> parts = Split(trimmed, '|');
                if (parts.size() != 3)
                {
                    FailLine(lineNo, "expected 3 |-separated fields");
                }
                const vector<string> head = Words(parts[0]);
                const string expected = Trim(parts[2]);
                if (head.empty())
                {
                    FailLine(lineNo, "empty record type");
                }
                if (head[0] == "E")
                {
                    RunEngineVector(head, Words(parts[1]), expected, lineNo);
                }
                else if (head[0] == "D")
                {
                    RunDoubleVector(Words(parts[1]), expected, lineNo);
                }
                else if (head[0] == "R")
                {
                    RunRadixVector(head, Words(parts[1]), Words(parts[2]), lineNo);
                }
                else
                {
                    FailLine(lineNo, "unknown record type: " + head[0]);
                }
                vectors++;
            }
            Assert::IsTrue(vectors >= 20, L"suspiciously few golden vectors parsed");

            // 一次报告全部差异（而非首个即止），方便定位成批漂移。
            for (const auto& mismatch : s_mismatches)
            {
                Logger::WriteMessage(("GOLDEN MISMATCH " + mismatch).c_str());
            }
            if (!s_mismatches.empty())
            {
                wostringstream message;
                message << s_mismatches.size() << L" golden vector mismatch(es), see log";
                Assert::Fail(message.str().c_str());
            }
        }

        // S10 Ratpack 闸门：10^12000 的分子超过 kMaxRationalDigits，
        // trimit 必须强制截断（cdigit 有界）并置粘滞标志；显示值不变（1e+12000）。
        TEST_METHOD(RatpackGateTruncatesAndSetsFlag)
        {
            ChangeConstants(10, 32);
            rat_clear_precision_limited();
            Assert::IsFalse(rat_precision_limited());

            PRAT power = i32torat(10);
            ratpowi32(&power, 12000, 32);

            Assert::IsTrue(rat_precision_limited(), L"gate flag not set after 10^12000");
            Assert::IsTrue(power->pp->cdigit <= 8, L"numerator cdigit not bounded by gate");
            Assert::IsTrue(power->pq->cdigit <= 8, L"denominator cdigit not bounded by gate");

            const wstring display = RatToString(power, NumberFormat::Float, 10, 32);
            destroyrat(power);
            if (display != L"1.e+12000")
            {
                wostringstream message;
                message << L"10^12000 after gate -> " << display.c_str();
                Assert::Fail(message.str().c_str());
            }

            rat_clear_precision_limited();
            Assert::IsFalse(rat_precision_limited());
        }

        // 引擎标准/科学模式常规精度运算不得触发闸门（不能把正常计算降级成近似）。
        TEST_METHOD(RatpackGateNotTriggeredByOrdinaryMath)
        {
            ChangeConstants(10, 32);
            rat_clear_precision_limited();

            PRAT value = i32torat(7);
            ratpowi32(&value, 100, 32); // 7^100 ≈ 3.2e84：85 位十进制，远低于上限
            Assert::IsFalse(rat_precision_limited(), L"gate fired on 7^100");
            destroyrat(value);
        }

    private:
        static shared_ptr<GoldenDisplay> s_display;
        static shared_ptr<EngineResourceProvider> s_resourceProvider;
        static shared_ptr<CalculatorManager> s_manager;
        static vector<string> s_mismatches;

        static void AddMismatch(int lineNo, const string& detail)
        {
            s_mismatches.push_back("line " + to_string(lineNo) + ": " + detail);
        }

        static void RunEngineVector(const vector<string>& head, const vector<string>& tokens, const string& expected, int lineNo)
        {
            if (head.size() != 2)
            {
                FailLine(lineNo, "E record needs a mode (std/sci/prog)");
            }
            s_manager->Reset();
            if (head[1] == "std")
            {
                s_manager->SetStandardMode();
            }
            else if (head[1] == "sci")
            {
                s_manager->SetScientificMode();
            }
            else if (head[1] == "prog")
            {
                s_manager->SetProgrammerMode();
            }
            else
            {
                FailLine(lineNo, "unknown mode: " + head[1]);
            }

            const auto& map = TokenMap();
            for (const auto& token : tokens)
            {
                const auto found = map.find(token);
                if (found == map.end())
                {
                    FailLine(lineNo, "unknown engine token: " + token);
                }
                s_manager->SendCommand(found->second);
            }

            const string actual = Narrow(s_display->Display());
            if (actual != expected)
            {
                AddMismatch(lineNo, "engine display: expected \"" + expected + "\" actual \"" + actual + "\"");
            }
        }

        static void RunDoubleVector(const vector<string>& tokens, const string& expected, int lineNo)
        {
            const double actual = EvalRpn(tokens, lineNo);
            char* end = nullptr;
            const double expectedValue = strtod(expected.c_str(), &end);
            if (end == nullptr || *end != '\0')
            {
                FailLine(lineNo, "bad expected hex float: " + expected);
            }
            if (!SameBits(actual, expectedValue))
            {
                AddMismatch(lineNo, "double: expected " + expected + " actual " + HexFloat(actual));
            }
        }

        static void RunRadixVector(const vector<string>& head, const vector<string>& digits, const vector<string>& expectations, int lineNo)
        {
            static const map<string, int> radixTypes = { { "hex", 0 }, { "dec", 1 }, { "oct", 2 }, { "bin", 3 } };
            static const map<string, uint32_t> radixValues = { { "hex", 16 }, { "dec", 10 }, { "oct", 8 }, { "bin", 2 } };
            if (head.size() != 2 || radixTypes.find(head[1]) == radixTypes.end())
            {
                FailLine(lineNo, "R record needs an input base (hex/dec/oct/bin)");
            }

            s_manager->Reset();
            s_manager->SetProgrammerMode();
            s_manager->SetRadix(static_cast<RadixType>(radixTypes.at(head[1])));

            const auto& map = TokenMap();
            for (const auto& token : digits)
            {
                const auto found = map.find(token);
                if (found == map.end())
                {
                    FailLine(lineNo, "unknown digit token: " + token);
                }
                s_manager->SendCommand(found->second);
            }

            for (const auto& expectation : expectations)
            {
                const vector<string> pair = Split(expectation, '=');
                if (pair.size() != 2 || radixValues.find(pair[0]) == radixValues.end())
                {
                    FailLine(lineNo, "bad radix expectation: " + expectation);
                }
                const string actual = Narrow(s_manager->GetResultForRadix(radixValues.at(pair[0]), 64, false));
                if (actual != pair[1])
                {
                    AddMismatch(lineNo, "radix " + pair[0] + ": expected " + pair[1] + " actual " + actual);
                }
            }
            // 复位回十进制，避免影响后续向量。
            s_manager->SetRadix(static_cast<RadixType>(1));
        }
    };

    shared_ptr<GoldenDisplay> GoldenScalarTests::s_display;
    shared_ptr<EngineResourceProvider> GoldenScalarTests::s_resourceProvider;
    shared_ptr<CalculatorManager> GoldenScalarTests::s_manager;
    vector<string> GoldenScalarTests::s_mismatches;
}

REGISTER_TEST_CLASS(GoldenTests::GoldenScalarTests)
