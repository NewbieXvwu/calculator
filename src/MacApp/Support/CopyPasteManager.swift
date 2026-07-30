// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// CopyPasteManager 完整移植（对照 src/CalcViewModel/Common/CopyPasteManager.cpp）：
// 按模式×进制×字长校验粘贴文本，非法输入整体拒绝（返回 nil，对应原版 "NoOp"）。
// 正则/长度/最大值规则与原版逐条对齐；差异仅在 API 形态（Optional 取代哨兵串）。

import Foundation

enum CopyPasteManager {
    enum PasteMode {
        case standard
        case scientific
        case programmer
        case converter
    }

    struct MaxOperandLengthAndValue: Equatable {
        var maxLength: Int
        var maxValue: UInt64
    }

    static let maxStandardOperandLength = 16
    static let maxScientificOperandLength = 32
    static let maxConverterInputLength = 16
    static let maxOperandCount = 100
    static let maxExponentLength = 4
    static let maxProgrammerBitLength = 64
    static let maxPasteableLength = 512

    // MARK: - 正则模式（逐字对照 C++，wspc 额外并入 \v，因 ICU \s 不含 0x0B）

    private static let wspc = "[\\s\\x{0B}\\x{85}]*"
    private static let wspcLParens = wspc + "[(]*" + wspc
    private static let wspcLParenSigned = wspc + "([-+]?[(])*" + wspc
    private static let wspcRParens = wspc + "[)]*" + wspc
    private static let signedDecFloat = "(?:[-+]?(?:\\d+(\\.\\d*)?|\\.\\d+))"
    private static let optionalENotation = "(?:e[+-]?\\d+)?"

    private static let hexProgrammerChars = "([a-f]|[A-F]|\\d)+((_|'|`)([a-f]|[A-F]|\\d)+)*"
    private static let decProgrammerChars = "\\d+((_|'|`)\\d+)*"
    private static let octProgrammerChars = "[0-7]+((_|'|`)[0-7]+)*"
    private static let binProgrammerChars = "[0-1]+((_|'|`)[0-1]+)*"
    private static let uIntSuffixes = "[uU]?[lL]{0,2}"

    private static func compile(_ pattern: String) -> NSRegularExpression {
        // 原版用 regex_match（整串匹配），以 \A...\z 锚定等价复刻。
        try! NSRegularExpression(pattern: "\\A(?:" + pattern + ")\\z")
    }

    private static let standardModePatterns = [compile(wspc + signedDecFloat + optionalENotation + wspc)]
    private static let scientificModePatterns = [
        compile("(" + wspc + "[-+]?)|(" + wspcLParenSigned + ")" + signedDecFloat + optionalENotation + wspcRParens)
    ]
    // 下标顺序对应 RadixKind: hex=0, dec=1, oct=2, bin=3
    private static let programmerModePatterns: [[NSRegularExpression]] = [
        [
            compile(wspcLParens + "(0[xX])?" + hexProgrammerChars + uIntSuffixes + wspcRParens),
            compile(wspcLParens + hexProgrammerChars + "[hH]?" + wspcRParens),
        ],
        [
            compile(wspcLParens + "[-+]?" + decProgrammerChars + "[lL]{0,2}" + wspcRParens),
            compile(wspcLParens + "(0[nN])?" + decProgrammerChars + uIntSuffixes + wspcRParens),
        ],
        [compile(wspcLParens + "(0[otOT])?" + octProgrammerChars + uIntSuffixes + wspcRParens)],
        [
            compile(wspcLParens + "(0[byBY])?" + binProgrammerChars + uIntSuffixes + wspcRParens),
            compile(wspcLParens + binProgrammerChars + "[bB]?" + wspcRParens),
        ],
    ]
    private static let unitConverterPatterns = [compile(wspc + signedDecFloat + wspc)]

    private static func fullMatch(_ regex: NSRegularExpression, _ s: String) -> Bool {
        let range = NSRange(s.startIndex..., in: s)
        return regex.firstMatch(in: s, range: range) != nil
    }

    // MARK: - 校验入口（ValidatePasteExpression）

    /// 合法返回原始粘贴文本，非法返回 nil（对应原版 "NoOp"）。
    static func validate(
        _ pastedText: String,
        mode: PasteMode,
        radix: RadixKind = .dec,
        wordSize: WordSize = .qword
    ) -> String? {
        if pastedText.utf16.count > maxPasteableLength {
            return nil
        }

        var pasteExpression = removeUnwantedChars(pastedText)

        if pasteExpression.hasSuffix("=") {
            pasteExpression.removeLast()
        }

        var operands = extractOperands(pasteExpression, mode: mode)
        if operands.isEmpty {
            return nil
        }

        if mode == .converter {
            operands = [pasteExpression]
        }

        if !expressionRegExMatch(operands, mode: mode, radix: radix, wordSize: wordSize) {
            return nil
        }

        return pastedText
    }

    // MARK: - ExtractOperands

    static func extractOperands(_ pasteExpression: String, mode: PasteMode) -> [String] {
        var operands: [String] = []
        let chars = Array(pasteExpression)
        var lastIndex = 0
        var haveOperator = false
        var startExpCounting = false
        var startOfExpression = true
        var isPreviousOpenParen = false
        var isPreviousOperator = false

        let validCharacterSet: Set<Character>
        switch mode {
        case .standard:
            validCharacterSet = Set("0123456789+-.e*/")
        case .scientific:
            validCharacterSet = Set("0123456789+-.e*/()^%")
        case .programmer:
            validCharacterSet = Set("0123456789+-.e*/()%abcdfABCDEF")
        case .converter:
            validCharacterSet = Set("0123456789+-.e")
        }

        var expLength = 0
        for (i, currentChar) in chars.enumerated() {
            if !validCharacterSet.contains(currentChar) {
                continue
            }

            if operands.count >= maxOperandCount {
                return []
            }

            if currentChar >= "0", currentChar <= "9" {
                if startExpCounting {
                    expLength += 1
                    // 禁止 1e+12345 被截断成 1e+1234 粘入，指数最多 4 位。
                    if expLength > maxExponentLength {
                        return []
                    }
                }
                isPreviousOperator = false
            } else if currentChar == "e" {
                if mode != .programmer {
                    startExpCounting = true
                }
                isPreviousOperator = false
            } else if currentChar == "+" || currentChar == "-" || currentChar == "*"
                || currentChar == "/" || currentChar == "^" || currentChar == "%" {
                if currentChar == "+" || currentChar == "-" {
                    // 符号位（正负号）不拆分操作数；continue 跳过尾部状态更新与 C++ 一致。
                    if isPreviousOpenParen || startOfExpression || isPreviousOperator
                        || (mode != .programmer && !(i != 0 && chars[i - 1] != "e")) {
                        isPreviousOperator = false
                        continue
                    }
                }

                startExpCounting = false
                expLength = 0
                haveOperator = true
                isPreviousOperator = true
                operands.append(String(chars[lastIndex..<i]))
                lastIndex = i + 1
            } else {
                isPreviousOperator = false
            }

            isPreviousOpenParen = (currentChar == "(")
            startOfExpression = false
        }

        if !haveOperator {
            operands = [pasteExpression]
        } else {
            operands.append(String(chars[lastIndex...]))
        }

        return operands
    }

    // MARK: - ExpressionRegExMatch

    static func expressionRegExMatch(
        _ operands: [String],
        mode: PasteMode,
        radix: RadixKind = .dec,
        wordSize: WordSize = .qword
    ) -> Bool {
        if operands.isEmpty {
            return false
        }

        let patterns: [NSRegularExpression]
        switch mode {
        case .standard:
            patterns = standardModePatterns
        case .scientific:
            patterns = scientificModePatterns
        case .programmer:
            patterns = programmerModePatterns[radix.rawValue]
        case .converter:
            patterns = unitConverterPatterns
        }

        let maxLengthAndValue = maxOperandLengthAndValue(mode: mode, radix: radix, wordSize: wordSize)
        var expMatched = true

        for operand in operands {
            var operandMatched = false
            for pattern in patterns {
                operandMatched = operandMatched || fullMatch(pattern, operand)
            }

            if operandMatched {
                let isNegativeValue = operand.hasPrefix("-")
                let operandValue = sanitizeOperand(operand)

                if operandLength(operandValue, mode: mode, radix: radix) > maxLengthAndValue.maxLength {
                    expMatched = false
                    break
                }

                if maxLengthAndValue.maxValue != 0 {
                    guard let operandAsULL = tryOperandToULL(operandValue, radix: radix) else {
                        expMatched = false
                        break
                    }

                    // 仅超出 1 且为负数时是有符号最小值边界（如 -32768）。
                    let isOverflow = operandAsULL > maxLengthAndValue.maxValue
                    let isMaxNegativeValue = operandAsULL &- 1 == maxLengthAndValue.maxValue
                    if isOverflow && !(isNegativeValue && isMaxNegativeValue) {
                        expMatched = false
                        break
                    }
                }
            }

            expMatched = expMatched && operandMatched
        }

        return expMatched
    }

    // MARK: - GetMaxOperandLengthAndValue

    static func maxOperandLengthAndValue(mode: PasteMode, radix: RadixKind, wordSize: WordSize) -> MaxOperandLengthAndValue {
        switch mode {
        case .standard:
            return MaxOperandLengthAndValue(maxLength: maxStandardOperandLength, maxValue: 0)
        case .scientific:
            return MaxOperandLengthAndValue(maxLength: maxScientificOperandLength, maxValue: 0)
        case .converter:
            return MaxOperandLengthAndValue(maxLength: maxConverterInputLength, maxValue: 0)
        case .programmer:
            let bitLength = wordSize.bitCount
            let bitsPerDigit: Double
            switch radix {
            case .bin: bitsPerDigit = 1
            case .oct: bitsPerDigit = 3
            case .dec: bitsPerDigit = log2(10)
            case .hex: bitsPerDigit = 4
            }
            let signBit = (radix == .dec) ? 1 : 0
            let maxLength = Int(ceil(Double(bitLength - signBit) / bitsPerDigit))
            let maxValue = UInt64.max >> UInt64(maxProgrammerBitLength - (bitLength - signBit))
            return MaxOperandLengthAndValue(maxLength: maxLength, maxValue: maxValue)
        }
    }

    // MARK: - SanitizeOperand / TryOperandToULL

    static func sanitizeOperand(_ operand: String) -> String {
        let unwanted: Set<Character> = ["'", "_", "`", "(", ")", "-", "+"]
        return String(operand.filter { !unwanted.contains($0) })
    }

    /// stoull 语义：跳前导空白，可选 + 号，base16 可带 0x 前缀，
    /// 解析到首个非法字符为止；溢出/无有效数字返回 nil。
    static func tryOperandToULL(_ operand: String, radix: RadixKind) -> UInt64? {
        guard !operand.isEmpty, !operand.hasPrefix("-") else {
            return nil
        }

        let base: UInt64
        switch radix {
        case .hex: base = 16
        case .oct: base = 8
        case .bin: base = 2
        case .dec: base = 10
        }

        let chars = Array(operand)
        var idx = 0
        while idx < chars.count, chars[idx].isWhitespace {
            idx += 1
        }
        if idx < chars.count, chars[idx] == "+" {
            idx += 1
        }
        if base == 16, idx + 2 < chars.count, chars[idx] == "0",
           chars[idx + 1] == "x" || chars[idx + 1] == "X",
           chars[idx + 2].isHexDigit {
            idx += 2
        }

        var value: UInt64 = 0
        var hasDigits = false
        while idx < chars.count {
            guard let digit = chars[idx].hexDigitValue, UInt64(digit) < base else {
                break
            }
            let (multiplied, overflow1) = value.multipliedReportingOverflow(by: base)
            if overflow1 { return nil }
            let (added, overflow2) = multiplied.addingReportingOverflow(UInt64(digit))
            if overflow2 { return nil }
            value = added
            hasDigits = true
            idx += 1
        }

        return hasDigits ? value : nil
    }

    // MARK: - OperandLength

    static func operandLength(_ operand: String, mode: PasteMode, radix: RadixKind) -> Int {
        switch mode {
        case .converter:
            return operand.count
        case .standard, .scientific:
            return standardScientificOperandLength(operand)
        case .programmer:
            return programmerOperandLength(operand, radix: radix)
        }
    }

    static func standardScientificOperandLength(_ operand: String) -> Int {
        let chars = Array(operand)
        let hasDecimal = chars.contains(".")
        var length = chars.count

        if hasDecimal, length >= 2 {
            if chars[0] == "0", chars[1] == "." {
                length -= 2
            } else {
                length -= 1
            }
        }

        if let exponentPos = chars.firstIndex(of: "e") {
            length -= chars.count - exponentPos
        }

        return length
    }

    static func programmerOperandLength(_ operand: String, radix: RadixKind) -> Int {
        var prefixes: [String]
        var suffixes: [String]
        switch radix {
        case .bin:
            prefixes = ["0B", "0Y"]
            suffixes = ["B"]
        case .dec:
            prefixes = ["-", "0N"]
            suffixes = []
        case .oct:
            prefixes = ["0T", "0O"]
            suffixes = []
        case .hex:
            prefixes = ["0X"]
            suffixes = ["H"]
        }

        suffixes.append(contentsOf: ["ULL", "UL", "LL", "U", "L"])

        let operandUpper = operand.uppercased()
        var len = operandUpper.count

        // 先查后缀再查前缀，使 "0b" 判长为 1（值 0）而非 0（无值）。
        for suffix in suffixes {
            if len < suffix.count { continue }
            if operandUpper.hasSuffix(suffix) {
                len -= suffix.count
                break
            }
        }

        for prefix in prefixes {
            if len < prefix.count { continue }
            if operandUpper.hasPrefix(prefix) {
                len -= prefix.count
                break
            }
        }

        return len
    }

    // MARK: - RemoveUnwantedCharsFromString

    /// 去除空格、逗号、双引号、常见货币前缀符号、方向控制符与不间断空格（对照原版字符表）。
    static func removeUnwantedChars(_ input: String) -> String {
        let unwantedScalars: Set<UInt32> = [
            32, 44, 34, // 空格、逗号、双引号
            165, 164, 8373, 36, 8353, 8361, 8362, 8358, 8377, 163, 8364, // ¥ ¤ ₵ $ ₡ ₩ ₪ ₦ ₹ £ €
            8234, 8235, 8236, 8237, // 双向文本控制符
            160, // 不间断空格
        ]
        return String(input.unicodeScalars.filter { !unwantedScalars.contains($0.value) }.map(Character.init))
    }
}
