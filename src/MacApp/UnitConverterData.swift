// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 静态单位换算数据表，移植自 src/CalcViewModel/DataLoaders/UnitConverterDataLoader.cpp
// 的 GetConversionData / GetExplicitConversionData。
//
// 换算原理与原版一致：
//   - 普通类别：每个单位有一个相对「基准单位」的换算因子 factor（基准单位 factor == 1）。
//     value(from) → value(to) == value * (fromFactor / toFactor)。
//   - 温度：非线性（含偏移），用 Celsius 作为中转做特判（对应原版 ExplicitConversionData）。
//
// 趣味单位（isWhimsical，如足球场/大象等）暂不纳入，只移植标准计量单位。

import Foundation

/// 单个换算单位。
struct ConverterUnit: Identifiable, Hashable {
    let id: Int
    let name: String
    let abbreviation: String
    /// 相对类别基准单位的换算因子（温度类别此值无意义，走特判）。
    let factor: Double
}

/// 换算类别。
struct ConverterCategory: Identifiable, Hashable {
    let id: Int
    let name: String
    /// 是否允许输入负数（对应原版 Category.supportsNegative，仅温度为 true）。
    let supportsNegative: Bool
    /// 温度类别走非线性特判而非 factor 比值。
    let isTemperature: Bool
    let units: [ConverterUnit]

    static func == (lhs: ConverterCategory, rhs: ConverterCategory) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum UnitConverterData {
    // 温度单位 id（用于特判），沿用原版 UnitConverterUnits 编号。
    static let celsiusID = 46
    static let fahrenheitID = 47
    static let kelvinID = 48

    static let categories: [ConverterCategory] = [
        lengthCategory,
        weightCategory,
        volumeCategory,
        temperatureCategory,
        areaCategory,
        speedCategory,
        timeCategory,
        powerCategory,
        dataCategory,
        pressureCategory,
        angleCategory,
        energyCategory,
    ]

    // MARK: - 长度（基准：米）
    private static let lengthCategory = ConverterCategory(
        id: 1, name: "长度", supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 38, name: "纳米", abbreviation: "nm", factor: 0.000000001),
            ConverterUnit(id: 168, name: "埃", abbreviation: "Å", factor: 0.0000000001),
            ConverterUnit(id: 35, name: "微米", abbreviation: "µm", factor: 0.000001),
            ConverterUnit(id: 37, name: "毫米", abbreviation: "mm", factor: 0.001),
            ConverterUnit(id: 30, name: "厘米", abbreviation: "cm", factor: 0.01),
            ConverterUnit(id: 34, name: "米", abbreviation: "m", factor: 1),
            ConverterUnit(id: 33, name: "千米", abbreviation: "km", factor: 1000),
            ConverterUnit(id: 32, name: "英寸", abbreviation: "in", factor: 0.0254),
            ConverterUnit(id: 31, name: "英尺", abbreviation: "ft", factor: 0.3048),
            ConverterUnit(id: 40, name: "码", abbreviation: "yd", factor: 0.9144),
            ConverterUnit(id: 36, name: "英里", abbreviation: "mi", factor: 1609.344),
            ConverterUnit(id: 39, name: "海里", abbreviation: "nmi", factor: 1852),
        ])

    // MARK: - 重量/质量（基准：千克）
    private static let weightCategory = ConverterCategory(
        id: 2, name: "重量和质量", supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 82, name: "克拉", abbreviation: "ct", factor: 0.0002),
            ConverterUnit(id: 90, name: "毫克", abbreviation: "mg", factor: 0.000001),
            ConverterUnit(id: 83, name: "厘克", abbreviation: "cg", factor: 0.00001),
            ConverterUnit(id: 84, name: "分克", abbreviation: "dg", factor: 0.0001),
            ConverterUnit(id: 86, name: "克", abbreviation: "g", factor: 0.001),
            ConverterUnit(id: 85, name: "十克", abbreviation: "dag", factor: 0.01),
            ConverterUnit(id: 87, name: "百克", abbreviation: "hg", factor: 0.1),
            ConverterUnit(id: 88, name: "千克", abbreviation: "kg", factor: 1),
            ConverterUnit(id: 95, name: "公吨", abbreviation: "t", factor: 1000),
            ConverterUnit(id: 91, name: "盎司", abbreviation: "oz", factor: 0.028349523125),
            ConverterUnit(id: 92, name: "磅", abbreviation: "lb", factor: 0.45359237),
            ConverterUnit(id: 94, name: "英石", abbreviation: "st", factor: 6.35029318),
            ConverterUnit(id: 93, name: "短吨", abbreviation: "ton", factor: 907.18474),
            ConverterUnit(id: 89, name: "长吨", abbreviation: "long ton", factor: 1016.0469088),
        ])

    // MARK: - 体积（基准：毫升/立方厘米）
    private static let volumeCategory = ConverterCategory(
        id: 3, name: "体积", supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 75, name: "毫升", abbreviation: "mL", factor: 1),
            ConverterUnit(id: 64, name: "立方厘米", abbreviation: "cm³", factor: 1),
            ConverterUnit(id: 79, name: "茶匙(美)", abbreviation: "tsp", factor: 4.92892159375),
            ConverterUnit(id: 78, name: "汤匙(美)", abbreviation: "tbsp", factor: 14.78676478125),
            ConverterUnit(id: 71, name: "液盎司(美)", abbreviation: "fl oz", factor: 29.5735295625),
            ConverterUnit(id: 70, name: "液盎司(英)", abbreviation: "fl oz (UK)", factor: 28.4130625),
            ConverterUnit(id: 69, name: "杯(美)", abbreviation: "cup", factor: 236.588237),
            ConverterUnit(id: 77, name: "品脱(美)", abbreviation: "pt", factor: 473.176473),
            ConverterUnit(id: 76, name: "品脱(英)", abbreviation: "pt (UK)", factor: 568.26125),
            ConverterUnit(id: 81, name: "夸脱(美)", abbreviation: "qt", factor: 946.352946),
            ConverterUnit(id: 80, name: "夸脱(英)", abbreviation: "qt (UK)", factor: 1136.5225),
            ConverterUnit(id: 74, name: "升", abbreviation: "L", factor: 1000),
            ConverterUnit(id: 73, name: "加仑(美)", abbreviation: "gal", factor: 3785.411784),
            ConverterUnit(id: 72, name: "加仑(英)", abbreviation: "gal (UK)", factor: 4546.09),
            ConverterUnit(id: 66, name: "立方英寸", abbreviation: "in³", factor: 16.387064),
            ConverterUnit(id: 65, name: "立方英尺", abbreviation: "ft³", factor: 28316.846592),
            ConverterUnit(id: 68, name: "立方码", abbreviation: "yd³", factor: 764554.857984),
            ConverterUnit(id: 67, name: "立方米", abbreviation: "m³", factor: 1000000),
        ])

    // MARK: - 温度（特判，基准中转：摄氏度）
    private static let temperatureCategory = ConverterCategory(
        id: 4, name: "温度", supportsNegative: true, isTemperature: true,
        units: [
            ConverterUnit(id: celsiusID, name: "摄氏度", abbreviation: "°C", factor: 1),
            ConverterUnit(id: fahrenheitID, name: "华氏度", abbreviation: "°F", factor: 1),
            ConverterUnit(id: kelvinID, name: "开尔文", abbreviation: "K", factor: 1),
        ])

    // MARK: - 面积（基准：平方米）
    private static let areaCategory = ConverterCategory(
        id: 5, name: "面积", supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 9, name: "平方毫米", abbreviation: "mm²", factor: 0.000001),
            ConverterUnit(id: 3, name: "平方厘米", abbreviation: "cm²", factor: 0.0001),
            ConverterUnit(id: 7, name: "平方米", abbreviation: "m²", factor: 1),
            ConverterUnit(id: 2, name: "公顷", abbreviation: "ha", factor: 10000),
            ConverterUnit(id: 6, name: "平方千米", abbreviation: "km²", factor: 1000000),
            ConverterUnit(id: 5, name: "平方英寸", abbreviation: "in²", factor: 0.00064516),
            ConverterUnit(id: 4, name: "平方英尺", abbreviation: "ft²", factor: 0.09290304),
            ConverterUnit(id: 10, name: "平方码", abbreviation: "yd²", factor: 0.83612736),
            ConverterUnit(id: 1, name: "英亩", abbreviation: "ac", factor: 4046.8564224),
            ConverterUnit(id: 8, name: "平方英里", abbreviation: "mi²", factor: 2589988.110336),
            ConverterUnit(id: 165, name: "坪", abbreviation: "坪", factor: 400.0 / 121.0),
        ])

    // MARK: - 速度（基准：厘米/秒）
    private static let speedCategory = ConverterCategory(
        id: 6, name: "速度", supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 57, name: "厘米/秒", abbreviation: "cm/s", factor: 1),
            ConverterUnit(id: 62, name: "米/秒", abbreviation: "m/s", factor: 100),
            ConverterUnit(id: 59, name: "千米/时", abbreviation: "km/h", factor: 27.77777777777778),
            ConverterUnit(id: 58, name: "英尺/秒", abbreviation: "ft/s", factor: 30.48),
            ConverterUnit(id: 63, name: "英里/时", abbreviation: "mph", factor: 44.7),
            ConverterUnit(id: 60, name: "节", abbreviation: "kn", factor: 51.44),
            ConverterUnit(id: 61, name: "马赫", abbreviation: "M", factor: 34030),
        ])

    // MARK: - 时间（基准：秒）
    private static let timeCategory = ConverterCategory(
        id: 7, name: "时间", supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 51, name: "微秒", abbreviation: "µs", factor: 0.000001),
            ConverterUnit(id: 52, name: "毫秒", abbreviation: "ms", factor: 0.001),
            ConverterUnit(id: 54, name: "秒", abbreviation: "s", factor: 1),
            ConverterUnit(id: 53, name: "分", abbreviation: "min", factor: 60),
            ConverterUnit(id: 50, name: "时", abbreviation: "h", factor: 3600),
            ConverterUnit(id: 49, name: "天", abbreviation: "d", factor: 86400),
            ConverterUnit(id: 55, name: "周", abbreviation: "wk", factor: 604800),
            ConverterUnit(id: 56, name: "年", abbreviation: "yr", factor: 31557600),
        ])

    // MARK: - 功率（基准：瓦特）
    private static let powerCategory = ConverterCategory(
        id: 8, name: "功率", supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 42, name: "英尺磅/分", abbreviation: "ft·lb/min", factor: 0.0225969658055233),
            ConverterUnit(id: 45, name: "瓦特", abbreviation: "W", factor: 1),
            ConverterUnit(id: 41, name: "英热单位/分", abbreviation: "BTU/min", factor: 17.58426666666667),
            ConverterUnit(id: 44, name: "千瓦", abbreviation: "kW", factor: 1000),
            ConverterUnit(id: 43, name: "马力", abbreviation: "hp", factor: 745.6998715822702),
        ])

    // MARK: - 数据（基准：兆字节 MB）
    private static let dataCategory = ConverterCategory(
        id: 9, name: "数据", supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 11, name: "比特", abbreviation: "b", factor: 0.000000125),
            ConverterUnit(id: 167, name: "半字节", abbreviation: "nibble", factor: 0.0000005),
            ConverterUnit(id: 12, name: "字节", abbreviation: "B", factor: 0.000001),
            ConverterUnit(id: 15, name: "千比特", abbreviation: "Kb", factor: 0.000125),
            ConverterUnit(id: 16, name: "千字节", abbreviation: "KB", factor: 0.001),
            ConverterUnit(id: 17, name: "兆比特", abbreviation: "Mb", factor: 0.125),
            ConverterUnit(id: 18, name: "兆字节", abbreviation: "MB", factor: 1),
            ConverterUnit(id: 13, name: "吉比特", abbreviation: "Gb", factor: 125),
            ConverterUnit(id: 14, name: "吉字节", abbreviation: "GB", factor: 1000),
            ConverterUnit(id: 21, name: "太比特", abbreviation: "Tb", factor: 125000),
            ConverterUnit(id: 22, name: "太字节", abbreviation: "TB", factor: 1000000),
            ConverterUnit(id: 19, name: "拍比特", abbreviation: "Pb", factor: 125000000),
            ConverterUnit(id: 20, name: "拍字节", abbreviation: "PB", factor: 1000000000),
            ConverterUnit(id: 149, name: "kibibit", abbreviation: "Kib", factor: 0.000128),
            ConverterUnit(id: 150, name: "kibibyte", abbreviation: "KiB", factor: 0.001024),
            ConverterUnit(id: 151, name: "mebibit", abbreviation: "Mib", factor: 0.131072),
            ConverterUnit(id: 152, name: "mebibyte", abbreviation: "MiB", factor: 1.048576),
            ConverterUnit(id: 147, name: "gibibit", abbreviation: "Gib", factor: 134.217728),
            ConverterUnit(id: 148, name: "gibibyte", abbreviation: "GiB", factor: 1073.741824),
            ConverterUnit(id: 155, name: "tebibit", abbreviation: "Tib", factor: 137438.953472),
            ConverterUnit(id: 156, name: "tebibyte", abbreviation: "TiB", factor: 1099511.627776),
        ])

    // MARK: - 压强（基准：标准大气压）
    private static let pressureCategory = ConverterCategory(
        id: 10, name: "压强", supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 137, name: "标准大气压", abbreviation: "atm", factor: 1),
            ConverterUnit(id: 138, name: "巴", abbreviation: "bar", factor: 0.9869232667160128),
            ConverterUnit(id: 139, name: "千帕", abbreviation: "kPa", factor: 0.0098692326671601),
            ConverterUnit(id: 140, name: "毫米汞柱", abbreviation: "mmHg", factor: 0.0013155687145324),
            ConverterUnit(id: 141, name: "帕斯卡", abbreviation: "Pa", factor: 9.869232667160128e-6),
            ConverterUnit(id: 142, name: "磅/平方英寸", abbreviation: "psi", factor: 0.068045961016531),
        ])

    // MARK: - 角度（基准：度）
    private static let angleCategory = ConverterCategory(
        id: 11, name: "角度", supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 134, name: "度", abbreviation: "°", factor: 1),
            ConverterUnit(id: 135, name: "弧度", abbreviation: "rad", factor: 57.29577951308233),
            ConverterUnit(id: 136, name: "百分度", abbreviation: "grad", factor: 0.9),
        ])

    // MARK: - 能量（基准：焦耳）
    private static let energyCategory = ConverterCategory(
        id: 12, name: "能量", supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 25, name: "电子伏特", abbreviation: "eV", factor: 1.602176565e-19),
            ConverterUnit(id: 27, name: "焦耳", abbreviation: "J", factor: 1),
            ConverterUnit(id: 26, name: "英尺磅", abbreviation: "ft·lb", factor: 1.3558179483314),
            ConverterUnit(id: 24, name: "卡路里", abbreviation: "cal", factor: 4.184),
            ConverterUnit(id: 29, name: "千焦", abbreviation: "kJ", factor: 1000),
            ConverterUnit(id: 28, name: "千卡", abbreviation: "kcal", factor: 4184),
            ConverterUnit(id: 23, name: "英热单位", abbreviation: "BTU", factor: 1055.056),
            ConverterUnit(id: 166, name: "千瓦时", abbreviation: "kWh", factor: 3600000),
        ])

    // MARK: - 换算

    /// 在同一类别内把 value 从 fromUnit 换算到 toUnit。
    static func convert(_ value: Double, from fromUnit: ConverterUnit, to toUnit: ConverterUnit, category: ConverterCategory) -> Double {
        if category.isTemperature {
            let celsius = toCelsius(value, unitID: fromUnit.id)
            return fromCelsius(celsius, unitID: toUnit.id)
        }
        return value * (fromUnit.factor / toUnit.factor)
    }

    private static func toCelsius(_ value: Double, unitID: Int) -> Double {
        switch unitID {
        case fahrenheitID: return (value - 32) / 1.8
        case kelvinID: return value - 273.15
        default: return value // 摄氏度
        }
    }

    private static func fromCelsius(_ celsius: Double, unitID: Int) -> Double {
        switch unitID {
        case fahrenheitID: return celsius * 1.8 + 32
        case kelvinID: return celsius + 273.15
        default: return celsius // 摄氏度
        }
    }
}
