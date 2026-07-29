// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

/// Mirror of CalculationManager::Command (src/CalcManager/Command.h).
/// Raw values must stay in sync with the C++ enum.
enum EngineCommand: Int {
    // Angle modes
    case deg = 321
    case rad = 322
    case grad = 323
    case degrees = 324
    case hyp = 325

    case null = 0

    case sign = 80
    case clear = 81
    case clearEntry = 82
    case backspace = 83
    case point = 84

    case and = 86
    case or = 87
    case xor = 88
    case lshf = 89
    case rshf = 90
    case divide = 91
    case multiply = 92
    case add = 93
    case subtract = 94
    case mod = 95
    case yroot = 96
    case power = 97

    case chop = 98
    case rol = 99
    case ror = 100
    case not = 101

    case sin = 102
    case cos = 103
    case tan = 104
    case sinh = 105
    case cosh = 106
    case tanh = 107
    case ln = 108
    case log = 109
    case sqrt = 110
    case sqr = 111
    case cube = 112
    case factorial = 113
    case reciprocal = 114
    case dms = 115
    case cubeRoot = 116
    case pow10 = 117
    case percent = 118

    case fe = 119
    case pi = 120
    case equals = 121

    case mClear = 122
    case recall = 123
    case store = 124
    case mPlus = 125
    case mMinus = 126

    case exp = 127
    case openParen = 128
    case closeParen = 129

    case digit0 = 130
    case digit1 = 131
    case digit2 = 132
    case digit3 = 133
    case digit4 = 134
    case digit5 = 135
    case digit6 = 136
    case digit7 = 137
    case digit8 = 138
    case digit9 = 139
    case digitA = 140
    case digitB = 141
    case digitC = 142
    case digitD = 143
    case digitE = 144
    case digitF = 145
    case inv = 146
    case setResult = 147

    case modeBasic = 200
    case modeScientific = 201

    case asin = 202
    case acos = 203
    case atan = 204
    case powE = 205
    case asinh = 206
    case acosh = 207
    case atanh = 208

    case modeProgrammer = 209

    case hex = 313
    case dec = 314
    case oct = 315
    case bin = 316
    case qword = 317
    case dword = 318
    case word = 319
    case byte = 320

    case sec = 400
    case asec = 401
    case csc = 402
    case acsc = 403
    case cot = 404
    case acot = 405
    case sech = 406
    case asech = 407
    case csch = 408
    case acsch = 409
    case coth = 410
    case acoth = 411

    case pow2 = 412
    case abs = 413
    case floor = 414
    case ceil = 415
    case rolc = 416
    case rorc = 417

    case logBaseY = 500
    case nand = 501
    case nor = 502
    case rshfl = 505

    case rand = 600
    case euler = 601

    static func digit(_ value: Int) -> EngineCommand {
        EngineCommand(rawValue: digit0.rawValue + value)!
    }
}
