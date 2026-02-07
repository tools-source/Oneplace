import SwiftData
import SwiftUI

struct FlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FlowItem.nextDueDate) private var items: [FlowItem]

    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                upcomingSection
                timelineSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Flow")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                FlowItemEditor { item in
                    modelContext.insert(item)
                }
            }
        }
    }

    private var upcomingSection: some View {
        Section("Upcoming") {
            ForEach(items) { item in
                FlowRow(item: item)
            }
            .onDelete { indexSet in
                indexSet.map { items[$0] }.forEach(modelContext.delete)
            }
        }
    }

    private var timelineSection: some View {
        Section("Timeline") {
            ForEach(groupedByMonth.keys.sorted(by: >), id: \.self) { month in
                if let items = groupedByMonth[month] {
                    Section(header: Text(month, format: .dateTime.year().month())) {
                        ForEach(items) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                    Text(item.nextDueDate, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                    .font(.subheadline)
                                    .foregroundStyle(item.type == .income ? .green : .orange)
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupedByMonth: [Date: [FlowItem]] {
        Dictionary(grouping: items) { item in
            let components = Calendar.current.dateComponents([.year, .month], from: item.nextDueDate)
            return Calendar.current.date(from: components) ?? item.nextDueDate
        }
    }
}

private struct FlowRow: View {
    let item: FlowItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                Text("\(item.frequency.rawValue.capitalized) · \(item.status.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .foregroundStyle(item.type == .income ? .green : .orange)
                Text(item.nextDueDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FlowItemEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amount: Double = 0
    @State private var type: FlowType = .bill
    @State private var frequency: FlowFrequency = .monthly
    @State private var nextDueDate = Date()
    @State private var status: FlowStatus = .upcoming
    @State private var notes = ""

    let onSave: (FlowItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Type", selection: $type) {
                        ForEach(FlowType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized)
                        }
                    }
                    Picker("Frequency", selection: $frequency) {
                        ForEach(FlowFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.rawValue.capitalized)
                        }
                    }
                    DatePicker("Next Due", selection: $nextDueDate, displayedComponents: .date)
                    Picker("Status", selection: $status) {
                        ForEach(FlowStatus.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Flow Item")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let item = FlowItem(title: title, amount: amount, type: type, frequency: frequency, nextDueDate: nextDueDate, status: status, notes: notes.isEmpty ? nil : notes)
                        onSave(item)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    FlowView()
        .modelContainer(SampleData.makeContainer())
}
