// FinanceCategory.swift
import Foundation

enum FinanceCategory: String, CaseIterable {
    // This enum exists primarily to centralize category names used by the UI.
    // We keep raw values as display names for convenience.
    case salary = "Salary"
    case freelance = "Freelance"
    case investments = "Investments"
    case otherIncome = "Other Income"

    case foodAndDining = "Food & Dining"
    case transport = "Transport"
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case healthcare = "Healthcare"
    case education = "Education"
    case billsAndUtilities = "Bills & Utilities"
    case otherExpense = "Other Expense"

    // Flat lists of display names used by pickers in FinanceView
    static let incomeRawValues: [String] = [
        FinanceCategory.salary.rawValue,
        FinanceCategory.freelance.rawValue,
        FinanceCategory.investments.rawValue,
        FinanceCategory.otherIncome.rawValue
    ]

    static let expenseRawValues: [String] = [
        FinanceCategory.foodAndDining.rawValue,
        FinanceCategory.transport.rawValue,
        FinanceCategory.shopping.rawValue,
        FinanceCategory.entertainment.rawValue,
        FinanceCategory.healthcare.rawValue,
        FinanceCategory.education.rawValue,
        FinanceCategory.billsAndUtilities.rawValue,
        FinanceCategory.otherExpense.rawValue
    ]
}
