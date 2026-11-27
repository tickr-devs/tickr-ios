# tickr-ios: rules for agents

The Tickr operator apps for macOS, iOS and iPadOS (one SwiftUI codebase, shared package
`apps/shared`). They show and command the Tickr bot through its API; they never talk to a broker.
The bot, its API and the contract live in `tickr-devs/tickr-bot`.

## Hard rules (never break, never "temporarily")

1. **Secrets are never read, printed, logged or committed.** Code handles credential variable NAMES and presence only. `.env`, tokens and account ids never enter the repo or logs.
2. **Never print the process environment; screenshot/test tools pass only named variables.** Its output holds credential values. Never run `env`, `printenv`, `export -p`, a bare `set`, `xctest --help` or `xcodebuild -showBuildSettings`, never trace a shell that sees a secret (`set -x`), never print, log, stringify or iterate `os.environ` whole, and in Swift read `ProcessInfo.processInfo.environment` one named variable at a time (never bind, print or forward the dictionary). Messages name a missing variable, never its value. `tests/test_no_env_dumps.py` enforces this for scripts, workflows and Python/Swift code; a real exception goes into its `ALLOWED` list with a reason.
3. **The API contract is the bot's.** `src/tickr/api/schema/`, `tests/api/fixtures/`, `contract/` and `apps/shared/Sources/TickrKit/Resources/DemoDay.jsonl.xz` are copies made by tickr-bot's `contract-sync` workflow (`contract/SOURCE` names the bot commit). Never edit them here: change the bot, and the sync pull request brings them. A code from a newer bot must still read as "Other reason", never crash.

## Swift code rules (apps/)

Enforced by `apps/scripts/check_swift_rules.py` in the `swift-rules` CI job on every pull request, and by SwiftLint. Details: `docs/design-system.md`.

- **No words in code.** Every text a person reads is defined once in the target's `L10n.swift` as `LocalizedStringResource("key", defaultValue: "English")`, with a Spanish translation in its String Catalog. Views use `L10n` entries: never `Text("…")`, `Button("…")`, `Text(verbatim: "…")` or a returned English string. Only SF Symbol names, documented `static let` identifiers and enum raw values may be other string literals.
- **No magic numbers.** Sizes, durations, opacities and colours come from `Tokens` and `Palette`; anything else is a documented `static let`.
- **2-space indentation.**
- **Current Apple stack only, no deprecated or legacy APIs.** The apps target the latest macOS and iOS (26 and later) in Swift 6 language mode with strict concurrency (no `nonisolated(unsafe)`, `@unchecked Sendable`, `@preconcurrency` or weakened concurrency settings), and use: Swift Testing (`import Testing`, `@Test`, `#expect`) for tests, XCTest only for UI tests; Observation (`@Observable`, `@State`, `@Environment`, `@Bindable`), never `ObservableObject`/`@Published`; async/await, `Task` and actors, never Combine, callbacks or `DispatchQueue`; `NavigationStack`/`NavigationSplitView`; Swift Charts for charts; String Catalogs; `#Preview`; the current form of every SwiftUI, UIKit and AppKit call (`foregroundStyle`, `clipShape`, `navigationTitle`, `onChange(of:) { old, new in }`, `NSApp.activate()`). Rule `legacy` of the checker rejects the listed old APIs, in tests too, and package or project settings below Swift 6 or OS 26.
- **Dependencies through Factory** (hmlongco/Factory, `FactoryKit`, re-exported by `TickrKit`). Services are registered once on `Container` (shared ones in `apps/shared/Sources/TickrKit/Dependencies.swift`, app ones in the app's `Dependencies.swift`) and resolved with `@Injected(\.key)` (`@ObservationIgnored` in an `@Observable` model) or `Container.shared.key()`. Never build a service inside a model or view, and never add a singleton of your own. Views read their model from the SwiftUI environment. Tests replace registrations under `@Suite(.container)` from `FactoryTesting`.

## How we work

- Work on a branch, open a pull request, keep PRs small (one reviewable idea).
- CI must be green. Tests run in a couple of minutes; if they get slow, fix that first.
- No evidence packets, receipts, trackers or design tables. The PR description says what changed, how it was tested, and what is left.
- Never weaken a test, raise a timeout or add a retry to make CI pass.
- Size is a warning sign: keep product code lean and every PR small. The owner lifted the ~15k-line v1 ceiling on 2026-11-14 (it is no longer a stop-and-ask point), so measure growth and say in the PR when a change adds a lot.
- Write code, comments, commits and docs in English. The owner reads Russian in chat.
