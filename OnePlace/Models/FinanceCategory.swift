import Foundation

enum FinanceCategory: String, CaseIterable, Codable {
    case salary = "Salary"
    case freelance = "Freelance"
    case investments = "Investments"
    case otherIncome = "Other Income"
    case foodDining = "Food & Dining"
    case shopping = "Shopping"
    case transport = "Transport"
    case billsUtilities = "Bills & Utilities"
    case entertainment = "Entertainment"
    case healthcare = "Healthcare"
    case education = "Education"
    case otherExpense = "Other Expense"

    static let income: [FinanceCategory] = [
        .salary,
        .freelance,
        .investments,
        .otherIncome
    ]

    static let expense: [FinanceCategory] = [
        .foodDining,
        .shopping,
        .transport,
        .billsUtilities,
        .entertainment,
        .healthcare,
        .education,
        .otherExpense
    ]

    static let incomeRawValues = income.map(\.rawValue)
    static let expenseRawValues = expense.map(\.rawValue)
}
