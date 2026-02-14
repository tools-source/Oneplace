import SwiftUI
import UIKit

struct FinanceView: View {
    @StateObject private var vm = FinanceViewModel()
    @State private var showingAdd = false
    @State private var editingEntry: FinanceEntryRecord?
    @State private var searchText = ""

    private var filteredEntries: [FinanceEntryRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return vm.entries }

        return vm.entries.filter { entry in
            entry.category.localizedCaseInsensitiveContains(query)
            || entry.entryDescription.localizedCaseInsensitiveContains(query)
            || entry.type.rawValue.localizedCaseInsensitiveContains(query)
            || entry.urgency.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    private var gainTotal: Double {
        vm.entries
            .filter { $0.type == .gain }
            .reduce(0) { $0 + $1.amount }
    }

    private var oweTotal: Double {
        vm.entries
            .filter { $0.type == .owe }
            .reduce(0) { $0 + $1.amount }
    }

    private var netTotal: Double {
        gainTotal - oweTotal
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryCards
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                }

                Section {
                    if vm.isLoading && vm.entries.isEmpty {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else if filteredEntries.isEmpty {
                        EmptyState(
                            title: "No transactions yet",
                            message: "Tap Add Transaction to create your first entry.",
                            systemImage: "tray",
                            ctaTitle: "Add Transaction"
                        ) {
                            showingAdd = true
                        }
                        .padding(.vertical, 24)
                    } else {
                        ForEach(filteredEntries) { entry in
                            transactionRow(for: entry)
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Finance")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search transactions")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .task { await vm.refresh() }
            .refreshable { await vm.refresh() }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.clearError() }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .sheet(isPresented: $showingAdd) {
                AddFinanceEntryView { draft in
                    Task { await vm.addEntry(draft: draft) }
                    showingAdd = false
                }
            }
            .sheet(item: $editingEntry) { entry in
                AddFinanceEntryView(entry: entry) { draft in
                    let updated = FinanceEntryRecord(
                        id: entry.id,
                        ownerUserId: entry.ownerUserId,
                        amount: draft.amount,
                        type: draft.type,
                        category: draft.category,
                        entryDescription: draft.entryDescription,
                        date: draft.date,
                        urgency: draft.urgency,
                        isCompleted: entry.isCompleted
                    )
                    Task { await vm.updateEntry(updated) }
                    editingEntry = nil
                }
            }
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            AppCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        FinanceTypeBadge(netTotal: netTotal)
                        Text("Net")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.secondaryTextColor)
                        Spacer(minLength: 0)
                    }

                    Text(StatCard.currencyString(for: netTotal))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .frame(minHeight: 72, alignment: .leading)
            }

            AppCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        FinanceTypeBadge(type: .gain)
                        Text("Gain")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.secondaryTextColor)
                        Spacer(minLength: 0)
                    }

                    Text(StatCard.currencyString(for: gainTotal))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.green)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .frame(minHeight: 72, alignment: .leading)
            }

            AppCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        FinanceTypeBadge(type: .owe)
                        Text("Owe")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.secondaryTextColor)
                        Spacer(minLength: 0)
                    }

                    Text(StatCard.currencyString(for: oweTotal))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.red)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .frame(minHeight: 72, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func transactionRow(for entry: FinanceEntryRecord) -> some View {
        let trimmedDescription = entry.entryDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDescription = !trimmedDescription.isEmpty

        AppCard {
            HStack(alignment: .center, spacing: 12) {
                FinanceTypeBadge(type: entry.type)
                    .padding(.leading, 0)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(hasDescription ? trimmedDescription : entry.category)
                            .font(.headline)
                            .strikethrough(entry.isCompleted)
                            .foregroundStyle(entry.isCompleted ? .secondary : .primary)
                            .lineLimit(1)

                        if entry.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .transition(.opacity)
                        }
                    }

                    if hasDescription {
                        Text(entry.category)
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.secondaryTextColor)
                            .lineLimit(1)
                    } else {
                        Text("No description")
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.secondaryTextColor)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(StatCard.currencyString(for: entry.amount))
                    .font(.headline)
                    .foregroundStyle(entry.type == .gain ? .green : .red)
                    .monospacedDigit()
            }
            .opacity(entry.isCompleted ? 0.78 : 1)
            .animation(.easeInOut(duration: 0.18), value: entry.isCompleted)
        }
        .contextMenu {
            Button {
                triggerLightHaptic()
                Task { await vm.toggleCompletion(for: entry) }
            } label: {
                Label(entry.isCompleted ? "Mark Undone" : "Mark Complete", systemImage: entry.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }

            Button {
                editingEntry = entry
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                triggerLightHaptic()
                Task { await vm.deleteEntry(entry) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                triggerLightHaptic()
                Task { await vm.toggleCompletion(for: entry) }
            } label: {
                Label(entry.isCompleted ? "Undo" : "Complete", systemImage: entry.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                editingEntry = entry
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)

            Button(role: .destructive) {
                triggerLightHaptic()
                Task { await vm.deleteEntry(entry) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func triggerLightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
