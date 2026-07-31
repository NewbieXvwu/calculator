// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// calc_c_api.cpp — C ABI facade implementation (S5).
//
// 只 include CalcSession.h，不 include 任何引擎头（Ratpack 全局 `pi` 与平台
// SDK 符号冲突的隔离规则经此层天然强化）。
// 边界纪律：任何 C++ 异常不得穿过 extern "C"——引擎抛裸 uint32_t 错误码
// （Ratpack/CalcErr.h），在此 catch 并转成返回值。

#include "include/calc_c_api.h"

#include "CalcSession.h"

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <new>
#include <string>
#include <vector>

namespace
{
    // ── UTF-8 ↔ wstring（wchar_t 可能是 2 或 4 字节，两者都支持）──────────

    void AppendCodepoint(std::wstring& out, char32_t cp)
    {
        if constexpr (sizeof(wchar_t) == 2)
        {
            if (cp > 0xFFFF)
            {
                cp -= 0x10000;
                out.push_back(static_cast<wchar_t>(0xD800 + (cp >> 10)));
                out.push_back(static_cast<wchar_t>(0xDC00 + (cp & 0x3FF)));
                return;
            }
        }
        out.push_back(static_cast<wchar_t>(cp));
    }

    std::wstring Utf8ToWide(const char* s)
    {
        std::wstring out;
        if (s == nullptr)
        {
            return out;
        }
        const auto* p = reinterpret_cast<const unsigned char*>(s);
        while (*p != 0)
        {
            char32_t cp;
            int extra;
            if (*p < 0x80)
            {
                cp = *p;
                extra = 0;
            }
            else if ((*p & 0xE0) == 0xC0)
            {
                cp = *p & 0x1F;
                extra = 1;
            }
            else if ((*p & 0xF0) == 0xE0)
            {
                cp = *p & 0x0F;
                extra = 2;
            }
            else if ((*p & 0xF8) == 0xF0)
            {
                cp = *p & 0x07;
                extra = 3;
            }
            else
            {
                ++p; // 非法首字节：跳过
                continue;
            }
            ++p;
            bool valid = true;
            for (int i = 0; i < extra; ++i, ++p)
            {
                if ((*p & 0xC0) != 0x80)
                {
                    valid = false;
                    break;
                }
                cp = (cp << 6) | (*p & 0x3F);
            }
            if (valid)
            {
                AppendCodepoint(out, cp);
            }
        }
        return out;
    }

    std::string WideToUtf8(const std::wstring& w)
    {
        std::string out;
        for (size_t i = 0; i < w.size(); ++i)
        {
            char32_t cp = static_cast<char32_t>(w[i]);
            if constexpr (sizeof(wchar_t) == 2)
            {
                if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < w.size())
                {
                    char32_t lo = static_cast<char32_t>(w[i + 1]);
                    if (lo >= 0xDC00 && lo <= 0xDFFF)
                    {
                        cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                        ++i;
                    }
                }
            }
            if (cp < 0x80)
            {
                out.push_back(static_cast<char>(cp));
            }
            else if (cp < 0x800)
            {
                out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
                out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
            }
            else if (cp < 0x10000)
            {
                out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
                out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
                out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
            }
            else
            {
                out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
                out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
                out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
                out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
            }
        }
        return out;
    }

    char* DupUtf8(const std::string& s)
    {
        char* buffer = static_cast<char*>(std::malloc(s.size() + 1));
        if (buffer != nullptr)
        {
            std::memcpy(buffer, s.c_str(), s.size() + 1);
        }
        return buffer;
    }
}

struct calc_session
{
    explicit calc_session(MacCalc::LocaleStrings locale)
        : impl(std::move(locale))
    {
    }

    MacCalc::CalcSession impl;
    calc_callbacks_t cbs{};
};

namespace
{
    // 把 C 回调表装配成 CalcSession 的 std::function 回调（字符串转 UTF-8）。
    MacCalc::SessionCallbacks BuildCallbacks(calc_session* session)
    {
        MacCalc::SessionCallbacks out;
        const calc_callbacks_t& c = session->cbs;
        void* ud = c.user_data;

        if (c.on_primary_display != nullptr)
        {
            auto fn = c.on_primary_display;
            out.onPrimaryDisplay = [fn, ud](const std::wstring& text, bool isError) {
                fn(ud, WideToUtf8(text).c_str(), isError);
            };
        }
        if (c.on_is_in_error != nullptr)
        {
            auto fn = c.on_is_in_error;
            out.onIsInError = [fn, ud](bool isInError) { fn(ud, isInError); };
        }
        if (c.on_expression_tokens != nullptr)
        {
            auto fn = c.on_expression_tokens;
            out.onExpressionTokens = [fn, ud](const std::vector<std::pair<std::wstring, int>>& tokens) {
                std::vector<std::string> texts;
                texts.reserve(tokens.size());
                for (const auto& t : tokens)
                {
                    texts.push_back(WideToUtf8(t.first));
                }
                std::vector<calc_token_t> cTokens(tokens.size());
                for (size_t i = 0; i < tokens.size(); ++i)
                {
                    cTokens[i].text = texts[i].c_str();
                    cTokens[i].command_index = tokens[i].second;
                }
                fn(ud, cTokens.data(), cTokens.size());
            };
        }
        if (c.on_parenthesis_count != nullptr)
        {
            auto fn = c.on_parenthesis_count;
            out.onParenthesisCount = [fn, ud](unsigned int count) { fn(ud, count); };
        }
        if (c.on_no_right_paren_added != nullptr)
        {
            auto fn = c.on_no_right_paren_added;
            out.onNoRightParenAdded = [fn, ud]() { fn(ud); };
        }
        if (c.on_max_digits_reached != nullptr)
        {
            auto fn = c.on_max_digits_reached;
            out.onMaxDigitsReached = [fn, ud]() { fn(ud); };
        }
        if (c.on_binary_operator_received != nullptr)
        {
            auto fn = c.on_binary_operator_received;
            out.onBinaryOperatorReceived = [fn, ud]() { fn(ud); };
        }
        if (c.on_history_item_added != nullptr)
        {
            auto fn = c.on_history_item_added;
            out.onHistoryItemAdded = [fn, ud](unsigned int index) { fn(ud, index); };
        }
        if (c.on_memorized_numbers != nullptr)
        {
            auto fn = c.on_memorized_numbers;
            out.onMemorizedNumbers = [fn, ud](const std::vector<std::wstring>& values) {
                std::vector<std::string> texts;
                texts.reserve(values.size());
                for (const auto& v : values)
                {
                    texts.push_back(WideToUtf8(v));
                }
                std::vector<const char*> cValues(texts.size());
                for (size_t i = 0; i < texts.size(); ++i)
                {
                    cValues[i] = texts[i].c_str();
                }
                fn(ud, cValues.data(), cValues.size());
            };
        }
        if (c.on_memory_item_changed != nullptr)
        {
            auto fn = c.on_memory_item_changed;
            out.onMemoryItemChanged = [fn, ud](unsigned int index) { fn(ud, index); };
        }
        if (c.on_input_changed != nullptr)
        {
            auto fn = c.on_input_changed;
            out.onInputChanged = [fn, ud]() { fn(ud); };
        }
        return out;
    }
}

// 边界护栏：引擎抛裸 uint32_t（CalcErr.h），其余一切折叠为 CALC_E_UNKNOWN。
// 可变参数：body 内的逗号（函数调用等）不能被当作宏实参分隔。
#define CALC_GUARD(session, ...)               \
    if ((session) == nullptr)                  \
    {                                          \
        return CALC_E_UNKNOWN;                 \
    }                                          \
    try                                        \
    {                                          \
        __VA_ARGS__;                           \
        return CALC_OK;                        \
    }                                          \
    catch (uint32_t code)                      \
    {                                          \
        return code;                           \
    }                                          \
    catch (...)                                \
    {                                          \
        return CALC_E_UNKNOWN;                 \
    }

extern "C" {

calc_session_t* calc_session_create(const calc_locale_t* locale)
{
    try
    {
        MacCalc::LocaleStrings ls;
        if (locale != nullptr)
        {
            if (locale->decimal_separator != nullptr)
            {
                ls.decimalSeparator = Utf8ToWide(locale->decimal_separator);
            }
            if (locale->thousand_separator != nullptr)
            {
                ls.thousandSeparator = Utf8ToWide(locale->thousand_separator);
            }
            if (locale->grouping != nullptr)
            {
                ls.grouping = Utf8ToWide(locale->grouping);
            }
        }
        return new calc_session(std::move(ls));
    }
    catch (...)
    {
        return nullptr;
    }
}

void calc_session_destroy(calc_session_t* session)
{
    delete session;
}

calc_error_t calc_session_set_callbacks(calc_session_t* session, const calc_callbacks_t* callbacks)
{
    CALC_GUARD(session, {
        session->cbs = callbacks != nullptr ? *callbacks : calc_callbacks_t{};
        session->impl.SetCallbacks(BuildCallbacks(session));
    })
}

calc_error_t calc_send_command(calc_session_t* session, int32_t command)
{
    CALC_GUARD(session, { session->impl.SendCommand(command); })
}

calc_error_t calc_send_digit(calc_session_t* session, int32_t digit)
{
    // Command0 = 130（Command.h：0–F 连续排列）。
    CALC_GUARD(session, {
        if (digit < 0 || digit > 15)
        {
            return CALC_E_UNKNOWN;
        }
        session->impl.SendCommand(130 + digit);
    })
}

calc_error_t calc_display_paste_error(calc_session_t* session)
{
    CALC_GUARD(session, { session->impl.DisplayPasteError(); })
}

calc_error_t calc_reset(calc_session_t* session, bool clear_memory)
{
    CALC_GUARD(session, { session->impl.Reset(clear_memory); })
}

calc_error_t calc_set_mode(calc_session_t* session, calc_mode_t mode)
{
    CALC_GUARD(session, {
        switch (mode)
        {
        case CALC_MODE_STANDARD:
            session->impl.SetStandardMode();
            break;
        case CALC_MODE_SCIENTIFIC:
            session->impl.SetScientificMode();
            break;
        case CALC_MODE_PROGRAMMER:
            session->impl.SetProgrammerMode();
            break;
        default:
            return CALC_E_UNKNOWN;
        }
    })
}

bool calc_is_engine_recording(calc_session_t* session)
{
    try
    {
        return session != nullptr && session->impl.IsEngineRecording();
    }
    catch (...)
    {
        return false;
    }
}

bool calc_is_input_empty(calc_session_t* session)
{
    try
    {
        return session == nullptr || session->impl.IsInputEmpty();
    }
    catch (...)
    {
        return true;
    }
}

bool calc_precision_limited(void)
{
    return MacCalc::CalcSession::PrecisionLimited();
}

void calc_clear_precision_limited(void)
{
    MacCalc::CalcSession::ClearPrecisionLimited();
}

uint32_t calc_decimal_separator(calc_session_t* session)
{
    try
    {
        return session != nullptr ? static_cast<uint32_t>(session->impl.DecimalSeparator()) : U'.';
    }
    catch (...)
    {
        return U'.';
    }
}

calc_error_t calc_set_precision(calc_session_t* session, int32_t precision)
{
    CALC_GUARD(session, { session->impl.SetPrecision(precision); })
}

calc_error_t calc_update_max_int_digits(calc_session_t* session)
{
    CALC_GUARD(session, { session->impl.UpdateMaxIntDigits(); })
}

calc_error_t calc_set_radix(calc_session_t* session, calc_radix_type_t radix_type)
{
    CALC_GUARD(session, { session->impl.SetRadix(static_cast<int>(radix_type)); })
}

char* calc_result_for_radix(calc_session_t* session, uint32_t radix, int32_t precision, bool group_digits)
{
    try
    {
        if (session == nullptr)
        {
            return nullptr;
        }
        return DupUtf8(WideToUtf8(session->impl.GetResultForRadix(radix, precision, group_digits)));
    }
    catch (...)
    {
        return nullptr;
    }
}

calc_error_t calc_memory_store(calc_session_t* session)
{
    CALC_GUARD(session, { session->impl.MemorizeNumber(); })
}

calc_error_t calc_memory_recall(calc_session_t* session, uint32_t index)
{
    CALC_GUARD(session, { session->impl.MemorizedNumberLoad(index); })
}

calc_error_t calc_memory_add(calc_session_t* session, uint32_t index)
{
    CALC_GUARD(session, { session->impl.MemorizedNumberAdd(index); })
}

calc_error_t calc_memory_subtract(calc_session_t* session, uint32_t index)
{
    CALC_GUARD(session, { session->impl.MemorizedNumberSubtract(index); })
}

calc_error_t calc_memory_clear(calc_session_t* session, uint32_t index)
{
    CALC_GUARD(session, { session->impl.MemorizedNumberClear(index); })
}

calc_error_t calc_memory_clear_all(calc_session_t* session)
{
    CALC_GUARD(session, { session->impl.MemorizedNumberClearAll(); })
}

size_t calc_history_count(calc_session_t* session)
{
    try
    {
        return session != nullptr ? session->impl.GetHistoryEntries().size() : 0;
    }
    catch (...)
    {
        return 0;
    }
}

calc_error_t calc_history_entry(calc_session_t* session, size_t index, char** out_expression, char** out_result)
{
    CALC_GUARD(session, {
        if (out_expression == nullptr || out_result == nullptr)
        {
            return CALC_E_UNKNOWN;
        }
        auto entries = session->impl.GetHistoryEntries();
        if (index >= entries.size())
        {
            return CALC_E_UNKNOWN;
        }
        char* expression = DupUtf8(WideToUtf8(entries[index].expression));
        char* result = DupUtf8(WideToUtf8(entries[index].result));
        if (expression == nullptr || result == nullptr)
        {
            std::free(expression);
            std::free(result);
            return CALC_E_UNKNOWN;
        }
        *out_expression = expression;
        *out_result = result;
    })
}

bool calc_history_remove(calc_session_t* session, uint32_t index)
{
    try
    {
        return session != nullptr && session->impl.RemoveHistoryItem(index);
    }
    catch (...)
    {
        return false;
    }
}

calc_error_t calc_history_clear(calc_session_t* session)
{
    CALC_GUARD(session, { session->impl.ClearHistory(); })
}

bool calc_is_operand_token(calc_session_t* session, uint32_t token_position)
{
    try
    {
        return session != nullptr && session->impl.IsTokenEditableOperand(token_position);
    }
    catch (...)
    {
        return false;
    }
}

bool calc_update_operand(
    calc_session_t* session,
    uint32_t token_position,
    const char* utf8_text,
    bool scientific_mode,
    bool f_to_e_checked)
{
    try
    {
        return session != nullptr
            && session->impl.UpdateOperandAtToken(token_position, Utf8ToWide(utf8_text), scientific_mode, f_to_e_checked);
    }
    catch (...)
    {
        return false;
    }
}

void calc_string_free(char* s)
{
    std::free(s);
}

size_t calc_grouping_format(const calc_grouping_t* grouping, char* out, size_t cap)
{
    if (grouping == nullptr)
    {
        if (out != nullptr && cap > 0)
        {
            out[0] = '\0';
        }
        return 0;
    }
    MacCalc::Grouping g;
    g.primary = grouping->primary;
    g.secondary = grouping->secondary;
    g.repeatSecondary = grouping->repeat_secondary;
    g.minimumGroupingDigits = grouping->minimum_grouping_digits;
    const std::string utf8 = WideToUtf8(g.EngineString());
    if (out != nullptr && cap > 0)
    {
        const size_t n = std::min(cap - 1, utf8.size());
        std::memcpy(out, utf8.data(), n);
        out[n] = '\0';
    }
    return utf8.size();
}

} // extern "C"
