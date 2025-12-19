---
description: General project-wide rules.
alwaysApply: true
---
Comment frequently with simple and direct language. Comments should concisely spell out what EVERY PART OF THE CODE is doing, being easy to read and understand. Use clear grammar. Avoid any special headers or decorative markers. Do not use comments made of symbols or any section labels.

UI must be replaceable. Views and view models may only handle presentation (layout, formatting for display, user input, navigation state). They must not contain persistence logic, file access, data format logic, or “business rules.” All core operations must live in non-UI types and be exposed through a small, stable API (protocol/service). UI code must depend on that API and plain Swift data types, not on file paths or storage details.

Keep responsibilities separate. UI code should only manage presentation and user interaction. Data and storage code should live outside UI types. File-system access must be centralized in one place, not scattered across views, view models, or helpers.

Keep data formats stable. Any on-disk format must include a version field. Treat the on-disk format as a contract: changes must be backward compatible when possible, and must fail gracefully when not. Never crash because a file is missing, malformed, or from a newer version; return a clear error and keep the app usable.

Write files safely. Never overwrite important files directly. Use atomic write patterns: write to a temporary file in the same folder and then replace. If multiple files must stay consistent, write the payload/data first, then update the index/metadata file second, so metadata never points to missing data.

Do not block the main thread. All disk I/O and expensive work must run off the main thread. UI state updates must happen on the main thread. Prefer structured concurrency (async/await). Ensure storage operations are serialized so concurrent saves do not race (for example, by using an actor or another single-writer design).

Make errors explicit. Do not use force unwrap (`!`), `try!`, `fatalError`, or assertions for normal runtime situations. Use `throws` and return errors to the UI layer so they can be shown as a simple message. Log errors with enough context to debug, but avoid noisy logging in normal operation.

Prefer simple, testable types. Use `Codable` structs for persisted data. Avoid hidden global state. Pass dependencies in (for example, a base folder URL, clocks, or UUID generators) so code is easy to test and change. Keep functions small and focused.

Protect user data. Never delete or overwrite user data without an explicit, intentional action. When deleting, confirm the correct item is being deleted. When renaming or updating metadata, keep stable identifiers stable.

Keep the codebase consistent. Always run `swift format --in-place --recursive .` on changes. Always run SwiftLint and fix violations until it passes. Avoid broad rule disables; if an exception is necessary, keep it narrow and add a short reason.

Prefer incremental, reversible changes. Keep commits small. Avoid “big refactors” mixed with behavior changes. Remove debug-only code before committing. Do not commit generated artifacts unless the project explicitly requires it.

Design for growth without overbuilding. Start with the simplest implementation that meets the current requirement, but keep extension points where formats, storage, or performance might evolve later (versioning, clear boundaries, centralized I/O, and safe writes).