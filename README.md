# tickr-ios

The Tickr operator apps: macOS, iOS and iPadOS, one SwiftUI codebase with the shared package
`apps/shared` (TickrKit, TickrDesign). Split from tickr-devs/Tickr on 2026-11-27.

- Rules for contributors and agents: [`CLAUDE.md`](CLAUDE.md)
- Design system: [`docs/design-system.md`](docs/design-system.md)
- Apps: [`apps/macos/README.md`](apps/macos/README.md), [`apps/ios/README.md`](apps/ios/README.md),
  [`apps/shared/README.md`](apps/shared/README.md)

## Xcode

`open Tickr.xcworkspace` opens both apps and the shared package. Copy your git-ignored
`apps/Config/Team.xcconfig` (signing team) from the old checkout.

## The API contract

The apps are built against the contract of [tickr-bot](https://github.com/tickr-devs/tickr-bot):
`src/tickr/api/schema/`, `tests/api/fixtures/` (decoded by the Swift tests and previews),
`contract/codes.json` (what the bot sends, checked by `tests/test_api_codes.py`) and the demo day.
tickr-bot's `contract-sync` workflow opens a pull request here when it changes.

## Checks

- `swift-rules` (every pull request): conflict markers, Swift code rules, SwiftLint and the
  Python tests in `tests/` (`uv run --no-project --with pytest==9.1.1 pytest -q tests`).
- `macos-app`, `ios-app`: build and test; `ui-tests`, `layout-sweep`: by label or nightly.

## Releases

Actions > release > Run workflow tags main with the next semver and opens a GitHub Release.
