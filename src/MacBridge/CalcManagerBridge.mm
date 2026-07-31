// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// CalcManagerBridge.mm — ObjC 门面，委托给 calc_c_api 的 C ABI（不再直接持有
// C++ CalcSession）。这样 calc_c_api 成为 CalcSession 的唯一包装，跨平台契约
// 由 macOS 实际消费验证；本文件退化为 UTF-8 char* ⇄ NSString 与回调转发。

#import "include/CalcManagerBridge.h"

#import "calc_c_api.h"

namespace
{
    NSString* ToNSString(const char* utf8)
    {
        if (utf8 == nullptr)
        {
            return @"";
        }
        return [NSString stringWithUTF8String:utf8] ?: @"";
    }
}

@implementation CalcBridgeToken

- (instancetype)initWithText:(NSString*)text commandIndex:(NSInteger)commandIndex
{
    self = [super init];
    if (self)
    {
        _text = [text copy];
        _commandIndex = commandIndex;
    }
    return self;
}

@end

@implementation CalcBridgeHistoryEntry

- (instancetype)initWithExpression:(NSString*)expression result:(NSString*)result
{
    self = [super init];
    if (self)
    {
        _expression = [expression copy];
        _result = [result copy];
    }
    return self;
}

@end

@interface CalcManagerBridge ()
- (void)handleDisplayUpdate:(NSString*)text isError:(BOOL)isError;
- (void)handleIsInError:(BOOL)isInError;
@end

namespace
{
    // C 回调 thunk：user_data 是未持有的 CalcManagerBridge*（session 由 bridge
    // 拥有，回调仅在 bridge 存活期间触发，故无需强引用，也不形成保留环）。
    CalcManagerBridge* BridgeFrom(void* userData)
    {
        return (__bridge CalcManagerBridge*)userData;
    }

    void OnPrimaryDisplay(void* userData, const char* text, bool isError)
    {
        [BridgeFrom(userData) handleDisplayUpdate:ToNSString(text) isError:isError ? YES : NO];
    }

    void OnIsInError(void* userData, bool isInError)
    {
        [BridgeFrom(userData) handleIsInError:isInError ? YES : NO];
    }

    void OnExpressionTokens(void* userData, const calc_token_t* tokens, size_t count)
    {
        CalcManagerBridge* bridge = BridgeFrom(userData);
        if (bridge.onExpressionChanged)
        {
            NSMutableArray<CalcBridgeToken*>* result = [NSMutableArray arrayWithCapacity:count];
            for (size_t i = 0; i < count; ++i)
            {
                [result addObject:[[CalcBridgeToken alloc] initWithText:ToNSString(tokens[i].text)
                                                          commandIndex:tokens[i].command_index]];
            }
            bridge.onExpressionChanged(result);
        }
    }

    void OnParenthesisCount(void* userData, uint32_t count)
    {
        CalcManagerBridge* bridge = BridgeFrom(userData);
        if (bridge.onParenthesisCountChanged)
        {
            bridge.onParenthesisCountChanged(count);
        }
    }

    void OnNoRightParenAdded(void* userData)
    {
        CalcManagerBridge* bridge = BridgeFrom(userData);
        if (bridge.onNoRightParenAdded)
        {
            bridge.onNoRightParenAdded();
        }
    }

    void OnMaxDigitsReached(void* userData)
    {
        CalcManagerBridge* bridge = BridgeFrom(userData);
        if (bridge.onMaxDigitsReached)
        {
            bridge.onMaxDigitsReached();
        }
    }

    void OnBinaryOperatorReceived(void* userData)
    {
        CalcManagerBridge* bridge = BridgeFrom(userData);
        if (bridge.onBinaryOperatorReceived)
        {
            bridge.onBinaryOperatorReceived();
        }
    }

    void OnHistoryItemAdded(void* userData, uint32_t index)
    {
        CalcManagerBridge* bridge = BridgeFrom(userData);
        if (bridge.onHistoryItemAdded)
        {
            bridge.onHistoryItemAdded(index);
        }
    }

    void OnMemorizedNumbers(void* userData, const char* const* values, size_t count)
    {
        CalcManagerBridge* bridge = BridgeFrom(userData);
        if (bridge.onMemoryChanged)
        {
            NSMutableArray<NSString*>* result = [NSMutableArray arrayWithCapacity:count];
            for (size_t i = 0; i < count; ++i)
            {
                [result addObject:ToNSString(values[i])];
            }
            bridge.onMemoryChanged(result);
        }
    }

    void OnMemoryItemChanged(void* userData, uint32_t index)
    {
        CalcManagerBridge* bridge = BridgeFrom(userData);
        if (bridge.onMemoryItemChanged)
        {
            bridge.onMemoryItemChanged(index);
        }
    }

    void OnInputChanged(void* userData)
    {
        CalcManagerBridge* bridge = BridgeFrom(userData);
        if (bridge.onInputChanged)
        {
            bridge.onInputChanged();
        }
    }
}

@implementation CalcManagerBridge
{
    calc_session_t* _session;
    NSString* _primaryDisplay;
    BOOL _isInError;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _primaryDisplay = @"0";

        NSLocale* currentLocale = NSLocale.currentLocale;
        NSString* decimal = currentLocale.decimalSeparator ?: @".";
        NSString* thousand = currentLocale.groupingSeparator ?: @",";

        // S8：分组模式从结构推导，不再硬编码 "3;0"。
        // 只读 groupingSize 会破坏印度拉克/克若尔制（3;2;0），必须连读 secondary。
        NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = currentLocale;
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        calc_grouping_t grouping = {};
        if (formatter.usesGroupingSeparator && formatter.groupingSize > 0)
        {
            grouping.primary = static_cast<int32_t>(formatter.groupingSize);
            grouping.secondary = static_cast<int32_t>(formatter.secondaryGroupingSize);
        }
        else
        {
            grouping.primary = 0;
        }
        char groupingBuffer[32];
        calc_grouping_format(&grouping, groupingBuffer, sizeof(groupingBuffer));

        calc_locale_t locale = {};
        locale.decimal_separator = decimal.UTF8String;
        locale.thousand_separator = thousand.UTF8String;
        locale.grouping = groupingBuffer;

        _session = calc_session_create(&locale);

        calc_callbacks_t callbacks = {};
        callbacks.user_data = (__bridge void*)self;
        callbacks.on_primary_display = OnPrimaryDisplay;
        callbacks.on_is_in_error = OnIsInError;
        callbacks.on_expression_tokens = OnExpressionTokens;
        callbacks.on_parenthesis_count = OnParenthesisCount;
        callbacks.on_no_right_paren_added = OnNoRightParenAdded;
        callbacks.on_max_digits_reached = OnMaxDigitsReached;
        callbacks.on_binary_operator_received = OnBinaryOperatorReceived;
        callbacks.on_history_item_added = OnHistoryItemAdded;
        callbacks.on_memorized_numbers = OnMemorizedNumbers;
        callbacks.on_memory_item_changed = OnMemoryItemChanged;
        callbacks.on_input_changed = OnInputChanged;
        calc_session_set_callbacks(_session, &callbacks);
    }
    return self;
}

- (void)dealloc
{
    calc_session_destroy(_session);
}

- (NSString*)primaryDisplay
{
    return _primaryDisplay;
}

- (BOOL)isInError
{
    return _isInError;
}

- (void)handleDisplayUpdate:(NSString*)text isError:(BOOL)isError
{
    _primaryDisplay = [text copy];
    _isInError = isError;
    if (self.onDisplayChanged)
    {
        self.onDisplayChanged(_primaryDisplay, isError);
    }
}

- (void)handleIsInError:(BOOL)isInError
{
    _isInError = isInError;
    if (self.onIsInErrorChanged)
    {
        self.onIsInErrorChanged(isInError);
    }
}

- (void)sendCommand:(NSInteger)command
{
    calc_send_command(_session, static_cast<int32_t>(command));
}

- (void)sendDigit:(NSInteger)digit
{
    calc_send_digit(_session, static_cast<int32_t>(digit));
}

- (void)displayPasteError
{
    calc_display_paste_error(_session);
}

- (void)reset
{
    calc_reset(_session, true);
}

- (void)resetWithClearMemory:(BOOL)clearMemory
{
    calc_reset(_session, clearMemory == YES);
}

- (void)setStandardMode
{
    calc_set_mode(_session, CALC_MODE_STANDARD);
}

- (void)setScientificMode
{
    calc_set_mode(_session, CALC_MODE_SCIENTIFIC);
}

- (void)setProgrammerMode
{
    calc_set_mode(_session, CALC_MODE_PROGRAMMER);
}

- (BOOL)isEngineRecording
{
    return calc_is_engine_recording(_session) ? YES : NO;
}

- (BOOL)isInputEmpty
{
    return calc_is_input_empty(_session) ? YES : NO;
}

- (BOOL)precisionLimited
{
    return calc_precision_limited() ? YES : NO;
}

- (void)clearPrecisionLimited
{
    calc_clear_precision_limited();
}

- (NSString*)decimalSeparator
{
    uint32_t codepoint = calc_decimal_separator(_session);
    return [[NSString alloc] initWithBytes:&codepoint
                                    length:sizeof(codepoint)
                                  encoding:NSUTF32LittleEndianStringEncoding]
        ?: @".";
}

- (void)setPrecision:(NSInteger)precision
{
    calc_set_precision(_session, static_cast<int32_t>(precision));
}

- (void)updateMaxIntDigits
{
    calc_update_max_int_digits(_session);
}

- (void)setRadix:(NSInteger)radixType
{
    calc_set_radix(_session, static_cast<calc_radix_type_t>(radixType));
}

- (NSString*)resultForRadix:(NSInteger)radix precision:(NSInteger)precision groupDigits:(BOOL)groupDigits
{
    char* result = calc_result_for_radix(_session,
                                         static_cast<uint32_t>(radix),
                                         static_cast<int32_t>(precision),
                                         groupDigits == YES);
    NSString* value = ToNSString(result);
    calc_string_free(result);
    return value;
}

- (void)memorizeNumber
{
    calc_memory_store(_session);
}

- (void)memoryLoad:(NSUInteger)index
{
    calc_memory_recall(_session, static_cast<uint32_t>(index));
}

- (void)memoryAdd:(NSUInteger)index
{
    calc_memory_add(_session, static_cast<uint32_t>(index));
}

- (void)memorySubtract:(NSUInteger)index
{
    calc_memory_subtract(_session, static_cast<uint32_t>(index));
}

- (void)memoryClear:(NSUInteger)index
{
    calc_memory_clear(_session, static_cast<uint32_t>(index));
}

- (void)memoryClearAll
{
    calc_memory_clear_all(_session);
}

- (NSArray<CalcBridgeHistoryEntry*>*)historyEntries
{
    size_t count = calc_history_count(_session);
    NSMutableArray<CalcBridgeHistoryEntry*>* result = [NSMutableArray arrayWithCapacity:count];
    for (size_t i = 0; i < count; ++i)
    {
        char* expression = nullptr;
        char* entryResult = nullptr;
        if (calc_history_entry(_session, i, &expression, &entryResult) == CALC_OK)
        {
            [result addObject:[[CalcBridgeHistoryEntry alloc] initWithExpression:ToNSString(expression)
                                                                         result:ToNSString(entryResult)]];
        }
        calc_string_free(expression);
        calc_string_free(entryResult);
    }
    return result;
}

- (BOOL)removeHistoryItem:(NSUInteger)index
{
    return calc_history_remove(_session, static_cast<uint32_t>(index)) ? YES : NO;
}

- (void)clearHistory
{
    calc_history_clear(_session);
}

- (BOOL)isOperandTokenAt:(NSUInteger)tokenPosition
{
    return calc_is_operand_token(_session, static_cast<uint32_t>(tokenPosition)) ? YES : NO;
}

- (BOOL)updateOperandAtToken:(NSUInteger)tokenPosition
                        text:(NSString*)text
                  scientific:(BOOL)scientific
                 fToEChecked:(BOOL)fToEChecked
{
    return calc_update_operand(_session,
                               static_cast<uint32_t>(tokenPosition),
                               text.UTF8String,
                               scientific == YES,
                               fToEChecked == YES)
        ? YES
        : NO;
}

@end
