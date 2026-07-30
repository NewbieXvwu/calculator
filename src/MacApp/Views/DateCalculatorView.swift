// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 排版对照 Views/DateCalculator.xaml：
//   顶栏（历史圆钮 + 模式菜单，与其它模式共用 CalculatorHeader）
//   模式选择（日期差 / 加减日期，对应原版顶部 ComboBox）
//   日期差：起始日期选择器 + 结束日期选择器 → 差值结果 + 纯天数结果
//   加减日期：起始日期 + 加/减分段 + 年/月/日 步进 → 结果日期
// 视觉沿用 macOS 原生控件；结果区为内容层（不加玻璃）。

import SwiftUI

struct DateCalculatorView: View {
    @ObservedObject var model: StandardCalculatorViewModel
    @StateObject private var dateModel = DateCalculatorViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $dateModel.isDateDiffMode) {
                Text(L10n.string("Mac_Date_Difference")).tag(true)
                Text(L10n.string("Mac_Date_AddSubtract")).tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)

            ScrollView {
                if dateModel.isDateDiffMode {
                    dateDiffSection
                } else {
                    addSubtractSection
                }
            }

            Spacer(minLength: 0)
        }
        .calculatorKeyMonitor(model: model)
    }

    // MARK: - 日期差

    private var dateDiffSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            labeledPicker(L10n.string("DateDiff_FromHeader.Header"), selection: $dateModel.fromDate)
            labeledPicker(L10n.string("DateDiff_ToHeader.Header"), selection: $dateModel.toDate)

            resultCard {
                if dateModel.isDiffInDays {
                    resultLine(dateModel.dateDiffResultInDays)
                } else {
                    resultLine(dateModel.dateDiffResult)
                    Divider()
                    resultLine(dateModel.dateDiffResultInDays, secondary: true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - 加减日期

    private var addSubtractSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            labeledPicker(L10n.string("DateDiff_FromHeader.Header"), selection: $dateModel.startDate)

            Picker("", selection: $dateModel.isAddMode) {
                Text(L10n.string("Mac_Date_Add")).tag(true)
                Text(L10n.string("Mac_Date_Subtract")).tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            offsetStepper(L10n.string("Mac_Date_Years"), value: $dateModel.yearsOffset)
            offsetStepper(L10n.string("Mac_Date_Months"), value: $dateModel.monthsOffset)
            offsetStepper(L10n.string("Mac_Date_Days"), value: $dateModel.daysOffset)

            resultCard {
                Text(L10n.string("Mac_Date_ResultDate"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                resultLine(dateModel.dateResultString)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - 复用小组件

    private func labeledPicker(_ title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            DatePicker("", selection: selection, displayedComponents: .date)
                .datePickerStyle(.field)
                .labelsHidden()
        }
    }

    private func offsetStepper(_ title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .frame(width: 32, alignment: .leading)
            Stepper(value: value, in: 0...dateModel.maxOffset) {
                Text("\(value.wrappedValue)")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
        }
    }

    private func resultCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func resultLine(_ text: String, secondary: Bool = false) -> some View {
        Text(text)
            .font(.system(size: secondary ? 15 : 20, weight: secondary ? .regular : .semibold))
            .foregroundStyle(secondary ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .accessibilityLabel(text)
    }
}
