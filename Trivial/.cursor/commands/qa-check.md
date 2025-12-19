# qa-check

Run this routine in this order: format → lint → build

1) Format Swift code (only this command)
- Run: `swift format --in-place --recursive .`

2) Lint (SwiftLint) and fix ALL violations
- Run: `swiftlint`

- If there are violations:
  a) If any are autocorrectable, run: `swiftlint autocorrect`
  b) Then run: `swiftlint` again
  c) For any remaining violations, fix them manually in code and rerun: `swiftlint`
  d) Repeat until `swiftlint` passes with zero violations.

- Only if a rule is genuinely wrong for this project:
  - Disable it in `.swiftlint.yml` (preferred) or with an inline comment like `// swiftlint:disable:next RuleName`.
  - Add a short comment explaining why.
  - Rerun `swiftlint` to confirm it is clean.

3) Build (catch compile/config errors)
- Run: `xcodebuild -list`
- Pick the scheme that matches the app (usually the same name as the project/app).
- Run: `xcrun simctl list devices available`
- Pick an iPad simulator name that exists (for example, “iPad A16” or similar).
- Run (replace placeholders):
  - `xcodebuild build -scheme "<SCHEME>" -destination 'platform=iOS Simulator,name=<iPad Simulator Name>'`

- If the build fails:
  - Read the first real error line that starts with `error:` (warnings don’t stop the build).
  - Fix that issue and rerun the same `xcodebuild build ...` command until it succeeds.
