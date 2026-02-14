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
}

struct FinanceEntryDocument: Codable {
    var amount: Double
    var type: String
    var category: String
    var entryDescription: String
    var date: Date
    var urgency: String

    init(record: FinanceEntryRecord) {
        amount = record.amount
        type = record.type.rawValue
        category = record.category
        entryDescription = record.entryDescription
        date = record.date
        urgency = record.urgency.rawValue
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
            urgency: entryUrgency
        )
    }
}
