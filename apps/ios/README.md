# Aperture operator app (iOS)

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
| Lab | Active strategy | Observers, replays, refusal counts |

Cancel and Flatten ask for Face ID (or the passcode) first; pausing entries does not. Every command
is queued once; its result appears as a banner when the bot reports it in `recent_commands`.
Commands are offered only while the status is fresh.

Push notifications, lock-screen alerts and the Live Activity need an Apple Developer Program
membership (APNs); they are added once that exists.

## Run it

Needs a Mac with Xcode 15 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). The Xcode project is generated from `project.yml` and not committed.

```sh
cd apps/ios
xcodegen            # writes Aperture.xcodeproj
open Aperture.xcodeproj
```

Pick the `Aperture` scheme and an iPhone Simulator, Run. With the API running on the same Mac
(`python -m aperture.api --config config/bot.toml`) the Simulator reaches it at
`http://127.0.0.1:8766`, the default address there. To try Face ID in the Simulator: Features ›
Face ID › Enrolled, then Matching Face when asked.

On your iPhone: in Xcode select your Apple ID team under Signing & Capabilities (a free Apple ID
works; the app then runs for 7 days before Xcode has to install it again), connect the phone, Run.
The phone reaches the Mac through Tailscale; that setup is described when the API accepts remote
requests.

Shared code (contract models, API client, palette, animated pieces) lives in `apps/shared`.
