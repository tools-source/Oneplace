import Foundation

struct SplitExpenseDraft: Sendable {
    var title: String = ""
    var amount: Double = 0
    var date: Date = Date()
    var participantIds: [String] = []
    var paidById: String? = nil
}
