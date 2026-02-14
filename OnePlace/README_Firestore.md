# Firestore persistence notes

## Finance schema
Finance tab data now lives under each authenticated user document:

- `users/{uid}`
  - `finance` (collection)
    - `entries` (document)
      - `transactions` (collection)
        - `{entryId}` (document)

Each finance transaction document stores fields inferred from `FinanceEntry`:

- `amount: Double`
- `type: String` (`gain` or `owe`)
- `category: String`
- `entryDescription: String`
- `date: Timestamp`
- `urgency: String` (`low`, `medium`, `high`)

The same repository pattern can be reused for other tabs by swapping the tab collection path under `users/{uid}/...`.
