// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// calc_c_api.h — C ABI facade over the pure-C++ CalcSession (S5).
//
// This is the single cross-platform entry point into the CalcManager engine:
//   Swift (direct import) / Kotlin (JNI) / TS-JS (Emscripten) / ArkTS (NAPI) /
//   C# (P/Invoke) all bind against this header. Do NOT add C++ or ObjC types.
//
// Contract:
//   - All strings are UTF-8. Strings returned as char* are heap copies owned
//     by the caller; release them with calc_string_free().
//   - Strings passed to callbacks are only valid for the duration of the call.
//   - No C++ exception ever crosses this boundary. Engine errors (the raw
//     uint32_t codes from Ratpack/CalcErr.h) are returned as calc_error_t;
//     CALC_OK (0) means success, CALC_E_UNKNOWN means a non-engine failure.
//   - Sessions are not thread-safe; callers must serialize access per session
//     (same as CalcSession).

#ifndef CALC_C_API_H
#define CALC_C_API_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct calc_session calc_session_t;

/// CALC_OK on success; otherwise a raw engine error code (CalcErr.h) or
/// CALC_E_UNKNOWN for unexpected non-engine failures.
typedef uint32_t calc_error_t;
#define CALC_OK ((calc_error_t)0)
#define CALC_E_UNKNOWN ((calc_error_t)0xFFFFFFFFu)

/// Locale separators injected into the engine's number formatter (see S8).
/// NULL members fall back to "." / "," / "3;0".
typedef struct calc_locale {
    const char* decimal_separator;
    const char* thousand_separator;
    const char* grouping;
} calc_locale_t;

/// Digit grouping pattern (S8): platforms fill this from their locale APIs
/// (ICU getGroupingSize/getSecondaryGroupingSize, NSNumberFormatter
/// groupingSize/secondaryGroupingSize, ...) instead of hand-writing engine
/// grouping strings. minimum_grouping_digits is carried for consumers that
/// support it; the engine's GroupDigits currently ignores it.
typedef struct calc_grouping {
    int32_t primary;                  /* 3; <= 0 disables grouping           */
    int32_t secondary;                /* 2 for Indian lakh/crore; 0 = none   */
    bool repeat_secondary;            /* true: last group repeats infinitely */
    int32_t minimum_grouping_digits;  /* CLDR minimumGroupingDigits, >= 1    */
} calc_grouping_t;

/// Formats `grouping` as the engine's sGrouping string ("3;0", "3;2;0", ...).
/// Writes at most cap bytes (NUL-terminated when cap > 0) and returns the
/// full length excluding the NUL, snprintf style.
size_t calc_grouping_format(const calc_grouping_t* grouping, char* out, size_t cap);

typedef enum calc_mode {
    CALC_MODE_STANDARD = 0,
    CALC_MODE_SCIENTIFIC = 1,
    CALC_MODE_PROGRAMMER = 2,
} calc_mode_t;

/// RadixType.h: 0=Hex 1=Decimal 2=Octal 3=Binary.
typedef enum calc_radix_type {
    CALC_RADIX_HEX = 0,
    CALC_RADIX_DECIMAL = 1,
    CALC_RADIX_OCTAL = 2,
    CALC_RADIX_BINARY = 3,
} calc_radix_type_t;

/// One expression-display token. command_index >= 0 means the token is an
/// editable operand; -1 means static text.
typedef struct calc_token {
    const char* text;
    int32_t command_index;
} calc_token_t;

/// Mirrors ICalcDisplay. Every hook is optional (leave NULL to ignore).
/// user_data is passed back verbatim as the first argument of every hook.
typedef struct calc_callbacks {
    void* user_data;
    void (*on_primary_display)(void* user_data, const char* utf8_text, bool is_error);
    void (*on_is_in_error)(void* user_data, bool is_in_error);
    void (*on_expression_tokens)(void* user_data, const calc_token_t* tokens, size_t count);
    void (*on_parenthesis_count)(void* user_data, uint32_t count);
    void (*on_no_right_paren_added)(void* user_data);
    void (*on_max_digits_reached)(void* user_data);
    void (*on_binary_operator_received)(void* user_data);
    void (*on_history_item_added)(void* user_data, uint32_t index);
    void (*on_memorized_numbers)(void* user_data, const char* const* utf8_values, size_t count);
    void (*on_memory_item_changed)(void* user_data, uint32_t index);
    void (*on_input_changed)(void* user_data);
} calc_callbacks_t;

// ── Session lifecycle ──────────────────────────────────────────────────────

/// Returns NULL on failure. `locale` may be NULL for defaults.
calc_session_t* calc_session_create(const calc_locale_t* locale);
void calc_session_destroy(calc_session_t* session);

/// Copies the callback table (pass NULL to clear all hooks).
calc_error_t calc_session_set_callbacks(calc_session_t* session, const calc_callbacks_t* callbacks);

// ── Commands & modes ───────────────────────────────────────────────────────

/// `command` mirrors CalculationManager::Command (Command.h).
calc_error_t calc_send_command(calc_session_t* session, int32_t command);
/// Convenience: digit 0–15 (10–15 = A–F in programmer mode).
calc_error_t calc_send_digit(calc_session_t* session, int32_t digit);
/// Shows the engine's "Invalid input" error (CalculatorManager::DisplayPasteError).
calc_error_t calc_display_paste_error(calc_session_t* session);
calc_error_t calc_reset(calc_session_t* session, bool clear_memory);
calc_error_t calc_set_mode(calc_session_t* session, calc_mode_t mode);

bool calc_is_engine_recording(calc_session_t* session);
bool calc_is_input_empty(calc_session_t* session);

/// S10 Ratpack size gate (M4): sticky flag set when an exact rational exceeded
/// kMaxRationalDigits and was force-truncated to display precision. Engine-global
/// (shared across sessions). UI must surface it — never silently show an
/// approximation as exact. Clear explicitly when a new expression starts.
bool calc_precision_limited(void);
void calc_clear_precision_limited(void);
/// Current decimal separator as a Unicode code point.
uint32_t calc_decimal_separator(calc_session_t* session);
calc_error_t calc_set_precision(calc_session_t* session, int32_t precision);
calc_error_t calc_update_max_int_digits(calc_session_t* session);
calc_error_t calc_set_radix(calc_session_t* session, calc_radix_type_t radix_type);
/// Programmer-mode conversion of the current result. Returns a heap UTF-8
/// string (calc_string_free) or NULL on failure.
char* calc_result_for_radix(calc_session_t* session, uint32_t radix, int32_t precision, bool group_digits);

// ── Memory ─────────────────────────────────────────────────────────────────

calc_error_t calc_memory_store(calc_session_t* session);
calc_error_t calc_memory_recall(calc_session_t* session, uint32_t index);
calc_error_t calc_memory_add(calc_session_t* session, uint32_t index);
calc_error_t calc_memory_subtract(calc_session_t* session, uint32_t index);
calc_error_t calc_memory_clear(calc_session_t* session, uint32_t index);
calc_error_t calc_memory_clear_all(calc_session_t* session);

// ── History (current mode) ─────────────────────────────────────────────────

size_t calc_history_count(calc_session_t* session);
/// Fills expression/result with heap UTF-8 strings (calc_string_free both).
calc_error_t calc_history_entry(calc_session_t* session, size_t index, char** out_expression, char** out_result);
bool calc_history_remove(calc_session_t* session, uint32_t index);
calc_error_t calc_history_clear(calc_session_t* session);

// ── Expression token editing ───────────────────────────────────────────────

bool calc_is_operand_token(calc_session_t* session, uint32_t token_position);
/// Replaces an operand's text and replays the expression through the engine.
/// Returns false (and restores the previous expression) when the edit is invalid.
bool calc_update_operand(
    calc_session_t* session,
    uint32_t token_position,
    const char* utf8_text,
    bool scientific_mode,
    bool f_to_e_checked);

// ── Utilities ──────────────────────────────────────────────────────────────

void calc_string_free(char* s);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // CALC_C_API_H
