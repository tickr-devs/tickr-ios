# Tickr operator app (iOS)

A SwiftUI iPhone app over the bot's local API (`docs/api.md`). Like the macOS app, it never talks to
the broker: it shows what the bot wrote and queues operator commands that the bot decides on.
Design: the approved canvas (tabs Home, Positions, Chart, Activity, Lab; Settings behind the gear
on Home; bot control behind the power button). It follows the system appearance (light and dark)
and Apple's Human Interface Guidelines; every animation has a still fallback for Reduce Motion.

| Tab | Now | Comes with |
|---|---|---|
| Home | Day result ring, headline, live event ticker, open positions, bot inputs, power button (pause/resume entries, cancel own orders, flatten) | Day picker (days API) |
| Positions | Each open position: risk band, protection chain, max loss, Flatten | Live price line (bars API) |
| Chart | Placeholder | Candles, indicators, levels, crosshair (bars API) |
| Activity | Today's result curve, trades, journal | Past days (days API), signals not taken |
| Lab | Active strategy | Replays, refusal counts |

Cancel and Flatten ask for Face ID (or the passcode) first; pausing entries does not. Every command
is queued once; its result appears as a banner when the bot reports it in `recent_commands`.
Commands are offered only while the status is fresh.

Push notifications, lock-screen alerts and the Live Activity need an Apple Developer Program
membership (APNs); they are added once that exists.

## Run it

Needs a Mac with Xcode 16 or newer. The Xcode project is committed, so nothing else is needed:

```sh
open apps/ios/Tickr.xcodeproj
```

(or open the root `Tickr.xcworkspace` to have the iOS and macOS apps side by side).

Pick the `Tickr iOS` scheme and an iPhone Simulator, Run. The app reads the bot at
`https://bot.tickr.bot`, built in, once you sign in with your tickr.bot account (Settings ›
Sign in with tickr.bot). To read a bot running on this Mac instead, run
`python -m tickr.api pair-simulator` and put the file path it prints in `Config/Local.xcconfig`
(`TICKR_SIMULATOR_TOKEN_FILE`). To try Face ID in the Simulator: Features ›
Face ID › Enrolled, then Matching Face when asked.

On your iPhone: copy `apps/Config/Team.xcconfig.example` to `apps/Config/Team.xcconfig` and
`Config/Local.xcconfig.example` to `Config/Local.xcconfig` (both git-ignored), put your Apple
Developer Program team id in the first, connect the phone, Run. Do not pick the team in Signing & Capabilities: that writes it into the committed
project. Bundle ids are `bot.tickr.ios` (and `.tests`, `.uitests`), from the one prefix in
`apps/Config/Identity.xcconfig`, shared with the Mac app (`bot.tickr.mac`). Likewise never accept Xcode's "Update to recommended
settings": the project is generated, so such changes go into `project.yml`.
The phone signs in once with the owner's tickr.bot account (passkey) in the system's sign-in
sheet; tickr.bot gives the app a 60-second grant for the bot, which the bot trades for this
phone's own token (`POST /session` in `docs/api.md`). The token is kept in the phone's Keychain
(this device only) and sent only over HTTPS to the bot's address; Sign out revokes it on the bot.

The project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).
Swift files under `Tickr/` are picked up automatically; only after changing `project.yml` run
XcodeGen 2.46.0 (the version CI uses): `cd apps/ios && xcodegen` and commit the result. CI fails when the
committed project differs from what `project.yml` generates.

Shared code (contract models, API client, palette, animated pieces) lives in `apps/shared`.
