// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Right-side dock mirroring Views/HistoryList.xaml and Views/Memory.xaml
// (History / Memory pivot shown when the window is wide).

import SwiftUI

enum DockTab: String, CaseIterable, Identifiable {
    case history = "History"
    case memory = "Memory"

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
            .padding(8)

            switch tab {
            case .history:
                HistoryListView(model: model)
            case .memory:
                MemoryListView(model: model)
            }
        }
        .background(.thinMaterial)
    }
}

struct HistoryListView: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var body: some View {
        VStack(spacing: 0) {
            if model.historyItems.isEmpty {
                Text("There's no history yet.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
            } else {
                ScrollView {
                    LazyVStack(alignment: .trailing, spacing: 0) {
                        // 原版最新记录在顶部，这里反转列表使最新项先显示。
                        ForEach(model.historyItems.reversed()) { item in
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.expression)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text(item.result)
                                    .font(.system(size: 22, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button("Delete") {
                                    model.removeHistoryItem(item.id)
                                }
                            }
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button {
                        model.clearHistory()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear all history")
                    .padding(8)
                }
            }
        }
    }
}

struct MemoryListView: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var body: some View {
        VStack(spacing: 0) {
            if model.memorizedNumbers.isEmpty {
                Text("There's nothing saved in memory.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
            } else {
                ScrollView {
                    LazyVStack(alignment: .trailing, spacing: 0) {
                        ForEach(model.memorizedNumbers) { slot in
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(slot.value)
                                    .font(.system(size: 22, weight: .semibold))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                HStack(spacing: 2) {
                                    Spacer()
                                    slotButton("MC") { model.memoryClear(slot.id) }
                                    slotButton("M+") { model.memoryAdd(slot.id) }
                                    slotButton("M−") { model.memorySubtract(slot.id) }
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.memoryItemPressed(slot.id)
                            }
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button {
                        model.clearMemory()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear all memory")
                    .padding(8)
                }
            }
        }
    }

    private func slotButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11))
        }
        .buttonStyle(.bordered)
    }
}
