import Foundation

struct FinanceEntryRecord: Identifiable, Equatable {
    let id: String
    let ownerUserId: String
    var amount: Double
    var type: FinanceType
    var category: String
    var entryDescription: String
    var date: Date
    var urgency: FinanceUrgency
    var isCompleted: Bool
    var personName: String = ""
    var createdAt: Date? = nil
}

struct FinanceEntryDocument: Codable {
    enum CodingKeys: String, CodingKey {
        case amount, type, category, entryDescription, date, urgency, isCompleted, personName, createdAt
    }

    var amount: Double
    var type: String
    var category: String
    var entryDescription: String
    var date: Date
    var urgency: String
    var isCompleted: Bool
    var personName: String
    var createdAt: Date?

    init(record: FinanceEntryRecord) {
        amount = record.amount
        type = record.type.rawValue
        category = record.category
        entryDescription = record.entryDescription
        date = record.date
        urgency = record.urgency.rawValue
        isCompleted = record.isCompleted
        personName = record.personName
        createdAt = record.createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amount = try container.decode(Double.self, forKey: .amount)
        type = try container.decode(String.self, forKey: .type)
        category = try container.decode(String.self, forKey: .category)
        entryDescription = try container.decode(String.self, forKey: .entryDescription)
        date = try container.decode(Date.self, forKey: .date)
        urgency = try container.decode(String.self, forKey: .urgency)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        personName = try container.decodeIfPresent(String.self, forKey: .personName) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    func toRecord(id: String, ownerUserId: String) -> FinanceEntryRecord? {
        guard let entryType = FinanceType(rawValue: type),
              let entryUrgency = FinanceUrgency(rawValue: urgency) else {
            return nil
        }

        return FinanceEntryRecord(
            id: id,
            ownerUserId: ownerUserId,
            amount: amount,
            type: entryType,
            category: category,
            entryDescription: entryDescription,
            date: date,
            urgency: entryUrgency,
            isCompleted: isCompleted,
            personName: personName,
            createdAt: createdAt
        )
    }
}

/// Ordering and grouping are shared by the list and its regression checks.
enum FinanceEntryList {
    static func normalizedPersonName(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func newestFirst(_ lhs: FinanceEntryRecord, _ rhs: FinanceEntryRecord) -> Bool {
        // Legacy entries have no creation timestamp. Keep their date ordering,
        // while newly created entries always appear ahead of that legacy list.
        if (lhs.createdAt != nil) != (rhs.createdAt != nil) {
            return lhs.createdAt != nil
        }
        let leftDate = lhs.createdAt ?? lhs.date
        let rightDate = rhs.createdAt ?? rhs.date
        if leftDate != rightDate { return leftDate > rightDate }
        return lhs.id > rhs.id
    }

    static func ordered(_ entries: [FinanceEntryRecord], customOrderIDs: [String]) -> [FinanceEntryRecord] {
        let sorted = entries.sorted(by: newestFirst)
        let byID = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) })
        let savedIDs = Set(customOrderIDs)
        // New records must precede a previously saved manual order.
        return sorted.filter { !savedIDs.contains($0.id) } + customOrderIDs.compactMap { byID[$0] }
    }

    static func groups(in entries: [FinanceEntryRecord]) -> [FinancePersonGroup] {
        var groups: [FinancePersonGroup] = []
        var indices: [String: Int] = [:]
        for entry in entries {
            let name = normalizedPersonName(entry.personName)
            let key = name.lowercased()
            if let index = indices[key] {
                groups[index].entries.append(entry)
            } else {
                indices[key] = groups.count
                groups.append(FinancePersonGroup(id: key, name: name, entries: [entry]))
            }
        }
        return groups
    }
}

struct FinancePersonGroup: Identifiable {
    let id: String
    let name: String
    var entries: [FinanceEntryRecord]

    var openNet: Double {
        entries.filter { !$0.isCompleted }.reduce(0) { $0 + ($1.type == .gain ? $1.amount : -$1.amount) }
    }
}

/// Headers and transactions share one move collection, so edit handles can
/// cross person boundaries without ever making a header draggable.
enum FinanceListRow: Identifiable {
    case person(FinancePersonGroup)
    case transaction(FinanceEntryRecord)

    var id: String {
        switch self {
        case .person(let group): return "person-\(group.id)"
        case .transaction(let entry): return "transaction-\(entry.id)"
        }
    }
}

struct FinanceMoveTarget {
    let personName: String
    let beforeEntryID: String?
}

struct FinanceMovePlan {
    let entry: FinanceEntryRecord
    let orderedIDs: [String]
}

extension FinanceEntryList {
    static func moveTarget(rows: [FinanceListRow], source: Int, destination: Int) -> FinanceMoveTarget? {
        guard rows.indices.contains(source), (0...rows.count).contains(destination),
              case .transaction = rows[source] else { return nil }
        var remaining = rows
        remaining.remove(at: source)
        let insertion = destination > source ? destination - 1 : destination
        let previousGroups = remaining.prefix(insertion).compactMap { row -> FinancePersonGroup? in
            if case .person(let group) = row { return group }
            return nil
        }
        let firstGroup = remaining.compactMap { row -> FinancePersonGroup? in
            if case .person(let group) = row { return group }
            return nil
        }.first
        guard let group = previousGroups.last ?? firstGroup else { return nil }
        let followingEntry: FinanceEntryRecord?
        if insertion < remaining.count, case .transaction(let entry) = remaining[insertion] {
            followingEntry = entry
        } else if insertion == 0 {
            followingEntry = group.entries.first { candidate in
                if case .transaction(let moved) = rows[source] { return candidate.id != moved.id }
                return false
            }
        } else {
            followingEntry = nil
        }
        return FinanceMoveTarget(personName: group.name, beforeEntryID: followingEntry?.id)
    }

    static func move(entryID: String, to target: FinanceMoveTarget, entries: [FinanceEntryRecord], customOrderIDs: [String]) -> FinanceMovePlan? {
        guard var moved = entries.first(where: { $0.id == entryID }), target.beforeEntryID != entryID else { return nil }
        let destinationName = normalizedPersonName(target.personName)
        let destinationKey = destinationName.lowercased()
        var remaining = groups(in: ordered(entries, customOrderIDs: customOrderIDs))
            .flatMap(\.entries).filter { $0.id != entryID }
        let insertion: Int
        if let beforeID = target.beforeEntryID {
            guard let index = remaining.firstIndex(where: { $0.id == beforeID }),
                  normalizedPersonName(remaining[index].personName).lowercased() == destinationKey else { return nil }
            insertion = index
        } else {
            insertion = remaining.lastIndex(where: { normalizedPersonName($0.personName).lowercased() == destinationKey }).map { $0 + 1 } ?? remaining.count
        }
        moved.personName = destinationName
        remaining.insert(moved, at: insertion)
        return FinanceMovePlan(entry: moved, orderedIDs: remaining.map(\.id))
    }
}
