// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 静态单位换算数据表，镜像自 spec/units.json（S6 规格表下沉，SpecTableTests 双向防漂移）；
// 数据最初移植自 src/CalcViewModel/DataLoaders/UnitConverterDataLoader.cpp 的
// GetConversionData / GetExplicitConversionData。
//
// 换算原理与原版一致：
//   - 普通类别：每个单位有一个相对「基准单位」的换算因子 factor（基准单位 factor == 1）。
//     value(from) → value(to) == value * (fromFactor / toFactor)。
//   - 温度：非线性（含偏移），用 Celsius 作为中转做特判（对应原版 ExplicitConversionData）。
//
// 趣味单位（isWhimsical，如足球场/大象等）按原版行为收录：
// 不可选为源/目标单位（isConversionSource/Target=false），仅出现在补充结果，
// 且补充结果末尾只追加第一个趣味条目（对应 UnitConverter::CalculateSuggested）。

import Foundation

/// 单个换算单位。
struct ConverterUnit: Identifiable, Hashable {
    let id: Int
    let name: String
    let abbreviation: String
    /// 相对类别基准单位的换算因子（温度类别此值无意义，走特判）。
    let factor: Double
    /// 趣味单位：不可选为源/目标，仅出现在补充结果（对应原版 isWhimsical）。
    var isWhimsical: Bool = false
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

    /// 可在下拉框中选择的单位（排除趣味单位，对应 isConversionSource/Target=false）。
    var selectableUnits: [ConverterUnit] { units.filter { !$0.isWhimsical } }

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
        id: 1, name: L10n.string("CategoryName_LengthText"), supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 38, name: L10n.string("UnitName_Nanometer"), abbreviation: L10n.string("UnitAbbreviation_Nanometer"), factor: 0.000000001),
            ConverterUnit(id: 168, name: L10n.string("UnitName_Angstrom"), abbreviation: L10n.string("UnitAbbreviation_Angstrom"), factor: 0.0000000001),
            ConverterUnit(id: 35, name: L10n.string("UnitName_Micron"), abbreviation: L10n.string("UnitAbbreviation_Micron"), factor: 0.000001),
            ConverterUnit(id: 37, name: L10n.string("UnitName_Millimeter"), abbreviation: L10n.string("UnitAbbreviation_Millimeter"), factor: 0.001),
            ConverterUnit(id: 30, name: L10n.string("UnitName_Centimeter"), abbreviation: L10n.string("UnitAbbreviation_Centimeter"), factor: 0.01),
            ConverterUnit(id: 34, name: L10n.string("UnitName_Meter"), abbreviation: L10n.string("UnitAbbreviation_Meter"), factor: 1),
            ConverterUnit(id: 33, name: L10n.string("UnitName_Kilometer"), abbreviation: L10n.string("UnitAbbreviation_Kilometer"), factor: 1000),
            ConverterUnit(id: 32, name: L10n.string("UnitName_Inch"), abbreviation: L10n.string("UnitAbbreviation_Inch"), factor: 0.0254),
            ConverterUnit(id: 31, name: L10n.string("UnitName_Foot"), abbreviation: L10n.string("UnitAbbreviation_Foot"), factor: 0.3048),
            ConverterUnit(id: 40, name: L10n.string("UnitName_Yard"), abbreviation: L10n.string("UnitAbbreviation_Yard"), factor: 0.9144),
            ConverterUnit(id: 36, name: L10n.string("UnitName_Mile"), abbreviation: L10n.string("UnitAbbreviation_Mile"), factor: 1609.344),
            ConverterUnit(id: 39, name: L10n.string("UnitName_NauticalMile"), abbreviation: L10n.string("UnitAbbreviation_NauticalMile"), factor: 1852),
            ConverterUnit(id: 105, name: L10n.string("UnitName_Paperclip"), abbreviation: L10n.string("UnitAbbreviation_Paperclip"), factor: 0.035052, isWhimsical: true),
            ConverterUnit(id: 131, name: L10n.string("UnitName_Hand"), abbreviation: L10n.string("UnitAbbreviation_Hand"), factor: 0.18669, isWhimsical: true),
            ConverterUnit(id: 107, name: L10n.string("UnitName_JumboJet"), abbreviation: L10n.string("UnitAbbreviation_JumboJet"), factor: 76, isWhimsical: true),
        ])

    // MARK: - 重量/质量（基准：千克）
    private static let weightCategory = ConverterCategory(
        id: 2, name: L10n.string("CategoryName_WeightText"), supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 82, name: L10n.string("UnitName_Carat"), abbreviation: L10n.string("UnitAbbreviation_Carat"), factor: 0.0002),
            ConverterUnit(id: 90, name: L10n.string("UnitName_Milligram"), abbreviation: L10n.string("UnitAbbreviation_Milligram"), factor: 0.000001),
            ConverterUnit(id: 83, name: L10n.string("UnitName_Centigram"), abbreviation: L10n.string("UnitAbbreviation_Centigram"), factor: 0.00001),
            ConverterUnit(id: 84, name: L10n.string("UnitName_Decigram"), abbreviation: L10n.string("UnitAbbreviation_Decigram"), factor: 0.0001),
            ConverterUnit(id: 86, name: L10n.string("UnitName_Gram"), abbreviation: L10n.string("UnitAbbreviation_Gram"), factor: 0.001),
            ConverterUnit(id: 85, name: L10n.string("UnitName_Decagram"), abbreviation: L10n.string("UnitAbbreviation_Decagram"), factor: 0.01),
            ConverterUnit(id: 87, name: L10n.string("UnitName_Hectogram"), abbreviation: L10n.string("UnitAbbreviation_Hectogram"), factor: 0.1),
            ConverterUnit(id: 88, name: L10n.string("UnitName_Kilogram"), abbreviation: L10n.string("UnitAbbreviation_Kilogram"), factor: 1),
            ConverterUnit(id: 95, name: L10n.string("UnitName_Tonne"), abbreviation: L10n.string("UnitAbbreviation_Tonne"), factor: 1000),
            ConverterUnit(id: 91, name: L10n.string("UnitName_Ounce"), abbreviation: L10n.string("UnitAbbreviation_Ounce"), factor: 0.028349523125),
            ConverterUnit(id: 92, name: L10n.string("UnitName_Pound"), abbreviation: L10n.string("UnitAbbreviation_Pound"), factor: 0.45359237),
            ConverterUnit(id: 94, name: L10n.string("UnitName_Stone"), abbreviation: L10n.string("UnitAbbreviation_Stone"), factor: 6.35029318),
            ConverterUnit(id: 93, name: L10n.string("UnitName_ShortTon"), abbreviation: L10n.string("UnitAbbreviation_ShortTon"), factor: 907.18474),
            ConverterUnit(id: 89, name: L10n.string("UnitName_LongTon"), abbreviation: L10n.string("UnitAbbreviation_LongTon"), factor: 1016.0469088),
            ConverterUnit(id: 113, name: L10n.string("UnitName_Snowflake"), abbreviation: L10n.string("UnitAbbreviation_Snowflake"), factor: 0.000002, isWhimsical: true),
            ConverterUnit(id: 133, name: L10n.string("UnitName_SoccerBall"), abbreviation: L10n.string("UnitAbbreviation_SoccerBall"), factor: 0.4325, isWhimsical: true),
            ConverterUnit(id: 114, name: L10n.string("UnitName_Elephant"), abbreviation: L10n.string("UnitAbbreviation_Elephant"), factor: 4000, isWhimsical: true),
            ConverterUnit(id: 123, name: L10n.string("UnitName_Whale"), abbreviation: L10n.string("UnitAbbreviation_Whale"), factor: 90000, isWhimsical: true),
        ])

    // MARK: - 体积（基准：毫升/立方厘米）
    private static let volumeCategory = ConverterCategory(
        id: 3, name: L10n.string("CategoryName_VolumeText"), supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 75, name: L10n.string("UnitName_Milliliter"), abbreviation: L10n.string("UnitAbbreviation_Milliliter"), factor: 1),
            ConverterUnit(id: 64, name: L10n.string("UnitName_CubicCentimeter"), abbreviation: L10n.string("UnitAbbreviation_CubicCentimeter"), factor: 1),
            ConverterUnit(id: 79, name: L10n.string("UnitName_TeaspoonUS"), abbreviation: L10n.string("UnitAbbreviation_TeaspoonUS"), factor: 4.92892159375),
            ConverterUnit(id: 78, name: L10n.string("UnitName_TablespoonUS"), abbreviation: L10n.string("UnitAbbreviation_TablespoonUS"), factor: 14.78676478125),
            ConverterUnit(id: 71, name: L10n.string("UnitName_FluidOunceUS"), abbreviation: L10n.string("UnitAbbreviation_FluidOunceUS"), factor: 29.5735295625),
            ConverterUnit(id: 70, name: L10n.string("UnitName_FluidOunceUK"), abbreviation: L10n.string("UnitAbbreviation_FluidOunceUK"), factor: 28.4130625),
            ConverterUnit(id: 69, name: L10n.string("UnitName_CupUS"), abbreviation: L10n.string("UnitAbbreviation_CupUS"), factor: 236.588237),
            ConverterUnit(id: 77, name: L10n.string("UnitName_PintUS"), abbreviation: L10n.string("UnitAbbreviation_PintUS"), factor: 473.176473),
            ConverterUnit(id: 76, name: L10n.string("UnitName_PintUK"), abbreviation: L10n.string("UnitAbbreviation_PintUK"), factor: 568.26125),
            ConverterUnit(id: 81, name: L10n.string("UnitName_QuartUS"), abbreviation: L10n.string("UnitAbbreviation_QuartUS"), factor: 946.352946),
            ConverterUnit(id: 80, name: L10n.string("UnitName_QuartUK"), abbreviation: L10n.string("UnitAbbreviation_QuartUK"), factor: 1136.5225),
            ConverterUnit(id: 74, name: L10n.string("UnitName_Liter"), abbreviation: L10n.string("UnitAbbreviation_Liter"), factor: 1000),
            ConverterUnit(id: 73, name: L10n.string("UnitName_GallonUS"), abbreviation: L10n.string("UnitAbbreviation_GallonUS"), factor: 3785.411784),
            ConverterUnit(id: 72, name: L10n.string("UnitName_GallonUK"), abbreviation: L10n.string("UnitAbbreviation_GallonUK"), factor: 4546.09),
            ConverterUnit(id: 66, name: L10n.string("UnitName_CubicInch"), abbreviation: L10n.string("UnitAbbreviation_CubicInch"), factor: 16.387064),
            ConverterUnit(id: 65, name: L10n.string("UnitName_CubicFoot"), abbreviation: L10n.string("UnitAbbreviation_CubicFoot"), factor: 28316.846592),
            ConverterUnit(id: 68, name: L10n.string("UnitName_CubicYard"), abbreviation: L10n.string("UnitAbbreviation_CubicYard"), factor: 764554.857984),
            ConverterUnit(id: 67, name: L10n.string("UnitName_CubicMeter"), abbreviation: L10n.string("UnitAbbreviation_CubicMeter"), factor: 1000000),
            ConverterUnit(id: 124, name: L10n.string("UnitName_CoffeeCup"), abbreviation: L10n.string("UnitAbbreviation_CoffeeCup"), factor: 236.5882, isWhimsical: true),
            ConverterUnit(id: 111, name: L10n.string("UnitName_Bathtub"), abbreviation: L10n.string("UnitAbbreviation_Bathtub"), factor: 378541.2, isWhimsical: true),
            ConverterUnit(id: 125, name: L10n.string("UnitName_SwimmingPool"), abbreviation: L10n.string("UnitAbbreviation_SwimmingPool"), factor: 3750000000, isWhimsical: true),
        ])

    // MARK: - 温度（特判，基准中转：摄氏度）
    private static let temperatureCategory = ConverterCategory(
        id: 4, name: L10n.string("CategoryName_TemperatureText"), supportsNegative: true, isTemperature: true,
        units: [
            ConverterUnit(id: celsiusID, name: L10n.string("UnitName_DegreesCelsius"), abbreviation: L10n.string("UnitAbbreviation_DegreesCelsius"), factor: 1),
            ConverterUnit(id: fahrenheitID, name: L10n.string("UnitName_DegreesFahrenheit"), abbreviation: L10n.string("UnitAbbreviation_DegreesFahrenheit"), factor: 1),
            ConverterUnit(id: kelvinID, name: L10n.string("UnitName_Kelvin"), abbreviation: L10n.string("UnitAbbreviation_Kelvin"), factor: 1),
        ])

    // MARK: - 面积（基准：平方米）
    private static let areaCategory = ConverterCategory(
        id: 5, name: L10n.string("CategoryName_AreaText"), supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 9, name: L10n.string("UnitName_SquareMillimeter"), abbreviation: L10n.string("UnitAbbreviation_SquareMillimeter"), factor: 0.000001),
            ConverterUnit(id: 3, name: L10n.string("UnitName_SquareCentimeter"), abbreviation: L10n.string("UnitAbbreviation_SquareCentimeter"), factor: 0.0001),
            ConverterUnit(id: 7, name: L10n.string("UnitName_SquareMeter"), abbreviation: L10n.string("UnitAbbreviation_SquareMeter"), factor: 1),
            ConverterUnit(id: 2, name: L10n.string("UnitName_Hectare"), abbreviation: L10n.string("UnitAbbreviation_Hectare"), factor: 10000),
            ConverterUnit(id: 6, name: L10n.string("UnitName_SquareKilometer"), abbreviation: L10n.string("UnitAbbreviation_SquareKilometer"), factor: 1000000),
            ConverterUnit(id: 5, name: L10n.string("UnitName_SquareInch"), abbreviation: L10n.string("UnitAbbreviation_SquareInch"), factor: 0.00064516),
            ConverterUnit(id: 4, name: L10n.string("UnitName_SquareFoot"), abbreviation: L10n.string("UnitAbbreviation_SquareFoot"), factor: 0.09290304),
            ConverterUnit(id: 10, name: L10n.string("UnitName_SquareYard"), abbreviation: L10n.string("UnitAbbreviation_SquareYard"), factor: 0.83612736),
            ConverterUnit(id: 1, name: L10n.string("UnitName_Acre"), abbreviation: L10n.string("UnitAbbreviation_Acre"), factor: 4046.8564224),
            ConverterUnit(id: 8, name: L10n.string("UnitName_SquareMile"), abbreviation: L10n.string("UnitAbbreviation_SquareMile"), factor: 2589988.110336),
            ConverterUnit(id: 165, name: L10n.string("UnitName_Pyeong"), abbreviation: L10n.string("UnitAbbreviation_Pyeong"), factor: 400.0 / 121.0),
            ConverterUnit(id: 118, name: L10n.string("UnitName_Hand"), abbreviation: L10n.string("UnitAbbreviation_Hand"), factor: 0.012516104, isWhimsical: true),
            ConverterUnit(id: 127, name: L10n.string("UnitName_Paper"), abbreviation: L10n.string("UnitAbbreviation_Paper"), factor: 0.06032246, isWhimsical: true),
            ConverterUnit(id: 99, name: L10n.string("UnitName_SoccerField"), abbreviation: L10n.string("UnitAbbreviation_SoccerField"), factor: 10869.66, isWhimsical: true),
            ConverterUnit(id: 128, name: L10n.string("UnitName_Castle"), abbreviation: L10n.string("UnitAbbreviation_Castle"), factor: 100000, isWhimsical: true),
        ])

    // MARK: - 速度（基准：厘米/秒）
    private static let speedCategory = ConverterCategory(
        id: 6, name: L10n.string("CategoryName_SpeedText"), supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 57, name: L10n.string("UnitName_CentimetersPerSecond"), abbreviation: L10n.string("UnitAbbreviation_CentimetersPerSecond"), factor: 1),
            ConverterUnit(id: 62, name: L10n.string("UnitName_MetersPerSecond"), abbreviation: L10n.string("UnitAbbreviation_MetersPerSecond"), factor: 100),
            ConverterUnit(id: 59, name: L10n.string("UnitName_KilometersPerHour"), abbreviation: L10n.string("UnitAbbreviation_KilometersPerHour"), factor: 27.77777777777778),
            ConverterUnit(id: 58, name: L10n.string("UnitName_FeetPerSecond"), abbreviation: L10n.string("UnitAbbreviation_FeetPerSecond"), factor: 30.48),
            ConverterUnit(id: 63, name: L10n.string("UnitName_MilesPerHour"), abbreviation: L10n.string("UnitAbbreviation_MilesPerHour"), factor: 44.7),
            ConverterUnit(id: 60, name: L10n.string("UnitName_Knot"), abbreviation: L10n.string("UnitAbbreviation_Knot"), factor: 51.44),
            ConverterUnit(id: 61, name: L10n.string("UnitName_Mach"), abbreviation: L10n.string("UnitAbbreviation_Mach"), factor: 34030),
            ConverterUnit(id: 121, name: L10n.string("UnitName_Turtle"), abbreviation: L10n.string("UnitAbbreviation_Turtle"), factor: 8.94, isWhimsical: true),
            ConverterUnit(id: 126, name: L10n.string("UnitName_Horse"), abbreviation: L10n.string("UnitAbbreviation_Horse"), factor: 2011.5, isWhimsical: true),
            ConverterUnit(id: 122, name: L10n.string("UnitName_Jet"), abbreviation: L10n.string("UnitAbbreviation_Jet"), factor: 24585, isWhimsical: true),
        ])

    // MARK: - 时间（基准：秒）
    private static let timeCategory = ConverterCategory(
        id: 7, name: L10n.string("CategoryName_TimeText"), supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 51, name: L10n.string("UnitName_Microsecond"), abbreviation: L10n.string("UnitAbbreviation_Microsecond"), factor: 0.000001),
            ConverterUnit(id: 52, name: L10n.string("UnitName_Millisecond"), abbreviation: L10n.string("UnitAbbreviation_Millisecond"), factor: 0.001),
            ConverterUnit(id: 54, name: L10n.string("UnitName_Second"), abbreviation: L10n.string("UnitAbbreviation_Second"), factor: 1),
            ConverterUnit(id: 53, name: L10n.string("UnitName_Minute"), abbreviation: L10n.string("UnitAbbreviation_Minute"), factor: 60),
            ConverterUnit(id: 50, name: L10n.string("UnitName_Hour"), abbreviation: L10n.string("UnitAbbreviation_Hour"), factor: 3600),
            ConverterUnit(id: 49, name: L10n.string("UnitName_Day"), abbreviation: L10n.string("UnitAbbreviation_Day"), factor: 86400),
            ConverterUnit(id: 55, name: L10n.string("UnitName_Week"), abbreviation: L10n.string("UnitAbbreviation_Week"), factor: 604800),
            ConverterUnit(id: 56, name: L10n.string("UnitName_Year"), abbreviation: L10n.string("UnitAbbreviation_Year"), factor: 31557600),
        ])

    // MARK: - 功率（基准：瓦特）
    private static let powerCategory = ConverterCategory(
        id: 8, name: L10n.string("CategoryName_PowerText"), supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 42, name: L10n.string("UnitName_Foot-PoundPerMinute"), abbreviation: L10n.string("UnitAbbreviation_Foot-PoundPerMinute"), factor: 0.0225969658055233),
            ConverterUnit(id: 45, name: L10n.string("UnitName_Watt"), abbreviation: L10n.string("UnitAbbreviation_Watt"), factor: 1),
            ConverterUnit(id: 41, name: L10n.string("UnitName_BTUPerMinute"), abbreviation: L10n.string("UnitAbbreviation_BTUPerMinute"), factor: 17.58426666666667),
            ConverterUnit(id: 44, name: L10n.string("UnitName_Kilowatt"), abbreviation: L10n.string("UnitAbbreviation_Kilowatt"), factor: 1000),
            ConverterUnit(id: 43, name: L10n.string("UnitName_Horsepower"), abbreviation: L10n.string("UnitAbbreviation_Horsepower"), factor: 745.6998715822702),
            ConverterUnit(id: 108, name: L10n.string("UnitName_LightBulb"), abbreviation: L10n.string("UnitAbbreviation_LightBulb"), factor: 60, isWhimsical: true),
            ConverterUnit(id: 109, name: L10n.string("UnitName_Horse"), abbreviation: L10n.string("UnitAbbreviation_Horse"), factor: 745.7, isWhimsical: true),
            ConverterUnit(id: 132, name: L10n.string("UnitName_TrainEngine"), abbreviation: L10n.string("UnitAbbreviation_TrainEngine"), factor: 2982799.486329081, isWhimsical: true),
        ])

    // MARK: - 数据（基准：兆字节 MB）
    private static let dataCategory = ConverterCategory(
        id: 9, name: L10n.string("CategoryName_DataText"), supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 11, name: L10n.string("UnitName_Bit"), abbreviation: L10n.string("UnitAbbreviation_Bit"), factor: 0.000000125),
            ConverterUnit(id: 167, name: L10n.string("UnitName_Nibble"), abbreviation: L10n.string("UnitAbbreviation_Nibble"), factor: 0.0000005),
            ConverterUnit(id: 12, name: L10n.string("UnitName_Byte"), abbreviation: L10n.string("UnitAbbreviation_Byte"), factor: 0.000001),
            ConverterUnit(id: 15, name: L10n.string("UnitName_Kilobit"), abbreviation: L10n.string("UnitAbbreviation_Kilobit"), factor: 0.000125),
            ConverterUnit(id: 16, name: L10n.string("UnitName_Kilobyte"), abbreviation: L10n.string("UnitAbbreviation_Kilobyte"), factor: 0.001),
            ConverterUnit(id: 17, name: L10n.string("UnitName_Megabit"), abbreviation: L10n.string("UnitAbbreviation_Megabit"), factor: 0.125),
            ConverterUnit(id: 18, name: L10n.string("UnitName_Megabyte"), abbreviation: L10n.string("UnitAbbreviation_Megabyte"), factor: 1),
            ConverterUnit(id: 13, name: L10n.string("UnitName_Gigabit"), abbreviation: L10n.string("UnitAbbreviation_Gigabit"), factor: 125),
            ConverterUnit(id: 14, name: L10n.string("UnitName_Gigabyte"), abbreviation: L10n.string("UnitAbbreviation_Gigabyte"), factor: 1000),
            ConverterUnit(id: 21, name: L10n.string("UnitName_Terabit"), abbreviation: L10n.string("UnitAbbreviation_Terabit"), factor: 125000),
            ConverterUnit(id: 22, name: L10n.string("UnitName_Terabyte"), abbreviation: L10n.string("UnitAbbreviation_Terabyte"), factor: 1000000),
            ConverterUnit(id: 19, name: L10n.string("UnitName_Petabit"), abbreviation: L10n.string("UnitAbbreviation_Petabit"), factor: 125000000),
            ConverterUnit(id: 20, name: L10n.string("UnitName_Petabyte"), abbreviation: L10n.string("UnitAbbreviation_Petabyte"), factor: 1000000000),
            ConverterUnit(id: 149, name: L10n.string("UnitName_Kibibits"), abbreviation: L10n.string("UnitAbbreviation_Kibibits"), factor: 0.000128),
            ConverterUnit(id: 150, name: L10n.string("UnitName_Kibibytes"), abbreviation: L10n.string("UnitAbbreviation_Kibibytes"), factor: 0.001024),
            ConverterUnit(id: 151, name: L10n.string("UnitName_Mebibits"), abbreviation: L10n.string("UnitAbbreviation_Mebibits"), factor: 0.131072),
            ConverterUnit(id: 152, name: L10n.string("UnitName_Mebibytes"), abbreviation: L10n.string("UnitAbbreviation_Mebibytes"), factor: 1.048576),
            ConverterUnit(id: 147, name: L10n.string("UnitName_Gibibits"), abbreviation: L10n.string("UnitAbbreviation_Gibibits"), factor: 134.217728),
            ConverterUnit(id: 148, name: L10n.string("UnitName_Gibibytes"), abbreviation: L10n.string("UnitAbbreviation_Gibibytes"), factor: 1073.741824),
            ConverterUnit(id: 155, name: L10n.string("UnitName_Tebibits"), abbreviation: L10n.string("UnitAbbreviation_Tebibits"), factor: 137438.953472),
            ConverterUnit(id: 156, name: L10n.string("UnitName_Tebibytes"), abbreviation: L10n.string("UnitAbbreviation_Tebibytes"), factor: 1099511.627776),
            ConverterUnit(id: 100, name: L10n.string("UnitName_FloppyDisk"), abbreviation: L10n.string("UnitAbbreviation_FloppyDisk"), factor: 1.474560, isWhimsical: true),
            ConverterUnit(id: 101, name: L10n.string("UnitName_CD"), abbreviation: L10n.string("UnitAbbreviation_CD"), factor: 700, isWhimsical: true),
            ConverterUnit(id: 102, name: L10n.string("UnitName_DVD"), abbreviation: L10n.string("UnitAbbreviation_DVD"), factor: 4700, isWhimsical: true),
        ])

    // MARK: - 压强（基准：标准大气压）
    private static let pressureCategory = ConverterCategory(
        id: 10, name: L10n.string("CategoryName_PressureText"), supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 137, name: L10n.string("UnitName_Atmosphere"), abbreviation: L10n.string("UnitAbbreviation_Atmosphere"), factor: 1),
            ConverterUnit(id: 138, name: L10n.string("UnitName_Bar"), abbreviation: L10n.string("UnitAbbreviation_Bar"), factor: 0.9869232667160128),
            ConverterUnit(id: 139, name: L10n.string("UnitName_KiloPascal"), abbreviation: L10n.string("UnitAbbreviation_KiloPascal"), factor: 0.0098692326671601),
            ConverterUnit(id: 140, name: L10n.string("UnitName_MillimeterOfMercury"), abbreviation: L10n.string("UnitAbbreviation_MillimeterOfMercury"), factor: 0.0013155687145324),
            ConverterUnit(id: 141, name: L10n.string("UnitName_Pascal"), abbreviation: L10n.string("UnitAbbreviation_Pascal"), factor: 9.869232667160128e-6),
            ConverterUnit(id: 142, name: L10n.string("UnitName_PSI"), abbreviation: L10n.string("UnitAbbreviation_PSI"), factor: 0.068045961016531),
        ])

    // MARK: - 角度（基准：度）
    private static let angleCategory = ConverterCategory(
        id: 11, name: L10n.string("CategoryName_AngleText"), supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 134, name: L10n.string("UnitName_Degree"), abbreviation: L10n.string("UnitAbbreviation_Degree"), factor: 1),
            ConverterUnit(id: 135, name: L10n.string("UnitName_Radian"), abbreviation: L10n.string("UnitAbbreviation_Radian"), factor: 57.29577951308233),
            ConverterUnit(id: 136, name: L10n.string("UnitName_Gradian"), abbreviation: L10n.string("UnitAbbreviation_Gradian"), factor: 0.9),
        ])

    // MARK: - 能量（基准：焦耳）
    private static let energyCategory = ConverterCategory(
        id: 12, name: L10n.string("CategoryName_EnergyText"), supportsNegative: false, isTemperature: false,
        units: [
            ConverterUnit(id: 25, name: L10n.string("UnitName_Electron-Volt"), abbreviation: L10n.string("UnitAbbreviation_Electron-Volt"), factor: 1.602176565e-19),
            ConverterUnit(id: 27, name: L10n.string("UnitName_Joule"), abbreviation: L10n.string("UnitAbbreviation_Joule"), factor: 1),
            ConverterUnit(id: 26, name: L10n.string("UnitName_Foot-Pound"), abbreviation: L10n.string("UnitAbbreviation_Foot-Pound"), factor: 1.3558179483314),
            ConverterUnit(id: 24, name: L10n.string("UnitName_Calorie"), abbreviation: L10n.string("UnitAbbreviation_Calorie"), factor: 4.184),
            ConverterUnit(id: 29, name: L10n.string("UnitName_Kilojoule"), abbreviation: L10n.string("UnitAbbreviation_Kilojoule"), factor: 1000),
            ConverterUnit(id: 28, name: L10n.string("UnitName_Kilocalorie"), abbreviation: L10n.string("UnitAbbreviation_Kilocalorie"), factor: 4184),
            ConverterUnit(id: 23, name: L10n.string("UnitName_BritishThermalUnit"), abbreviation: L10n.string("UnitAbbreviation_BritishThermalUnit"), factor: 1055.056),
            ConverterUnit(id: 166, name: L10n.string("UnitName_Kilowatthour"), abbreviation: L10n.string("UnitAbbreviation_Kilowatthour"), factor: 3600000),
            ConverterUnit(id: 103, name: L10n.string("UnitName_Battery"), abbreviation: L10n.string("UnitAbbreviation_Battery"), factor: 9000, isWhimsical: true),
            ConverterUnit(id: 129, name: L10n.string("UnitName_Banana"), abbreviation: L10n.string("UnitAbbreviation_Banana"), factor: 439614, isWhimsical: true),
            ConverterUnit(id: 130, name: L10n.string("UnitName_SliceOfCake"), abbreviation: L10n.string("UnitAbbreviation_SliceOfCake"), factor: 1046700, isWhimsical: true),
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
