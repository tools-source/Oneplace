import Foundation

struct SplitPersonRecord: Identifiable, Equatable {
    let id: String
    let ownerUserId: String
    var name: String
    var manualOrder: Double?
}

struct SplitExpenseRecord: Identifiable, Equatable {
    let id: String
    let ownerUserId: String
    var title: String
    var amount: Double
    var date: Date
    var participantIds: [String]  // IDs of SplitPersonRecord
    var paidById: String?  // ID of SplitPersonRecord who paid
}

struct SplitBalanceRecord: Identifiable, Equatable {
    let id: String
    let ownerUserId: String
    let personId: String
    var balance: Double
}
