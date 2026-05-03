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

## Archive notes

Firebase Firestore uses a binary Swift Package Manager build by default, and that can trigger Xcode Organizer warnings about missing dSYMs for `FirebaseFirestoreInternal`, `absl`, and `gRPC`.

To produce a clean distribution archive, open Xcode with `FIREBASE_SOURCE_FIRESTORE=1` set, or use the checked-in helper script:

```bash
./scripts/open-xcode-source-firestore.sh
./scripts/archive-source-firestore.sh
```

The helper keeps Firestore on the source-built path so Xcode can generate the expected debug symbols during archive.
