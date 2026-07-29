// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Raw command IDs mirroring CalculationManager::Command (Command.h).
/// Digits 0-9 are 130-139; see Command.h for the full table.
typedef NS_ENUM(NSInteger, CalcBridgeCommand) {
    CalcBridgeCommandClear = 81,
    CalcBridgeCommandPoint = 84,
    CalcBridgeCommandDivide = 91,
    CalcBridgeCommandMultiply = 92,
    CalcBridgeCommandAdd = 93,
    CalcBridgeCommandSubtract = 94,
    CalcBridgeCommandEquals = 121,
    CalcBridgeCommandDigit0 = 130,
};

@interface CalcManagerBridge : NSObject

/// Latest primary display text pushed by the engine.
@property (nonatomic, readonly, copy) NSString *primaryDisplay;
@property (nonatomic, readonly) BOOL isInError;

/// Called on every primary display update.
@property (nonatomic, copy, nullable) void (^onDisplayChanged)(NSString *text, BOOL isError);

- (void)sendCommand:(NSInteger)command;
- (void)sendDigit:(NSInteger)digit;
- (void)reset;
- (void)setStandardMode;
- (void)setScientificMode;

@end

NS_ASSUME_NONNULL_END
