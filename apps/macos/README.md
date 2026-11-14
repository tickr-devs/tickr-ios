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
| `Sources/ApertureUI` | SwiftUI views and the polling model. |
| `Sources/ApertureMac` | macOS shell: menu-bar extra + window. |

## Run on your Mac

Needs Xcode 15 or newer (or the Swift 5.9+ command line tools) and macOS 14+.

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

To develop in Xcode: `open apps/macos/Package.swift`, pick the `ApertureMac` scheme, Run.

The app talks to `http://127.0.0.1:8766` (the `[api]` port in `config/bot.toml`). If you change
the port: `defaults write local.aperture.operator apiBaseURL http://127.0.0.1:<port>` for the
bundle, or `defaults write ApertureMac apiBaseURL ...` when started with `swift run`.
