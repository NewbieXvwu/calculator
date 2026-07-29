// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 右侧停靠面板，对应 Views/HistoryList.xaml 与 Views/Memory.xaml
// （原版窗口足够宽时显示的 History / Memory pivot）。
// 视觉换成 macOS 原生：毛玻璃由窗口背景提供，此处仅做半透明分层。

import SwiftUI

enum DockTab: String, CaseIterable, Identifiable {
    case history = "历史记录"
    case memory = "内存"

    var id: String { rawValue }
}

struct HistoryMemoryPanel: View {
    @ObservedObject var model: StandardCalculatorViewModel
    @State private var tab: DockTab = .history

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(DockTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)

            switch tab {
            case .history:
                HistoryListView(model: model)
            case .memory:
                MemoryListView(model: model)
            }
        }
        .background(Color.primary.opacity(0.03))
    }
}

struct HistoryListView: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var body: some View {
        VStack(spacing: 0) {
            if model.historyItems.isEmpty {
                Text("尚无历史记录")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
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
                HStack {
                    Spacer()
                    Button {
                        model.clearHistory()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("清除所有历史记录")
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
                .font(.system(size: 20, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.06 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button("删除") { onDelete() }
        }
    }
}

struct MemoryListView: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var body: some View {
        VStack(spacing: 0) {
            if model.memorizedNumbers.isEmpty {
                Text("内存中没有内容")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
            } else {
                ScrollView {
                    LazyVStack(alignment: .trailing, spacing: 2) {
                        ForEach(model.memorizedNumbers) { slot in
                            MemoryRow(slot: slot, model: model)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                HStack {
                    Spacer()
                    Button {
                        model.clearMemory()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("清除所有内存")
                    .padding(8)
                }
            }
        }
    }
}

private struct MemoryRow: View {
    let slot: MemorySlot
    @ObservedObject var model: StandardCalculatorViewModel

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(slot.value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
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
                .fill(Color.primary.opacity(hovering ? 0.06 : 0))
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
