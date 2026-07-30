// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Swift 重写 src/CalcViewModel/DateCalculatorViewModel.cpp + Common/DateCalculator.cpp。
// 原版依赖 Windows.Globalization.Calendar 做日历感知的日期运算；macOS 直接用
// Foundation.Calendar / DateComponents，语义等价：
//   - 日期差：先算「年」，再算「月」，剩余天数拆成「周 + 天」（对应原版逐单位逼近）；
//     另给一个纯天数结果，两日期同天或仅差天数时只显示一个结果。
//   - 加减日期：起始日 ± (年, 月, 天) 偏移。
// 偏移上限沿用原版 c_maxOffsetValue = 999。

import Foundation

@MainActor
final class DateCalculatorViewModel: ObservableObject {
    /// 日期差 / 加减日期 两种子模式（对应原版 IsDateDiffMode）。
    @Published var isDateDiffMode = true

    // 日期差模式
    @Published var fromDate = Calendar.current.startOfDay(for: Date())
    @Published var toDate = Calendar.current.startOfDay(for: Date())

    // 加减日期模式
    /// true=加，false=减（对应原版 IsAddMode）。
    @Published var isAddMode = true
    @Published var startDate = Calendar.current.startOfDay(for: Date())
    @Published var yearsOffset = 0
    @Published var monthsOffset = 0
    @Published var daysOffset = 0

    /// 偏移量上限（对应原版 c_maxOffsetValue）。
    let maxOffset = 999

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }

    // MARK: - 日期差结果

    /// 完整差值：X 年 Y 个月 Z 周 W 天（对应原版 StrDateDiffResult）。
    var dateDiffResult: String {
        let start = calendar.startOfDay(for: min(fromDate, toDate))
        let end = calendar.startOfDay(for: max(fromDate, toDate))
        let comps = calendar.dateComponents([.year, .month, .day], from: start, to: end)
        let years = comps.year ?? 0
        let months = comps.month ?? 0
        let trailingDays = comps.day ?? 0
        let weeks = trailingDays / 7
        let days = trailingDays % 7

        var parts: [String] = []
        if years != 0 { parts.append(L10n.format("Mac_Date_YearsPart", "\(years)")) }
        if months != 0 { parts.append(L10n.format("Mac_Date_MonthsPart", "\(months)")) }
        if weeks != 0 { parts.append(L10n.format("Mac_Date_WeeksPart", "\(weeks)")) }
        if days != 0 { parts.append(L10n.format("Mac_Date_DaysPart", "\(days)")) }
        if parts.isEmpty { return L10n.string("Mac_Date_SameDates") }
        return parts.joined(separator: " ")
    }

    /// 纯天数结果（对应原版 StrDateDiffResultInDays）。
    var dateDiffResultInDays: String {
        let start = calendar.startOfDay(for: min(fromDate, toDate))
        let end = calendar.startOfDay(for: max(fromDate, toDate))
        let totalDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return L10n.format("Mac_Date_DaysPart", "\(totalDays)")
    }

    /// 差值是否只有天数（此时只显示一个结果，避免冗余；对应原版 IsDiffInDays）。
    var isDiffInDays: Bool {
        let start = calendar.startOfDay(for: min(fromDate, toDate))
        let end = calendar.startOfDay(for: max(fromDate, toDate))
        let comps = calendar.dateComponents([.year, .month, .day], from: start, to: end)
        return (comps.year ?? 0) == 0 && (comps.month ?? 0) == 0
    }

    // MARK: - 加减日期结果

    /// 结果日期，越界时为 nil（对应原版 StrDateResult / IsOutOfBound）。
    var dateResult: Date? {
        let sign = isAddMode ? 1 : -1
        var comps = DateComponents()
        comps.year = sign * yearsOffset
        comps.month = sign * monthsOffset
        comps.day = sign * daysOffset
        return calendar.date(byAdding: comps, to: calendar.startOfDay(for: startDate))
    }

    /// 结果日期的本地化长格式字符串。
    var dateResultString: String {
        guard let result = dateResult else { return L10n.string("Mac_Date_OutOfRange") }
        return Self.longDateFormatter.string(from: result)
    }

    static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()
}
