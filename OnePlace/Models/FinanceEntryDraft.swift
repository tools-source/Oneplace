import Foundation

struct FinanceEntryDraft: Equatable {
    var amount: Double
    var type: FinanceType
    var category: String
    var entryDescription: String
    var date: Date
    var urgency: FinanceUrgency
    var personName: String = ""
}
