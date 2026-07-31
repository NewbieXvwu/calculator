// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 右侧停靠面板，对应 Views/HistoryList.xaml 与 Views/Memory.xaml
// （原版窗口足够宽时显示的 History / Memory pivot）。
// 视觉换成 macOS 原生：毛玻璃由窗口底材提供，此处只做语义分层填充与系统空态。

import SwiftUI

enum DockTab: String, CaseIterable, Identifiable {
    case history
    case memory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: return L10n.string("HistoryLabel.Text")
        case .memory: return L10n.string("MemoryLabel.Text")
        }
    }
}

struct HistoryMemoryPanel: View {
    let model: StandardCalculatorViewModel
    @State private var tab: DockTab = .history

    /// 程序员模式无历史（原版引擎该模式不持有 CalculatorHistory）。
    private var availableTabs: [DockTab] {
        model.mode == .programmer ? [.memory] : DockTab.allCases
    }

    private var effectiveTab: DockTab {
        availableTabs.contains(tab) ? tab : .memory
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(availableTabs) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)

            switch effectiveTab {
            case .history:
                HistoryListView(model: model)
            case .memory:
                MemoryListView(model: model)
            }
        }
    }
}

struct HistoryListView: View {
    let model: StandardCalculatorViewModel

    var body: some View {
        VStack(spacing: 0) {
            if model.historyItems.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey(L10n.string("Mac_NoHistory")),
                    systemImage: AppIcon.historyEmpty.sfSymbol,
                    description: Text(L10n.string("Mac_NoHistoryDesc"))
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .trailing, spacing: 2) {
                        // 原版最新记录在顶部，这里反转列表使最新项先显示。
                        ForEach(model.historyItems.reversed()) { item in
                            HistoryRow(item: item) {
                                model.removeHistoryItem(item.id)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .softTopScrollEdge()
                HStack {
                    Spacer()
                    Button {
                        model.clearHistory()
                    } label: {
                        Image(systemName: AppIcon.itemDelete.sfSymbol)
                    }
                    .buttonStyle(.borderless)
                    .help(L10n.string("Mac_ClearAllHistory"))
                    .padding(8)
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(item.expression)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(item.result)
                .font(.system(size: 20, weight: .regular))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(hovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button(L10n.string("DeleteHistoryMenuItem.Text")) { onDelete() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.format("Mac_HistoryItemA11y", item.expression, item.result))
        .accessibilityAction(named: Text(L10n.string("DeleteHistoryMenuItem.Text"))) { onDelete() }
    }
}

struct MemoryListView: View {
    let model: StandardCalculatorViewModel

    var body: some View {
        VStack(spacing: 0) {
            if model.memorizedNumbers.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey(L10n.string("Mac_NoMemory")),
                    systemImage: AppIcon.memoryEmpty.sfSymbol,
                    description: Text(L10n.string("Mac_NoMemoryDesc"))
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .trailing, spacing: 2) {
                        ForEach(model.memorizedNumbers) { slot in
                            MemoryRow(slot: slot, model: model)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .softTopScrollEdge()
                HStack {
                    Spacer()
                    Button {
                        model.clearMemory()
                    } label: {
                        Image(systemName: AppIcon.itemDelete.sfSymbol)
                    }
                    .buttonStyle(.borderless)
                    .help(L10n.string("Mac_ClearAllMemory"))
                    .padding(8)
                }
            }
        }
    }
}

private struct MemoryRow: View {
    let slot: MemorySlot
    let model: StandardCalculatorViewModel

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(slot.value)
                .font(.system(size: 20, weight: .regular))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
            // 原版悬停时才显示每条目的 MC/M+/M− 按钮。
            if hovering {
                HStack(spacing: 2) {
                    Spacer()
                    slotButton("MC") { model.memoryClear(slot.id) }
                    slotButton("M+") { model.memoryAdd(slot.id) }
                    slotButton("M−") { model.memorySubtract(slot.id) }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(minHeight: 58, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(hovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            model.memoryItemPressed(slot.id)
        }
    }

    private func slotButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
