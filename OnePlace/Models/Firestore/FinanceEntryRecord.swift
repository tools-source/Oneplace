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
}

struct FinanceEntryDocument: Codable {
    enum CodingKeys: String, CodingKey {
        case amount, type, category, entryDescription, date, urgency, isCompleted
    }

    var amount: Double
    var type: String
    var category: String
    var entryDescription: String
    var date: Date
    var urgency: String
    var isCompleted: Bool

    init(record: FinanceEntryRecord) {
        amount = record.amount
        type = record.type.rawValue
        category = record.category
        entryDescription = record.entryDescription
        date = record.date
        urgency = record.urgency.rawValue
        isCompleted = record.isCompleted
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
            isCompleted: isCompleted
        )
    }
}
