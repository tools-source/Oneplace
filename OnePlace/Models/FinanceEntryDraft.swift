import Foundation

struct FinanceEntryDraft {
    var amount: Double
    var type: FinanceType
    var category: String
    var entryDescription: String
    var date: Date
    var urgency: FinanceUrgency
}
