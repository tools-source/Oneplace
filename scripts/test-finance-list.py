#!/usr/bin/env python3
"""Run pure Finance ordering, grouping, and document compatibility regressions."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
enums = (root / 'OnePlace/Models/FinanceEntry.swift').read_text().split('@Model')[0].replace('import SwiftData', '')
models = (root / 'OnePlace/Models/Firestore/FinanceEntryRecord.swift').read_text()
tests = r'''
func entry(_ id: String, person: String = "", amount: Double = 10, type: FinanceType = .gain, created: Double? = nil, date: Double = 100, completed: Bool = false) -> FinanceEntryRecord {
    FinanceEntryRecord(id: id, ownerUserId: "test", amount: amount, type: type,
        category: "Shopping", entryDescription: id, date: Date(timeIntervalSince1970: date),
        urgency: .medium, isCompleted: completed, personName: person,
        createdAt: created.map { Date(timeIntervalSince1970: $0) })
}
let macys = entry("macys", person: "Mom", amount: 120, created: 200)
let amazon = entry("amazon", person: " mom ", amount: 40, created: 300, date: 1)
let dad = entry("dad", person: "Dad", created: 250)
let legacy = entry("legacy", date: 99999)
let input = [macys, legacy, dad, amazon]
let sorted = FinanceEntryList.ordered(input, customOrderIDs: [])
precondition(sorted.map(\.id) == ["amazon", "dad", "macys", "legacy"], "Creation order must win over transaction dates")
let groups = FinanceEntryList.groups(in: sorted)
precondition(groups.map(\.id) == ["mom", "dad", ""])
precondition(groups[0].entries.map(\.id) == ["amazon", "macys"])
precondition(groups[0].openNet == 160)

let custom = FinanceEntryList.ordered(input, customOrderIDs: ["dad", "macys", "legacy", "deleted"])
precondition(custom.map(\.id) == ["amazon", "dad", "macys", "legacy"], "New item must precede existing manual ordering")
precondition(FinanceEntryList.groups(in: custom)[0].id == "mom", "New item's group must move first")
let refreshed = FinanceEntryList.ordered(Array(input.reversed()), customOrderIDs: ["dad", "macys", "legacy"])
precondition(refreshed.map(\.id) == custom.map(\.id), "Refresh must retain new-first ordering")

let mixed = FinanceEntryList.groups(in: [macys, entry("repayment", person: "MOM", amount: 30, type: .owe), entry("done", person: "Mom", amount: 500, completed: true)])
precondition(mixed.count == 1 && mixed[0].openNet == 90, "Only open directional balances count")
let unassigned = FinanceEntryList.groups(in: [entry("a"), entry("b", person: "  \n ")])
precondition(unassigned.count == 1 && unassigned[0].name.isEmpty)
precondition(FinanceEntryList.normalizedPersonName("  Mary   Jane \n") == "Mary Jane")

let encoder = JSONEncoder()
let decoder = JSONDecoder()
let data = try encoder.encode(FinanceEntryDocument(record: amazon))
let roundTrip = try decoder.decode(FinanceEntryDocument.self, from: data).toRecord(id: amazon.id, ownerUserId: amazon.ownerUserId)
precondition(roundTrip == amazon, "Person and creation time must survive document round trips")
var legacyJSON = try JSONSerialization.jsonObject(with: data) as! [String: Any]
legacyJSON.removeValue(forKey: "personName")
legacyJSON.removeValue(forKey: "createdAt")
legacyJSON.removeValue(forKey: "isCompleted")
let oldDocument = try decoder.decode(FinanceEntryDocument.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
precondition(oldDocument.personName == "" && oldDocument.createdAt == nil && !oldDocument.isCompleted)

let others = FinancePersonGroup(id: "", name: "", entries: [legacy])
let mom = FinancePersonGroup(id: "mom", name: "Mom", entries: [amazon, macys])
let rows: [FinanceListRow] = [.person(others), .transaction(legacy), .person(mom), .transaction(amazon), .transaction(macys)]
let destination = FinanceEntryList.moveTarget(rows: rows, source: 1, destination: 3)!
precondition(destination.personName == "Mom" && destination.beforeEntryID == "amazon")
let moved = FinanceEntryList.move(entryID: legacy.id, to: destination, entries: input, customOrderIDs: [])!
precondition(moved.entry.personName == "Mom")
precondition(moved.entry.amount == legacy.amount && moved.entry.type == legacy.type && moved.entry.createdAt == legacy.createdAt && moved.entry.date == legacy.date)
let movedEntries = input.map { $0.id == moved.entry.id ? moved.entry : $0 }
let movedGroups = FinanceEntryList.groups(in: FinanceEntryList.ordered(movedEntries, customOrderIDs: moved.orderedIDs))
precondition(movedGroups.first(where: { $0.id == "mom" })!.entries.map(\.id) == ["legacy", "amazon", "macys"])
let persistedMove = try decoder.decode(FinanceEntryDocument.self, from: encoder.encode(FinanceEntryDocument(record: moved.entry)))
precondition(persistedMove.personName == "Mom")
let backTarget = FinanceEntryList.moveTarget(rows: rows, source: 3, destination: 1)!
precondition(backTarget.personName.isEmpty && backTarget.beforeEntryID == "legacy")
let back = FinanceEntryList.move(entryID: amazon.id, to: backTarget, entries: input, customOrderIDs: [])!
precondition(back.entry.personName.isEmpty && Set(back.orderedIDs) == Set(input.map(\.id)))
let emptyRows: [FinanceListRow] = [.person(mom), .transaction(amazon), .transaction(macys), .person(FinancePersonGroup(id: "", name: "", entries: []))]
let emptyTarget = FinanceEntryList.moveTarget(rows: emptyRows, source: 1, destination: 4)!
precondition(emptyTarget.personName.isEmpty && emptyTarget.beforeEntryID == nil)
let reorderTarget = FinanceEntryList.moveTarget(rows: rows, source: 3, destination: 5)!
let reordered = FinanceEntryList.move(entryID: amazon.id, to: reorderTarget, entries: input, customOrderIDs: [])!
let reorderedIDs = reordered.orderedIDs.filter { ["amazon", "macys"].contains($0) }
precondition(reordered.entry.personName == "Mom" && reorderedIDs == ["macys", "amazon"])
precondition(FinanceEntryList.moveTarget(rows: rows, source: 0, destination: 3) == nil, "Headers cannot move")
precondition(FinanceEntryList.moveTarget(rows: rows, source: 20, destination: 3) == nil)
precondition(FinanceEntryList.move(entryID: "missing", to: destination, entries: input, customOrderIDs: []) == nil)
precondition(FinanceEntryList.move(entryID: legacy.id, to: FinanceMoveTarget(personName: "Dad", beforeEntryID: "macys"), entries: input, customOrderIDs: []) == nil)
print("PASS: new-first order, manual ordering, refresh, person grouping, balances, unnamed entries, document round trip, legacy compatibility, cross-person moves, reverse moves, empty targets, within-group reorder, invalid drops")
'''
with tempfile.TemporaryDirectory(prefix='oneplace-finance-tests-') as directory:
    source = Path(directory) / 'FinanceTests.swift'
    binary = Path(directory) / 'FinanceTests'
    source.write_text(enums + models + tests)
    sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
    subprocess.run(['xcrun', 'swiftc', '-sdk', sdk, str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
