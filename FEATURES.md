# ExpenseTrackerApp Features

## App Overview

ExpenseTrackerApp is a Flutter expense tracking app for recording daily spending, reviewing totals, and keeping expense data available after reopening the app.

## Current Features

- Home welcome page shown first when the app opens.
- Vertical slide-up navigation from the home page to the current expense process page.
- Sky blue Material 3 theme.
- App display name set to `ExpenseTrackerApp` for browser tab and installed app name.
- Add new expense with title, integer amount, category, date, and optional note.
- Amount input accepts integer numbers only.
- Edit existing expense data.
- Delete expenses using the delete button.
- Swipe expense row to delete.
- Undo recently deleted expense from the snackbar.
- Floating modern success notification after creating or updating an expense.
- Expense data is saved locally using `shared_preferences`.
- Saved expenses are loaded again when the app is reopened.
- Dashboard total spent summary.
- Today expense summary.
- Expense record count summary.
- Daily, monthly, and yearly report tabs.
- Report rows show total amount and expense count.
- Category breakdown with progress bars.
- Category filter chips.
- Empty state when no expenses exist.
- Currency amounts display without `.00`, for example `$45`.

## Expense Categories

- Food
- Transport
- Shopping
- Bills
- Health
- Leisure
- Work

## Build Notes

- Android app label is configured as `ExpenseTrackerApp`.
- Web title and manifest name are configured as `ExpenseTrackerApp`.
- Kotlin incremental compilation is disabled in `android/gradle.properties` to avoid corrupted Kotlin cache build errors.
- Release APK build command:

```bash
flutter build apk --release
```

## Main Files

- `lib/main.dart` - Main app UI, expense model, reports, persistence, and interactions.
- `test/widget_test.dart` - Widget test for the main app flow.
- `pubspec.yaml` - Project dependencies, including `shared_preferences`.
