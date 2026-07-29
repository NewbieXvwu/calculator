// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "include/CalcManagerBridge.h"

#include <memory>
#include <string>

#include "CalcSession.h"

namespace
{
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

        _session = std::make_unique<MacCalc::CalcSession>(locale);

        __weak CalcManagerBridge* weakSelf = self;
        _session->SetDisplayCallback([weakSelf](const std::wstring& text, bool isError) {
            [weakSelf handleDisplayUpdate:ToNSString(text) isError:isError ? YES : NO];
        });
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
    [self sendCommand:CalcBridgeCommandDigit0 + digit];
}

- (void)reset
{
    _session->Reset();
}

- (void)setStandardMode
{
    _session->SetStandardMode();
}

- (void)setScientificMode
{
    _session->SetScientificMode();
}

@end
