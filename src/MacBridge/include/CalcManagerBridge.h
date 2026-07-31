// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#import <Foundation/Foundation.h>

// SPM 以本文件为伞头（与 target 同名）；C ABI 门面须由此导出给 Swift。
#import "calc_c_api.h"

NS_ASSUME_NONNULL_BEGIN

/// One expression-display token. commandIndex >= 0 means the token is editable
/// (it maps into the engine command list); -1 means static text.
@interface CalcBridgeToken : NSObject
@property (nonatomic, readonly, copy) NSString *text;
@property (nonatomic, readonly) NSInteger commandIndex;
- (instancetype)initWithText:(NSString *)text commandIndex:(NSInteger)commandIndex;
@end

@interface CalcBridgeHistoryEntry : NSObject
@property (nonatomic, readonly, copy) NSString *expression;
@property (nonatomic, readonly, copy) NSString *result;
- (instancetype)initWithExpression:(NSString *)expression result:(NSString *)result;
@end

/// Thin ObjC wrapper over the C++ CalcSession facade. Command IDs mirror
/// CalculationManager::Command (Command.h); Swift keeps its own typed enum.
@interface CalcManagerBridge : NSObject

@property (nonatomic, readonly, copy) NSString *primaryDisplay;
@property (nonatomic, readonly) BOOL isInError;

@property (nonatomic, copy, nullable) void (^onDisplayChanged)(NSString *text, BOOL isError);
@property (nonatomic, copy, nullable) void (^onIsInErrorChanged)(BOOL isInError);
@property (nonatomic, copy, nullable) void (^onExpressionChanged)(NSArray<CalcBridgeToken *> *tokens);
@property (nonatomic, copy, nullable) void (^onParenthesisCountChanged)(NSUInteger count);
@property (nonatomic, copy, nullable) void (^onNoRightParenAdded)(void);
@property (nonatomic, copy, nullable) void (^onMaxDigitsReached)(void);
@property (nonatomic, copy, nullable) void (^onBinaryOperatorReceived)(void);
@property (nonatomic, copy, nullable) void (^onHistoryItemAdded)(NSUInteger index);
@property (nonatomic, copy, nullable) void (^onMemoryChanged)(NSArray<NSString *> *values);
@property (nonatomic, copy, nullable) void (^onMemoryItemChanged)(NSUInteger index);
@property (nonatomic, copy, nullable) void (^onInputChanged)(void);

- (void)sendCommand:(NSInteger)command;
- (void)sendDigit:(NSInteger)digit;
/// Shows the engine's "Invalid input" error (mirrors CalculatorManager::DisplayPasteError).
- (void)displayPasteError;
- (void)reset;
- (void)resetWithClearMemory:(BOOL)clearMemory;
- (void)setStandardMode;
- (void)setScientificMode;
- (void)setProgrammerMode;

- (BOOL)isEngineRecording;
- (BOOL)isInputEmpty;
- (NSString *)decimalSeparator;
- (void)setPrecision:(NSInteger)precision;
- (void)updateMaxIntDigits;
/// radixType: 0=Hex 1=Decimal 2=Octal 3=Binary
- (void)setRadix:(NSInteger)radixType;
- (NSString *)resultForRadix:(NSInteger)radix precision:(NSInteger)precision groupDigits:(BOOL)groupDigits;

- (void)memorizeNumber;
- (void)memoryLoad:(NSUInteger)index;
- (void)memoryAdd:(NSUInteger)index;
- (void)memorySubtract:(NSUInteger)index;
- (void)memoryClear:(NSUInteger)index;
- (void)memoryClearAll;

- (NSArray<CalcBridgeHistoryEntry *> *)historyEntries;
- (BOOL)removeHistoryItem:(NSUInteger)index;
- (void)clearHistory;

/// YES when the token at this position maps to an editable operand command.
- (BOOL)isOperandTokenAt:(NSUInteger)tokenPosition;
/// Replaces the operand text and replays the whole expression through the engine.
/// Returns NO (and restores the previous expression) when the edit is invalid.
- (BOOL)updateOperandAtToken:(NSUInteger)tokenPosition
                        text:(NSString *)text
                  scientific:(BOOL)scientific
                fToEChecked:(BOOL)fToEChecked;

@end

NS_ASSUME_NONNULL_END
