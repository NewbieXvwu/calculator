// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "include/CalcManagerBridge.h"

#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "CalcSession.h"

namespace
{
    constexpr int kCommandDigit0 = 130; // CalculationManager::Command::Command0

    NSString* ToNSString(const std::wstring& text)
    {
        return [[NSString alloc] initWithBytes:text.data()
                                        length:text.size() * sizeof(wchar_t)
                                      encoding:NSUTF32LittleEndianStringEncoding]
                   ?: @"";
    }

    std::wstring ToWString(NSString* text)
    {
        NSData* data = [text dataUsingEncoding:NSUTF32LittleEndianStringEncoding];
        return std::wstring(static_cast<const wchar_t*>(data.bytes), data.length / sizeof(wchar_t));
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

@implementation CalcManagerBridge
{
    std::unique_ptr<MacCalc::CalcSession> _session;
    NSString* _primaryDisplay;
    BOOL _isInError;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _primaryDisplay = @"0";

        MacCalc::LocaleStrings locale;
        NSLocale* currentLocale = NSLocale.currentLocale;
        locale.decimalSeparator = ToWString(currentLocale.decimalSeparator ?: @".");
        locale.thousandSeparator = ToWString(currentLocale.groupingSeparator ?: @",");

        // S8：分组模式从结构推导，不再硬编码 "3;0"。
        // 只读 groupingSize 会破坏印度拉克/克若尔制（3;2;0），必须连读 secondary。
        NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = currentLocale;
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        MacCalc::Grouping grouping;
        if (formatter.usesGroupingSeparator && formatter.groupingSize > 0)
        {
            grouping.primary = static_cast<int>(formatter.groupingSize);
            grouping.secondary = static_cast<int>(formatter.secondaryGroupingSize);
        }
        else
        {
            grouping.primary = 0;
        }
        locale.grouping = grouping.EngineString();

        _session = std::make_unique<MacCalc::CalcSession>(locale);

        __weak CalcManagerBridge* weakSelf = self;
        MacCalc::SessionCallbacks callbacks;
        callbacks.onPrimaryDisplay = [weakSelf](const std::wstring& text, bool isError) {
            [weakSelf handleDisplayUpdate:ToNSString(text) isError:isError ? YES : NO];
        };
        callbacks.onIsInError = [weakSelf](bool isInError) {
            CalcManagerBridge* self = weakSelf;
            if (self)
            {
                self->_isInError = isInError ? YES : NO;
            }
            if (self.onIsInErrorChanged)
            {
                self.onIsInErrorChanged(isInError ? YES : NO);
            }
        };
        callbacks.onExpressionTokens = [weakSelf](const std::vector<std::pair<std::wstring, int>>& tokens) {
            CalcManagerBridge* self = weakSelf;
            if (self.onExpressionChanged)
            {
                NSMutableArray<CalcBridgeToken*>* result = [NSMutableArray arrayWithCapacity:tokens.size()];
                for (const auto& [text, commandIndex] : tokens)
                {
                    [result addObject:[[CalcBridgeToken alloc] initWithText:ToNSString(text) commandIndex:commandIndex]];
                }
                self.onExpressionChanged(result);
            }
        };
        callbacks.onParenthesisCount = [weakSelf](unsigned int count) {
            CalcManagerBridge* self = weakSelf;
            if (self.onParenthesisCountChanged)
            {
                self.onParenthesisCountChanged(count);
            }
        };
        callbacks.onNoRightParenAdded = [weakSelf]() {
            CalcManagerBridge* self = weakSelf;
            if (self.onNoRightParenAdded)
            {
                self.onNoRightParenAdded();
            }
        };
        callbacks.onMaxDigitsReached = [weakSelf]() {
            CalcManagerBridge* self = weakSelf;
            if (self.onMaxDigitsReached)
            {
                self.onMaxDigitsReached();
            }
        };
        callbacks.onBinaryOperatorReceived = [weakSelf]() {
            CalcManagerBridge* self = weakSelf;
            if (self.onBinaryOperatorReceived)
            {
                self.onBinaryOperatorReceived();
            }
        };
        callbacks.onHistoryItemAdded = [weakSelf](unsigned int index) {
            CalcManagerBridge* self = weakSelf;
            if (self.onHistoryItemAdded)
            {
                self.onHistoryItemAdded(index);
            }
        };
        callbacks.onMemorizedNumbers = [weakSelf](const std::vector<std::wstring>& values) {
            CalcManagerBridge* self = weakSelf;
            if (self.onMemoryChanged)
            {
                NSMutableArray<NSString*>* result = [NSMutableArray arrayWithCapacity:values.size()];
                for (const auto& value : values)
                {
                    [result addObject:ToNSString(value)];
                }
                self.onMemoryChanged(result);
            }
        };
        callbacks.onMemoryItemChanged = [weakSelf](unsigned int index) {
            CalcManagerBridge* self = weakSelf;
            if (self.onMemoryItemChanged)
            {
                self.onMemoryItemChanged(index);
            }
        };
        callbacks.onInputChanged = [weakSelf]() {
            CalcManagerBridge* self = weakSelf;
            if (self.onInputChanged)
            {
                self.onInputChanged();
            }
        };
        _session->SetCallbacks(std::move(callbacks));
    }
    return self;
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

- (void)sendCommand:(NSInteger)command
{
    _session->SendCommand(static_cast<int>(command));
}

- (void)sendDigit:(NSInteger)digit
{
    [self sendCommand:kCommandDigit0 + digit];
}

- (void)displayPasteError
{
    _session->DisplayPasteError();
}

- (void)reset
{
    _session->Reset(true);
}

- (void)resetWithClearMemory:(BOOL)clearMemory
{
    _session->Reset(clearMemory == YES);
}

- (void)setStandardMode
{
    _session->SetStandardMode();
}

- (void)setScientificMode
{
    _session->SetScientificMode();
}

- (void)setProgrammerMode
{
    _session->SetProgrammerMode();
}

- (BOOL)isEngineRecording
{
    return _session->IsEngineRecording() ? YES : NO;
}

- (BOOL)isInputEmpty
{
    return _session->IsInputEmpty() ? YES : NO;
}

- (BOOL)precisionLimited
{
    return MacCalc::CalcSession::PrecisionLimited() ? YES : NO;
}

- (void)clearPrecisionLimited
{
    MacCalc::CalcSession::ClearPrecisionLimited();
}

- (NSString*)decimalSeparator
{
    std::wstring separator(1, _session->DecimalSeparator());
    return ToNSString(separator);
}

- (void)setPrecision:(NSInteger)precision
{
    _session->SetPrecision(static_cast<int>(precision));
}

- (void)updateMaxIntDigits
{
    _session->UpdateMaxIntDigits();
}

- (void)setRadix:(NSInteger)radixType
{
    _session->SetRadix(static_cast<int>(radixType));
}

- (NSString*)resultForRadix:(NSInteger)radix precision:(NSInteger)precision groupDigits:(BOOL)groupDigits
{
    return ToNSString(_session->GetResultForRadix(static_cast<unsigned int>(radix), static_cast<int>(precision), groupDigits == YES));
}

- (void)memorizeNumber
{
    _session->MemorizeNumber();
}

- (void)memoryLoad:(NSUInteger)index
{
    _session->MemorizedNumberLoad(static_cast<unsigned int>(index));
}

- (void)memoryAdd:(NSUInteger)index
{
    _session->MemorizedNumberAdd(static_cast<unsigned int>(index));
}

- (void)memorySubtract:(NSUInteger)index
{
    _session->MemorizedNumberSubtract(static_cast<unsigned int>(index));
}

- (void)memoryClear:(NSUInteger)index
{
    _session->MemorizedNumberClear(static_cast<unsigned int>(index));
}

- (void)memoryClearAll
{
    _session->MemorizedNumberClearAll();
}

- (NSArray<CalcBridgeHistoryEntry*>*)historyEntries
{
    auto entries = _session->GetHistoryEntries();
    NSMutableArray<CalcBridgeHistoryEntry*>* result = [NSMutableArray arrayWithCapacity:entries.size()];
    for (const auto& entry : entries)
    {
        [result addObject:[[CalcBridgeHistoryEntry alloc] initWithExpression:ToNSString(entry.expression) result:ToNSString(entry.result)]];
    }
    return result;
}

- (BOOL)removeHistoryItem:(NSUInteger)index
{
    return _session->RemoveHistoryItem(static_cast<unsigned int>(index)) ? YES : NO;
}

- (void)clearHistory
{
    _session->ClearHistory();
}

- (BOOL)isOperandTokenAt:(NSUInteger)tokenPosition
{
    return _session->IsTokenEditableOperand(static_cast<unsigned int>(tokenPosition)) ? YES : NO;
}

- (BOOL)updateOperandAtToken:(NSUInteger)tokenPosition
                        text:(NSString*)text
                  scientific:(BOOL)scientific
                 fToEChecked:(BOOL)fToEChecked
{
    return _session->UpdateOperandAtToken(static_cast<unsigned int>(tokenPosition), ToWString(text), scientific == YES, fToEChecked == YES) ? YES : NO;
}

@end
