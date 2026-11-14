# Aperture operator app (macOS)

A SwiftUI app over the bot's local API (contract v1, `docs/api.md`). It shows the status and sends
the three operator commands. It never talks to the broker.

- Menu-bar icon, always visible: green = entries allowed, orange = entries blocked (reason shown),
  red = something needs you (bot down or stale, API unreachable, position without a verified stop).
- Window: the entry-blocking reason in plain words, bot state, trading gate, strategy, position with
  its stop, fences, today's trades and gross result, quote stream health, status age, recent commands.
- Buttons: set/clear entry stop, cancel own orders, flatten. Each asks for confirmation. A command
  is only queued; its result appears under "Recent commands" when the bot has handled it.

## Layout

| Path | What |
|---|---|
| `../shared` | Shared Swift package (see `apps/shared/README.md`): contract models and API client (`ApertureKit`), palette and animated pieces (`ApertureDesign`). |
| `Aperture/` | The app's Swift sources (views, polling model, menu-bar extra, window). |
| `ApertureMac.xcodeproj` | Xcode project: target and scheme `Aperture macOS`, builds `Aperture.app` from `Aperture/`. |
| `Support/Info.plist` | Info.plist keys Xcode cannot generate (local-network HTTP to the API). |
| `Package.swift` | The same sources as a Swift package, for `swift build` and `scripts/make-app.sh` without Xcode. |

## Open in Xcode

Kept current with Xcode 27.2: its upgrade check and recommended settings are already applied, so
Xcode offers no project update. The app needs macOS 26 and builds with Xcode 26 or later (Swift 6 language mode).

```sh
open Aperture.xcworkspace        # at the repository root
```

The workspace holds the macOS app (`apps/macos/ApertureMac.xcodeproj`) and the shared package
(`apps/shared`); the iOS app's project joins it when it is committed. Pick the scheme `Aperture macOS` and
"My Mac", then Run (⌘R). Signing is automatic and signs to run locally; no Apple ID is needed
for the Mac app. New Swift files dropped into `apps/macos/Aperture/` are picked up without
editing the project. Start the API first (below), or the app shows "unavailable".

## Run without Xcode

Needs Swift 6.2+ command line tools (Xcode 26) and macOS 26.

```sh
# 1. Start the API (the bot writes data/status.json; without the bot the app shows "unavailable").
python -m aperture.api --config config/bot.toml

# 2a. Quick run from the terminal
cd apps/macos && swift run ApertureMac

# 2b. Or build an app bundle and open it
apps/macos/scripts/make-app.sh && open apps/macos/build/Aperture.app

# Tests (contract models and shared code)
cd apps/shared && swift test
```

The app talks to `http://127.0.0.1:8766` (the `[api]` port in `config/bot.toml`). If you change
the port: `defaults write local.aperture.operator apiBaseURL http://127.0.0.1:<port>` for the
bundle, or `defaults write ApertureMac apiBaseURL ...` when started with `swift run`.
