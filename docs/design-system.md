# Aperture design system

The single definition of how the operator apps (macOS and iOS) look and move. It is derived from
the approved design canvas. Code follows it one to one:

- Colours: `apps/shared/Sources/ApertureDesign/Palette.swift`.
- Everything else: `apps/shared/Sources/ApertureDesign/Tokens.swift`.
- Changing a value means changing this table and the Swift file in the same pull request.

## Rules

1. **Screens use tokens and roles only.** They contain no number, colour or duration of their own.
   - `apps/scripts/check_swift_rules.py` (rule `numbers`, using `check_swift_literals.py`) fails CI on a number other than 0 and 1 unless it is a documented `static let` constant, an enum raw value, a subscript index or a halving `/ 2`.
   - SwiftLint (`.swiftlint.yml`) fails CI on a colour made outside `Palette.swift`, a hue name instead of a role, and a font size outside `Tokens.Typography`.
   - A screen may define its own documented constant only for a value no other screen uses (a chart's padding ratio, say); anything shared belongs in `Tokens`.
   - The rules check covers `apps/shared`, `apps/macos` and `apps/ios` in the `swift-rules` workflow on every pull request. It has no baseline: every violation fails. The `test` job also runs the check (`tests/test_swift_rules.py`). SwiftLint covers `apps/shared`; each app joins it once its code has moved onto the system.
2. **No user-facing text in code.** Every string a person reads is defined once, in the target's `L10n.swift`, as `LocalizedStringResource("key", defaultValue: "English")`, and translated in the String Catalog (`Localizable.xcstrings`) beside it. A catalog is committed exactly as Xcode writes it (`apps/scripts/format_xcstrings.py` rewrites it so), and a key's `table:` is a string literal or left out: Xcode's extraction cannot follow a constant, so it would copy the keys into `Localizable.xcstrings` on every build.
   - Views use `L10n` entries. `Text("…")`, `Button("…")`, `Text(verbatim: "…")` and computed properties returning English all fail CI (rule `text`). Other string literals may only be SF Symbol names, documented `static let` identifiers and enum raw values; the one capitalised protocol token allowed in a documented constant is the HTTP scheme `Bearer`.
   - CI fails when an `L10n` key has no Russian translation in the catalog (rule `catalog`).
   - English is the development language, with a Russian translation, and the app follows the system language.
   - Protocol values from the bot (`exit_reason`, fence `kind`) are shown through a localized title and never translated in place.
3. **System appearance only.** Light and dark follow macOS/iOS; there is no theme switch. Light is designed on its own (soft glows and a tinted shadow), not as an inverted dark.
4. **Components carry the spacing.** Cards, rows, section labels, badges and tags come from shared components. A screen arranges components; it does not restyle them.
5. **Motion has meaning and respects Reduce Motion.** Every animation uses a `Tokens.Motion` curve. With Reduce Motion on, every piece shows its still final state.
6. **Formatting: Swift uses 2-space indentation.**
   - `.editorconfig`, SwiftLint's `indentation_width` (shared package) and the rules check (rule `indent`, every app) enforce it.
   - Planned with each app's move: the Xcode projects' text settings get the same values, so Xcode indents with 2.
7. **Current Apple stack only.** macOS and iOS 26, Swift 6 with strict concurrency, Swift Testing, Observation, dependencies through Factory, async/await, NavigationStack/SplitView, Swift Charts, String Catalogs, `#Preview`; no deprecated API. The rules check (rule `legacy`, tests included) rejects the old ones; the full list is in CLAUDE.md.

## Colour roles

Each meaning has a fill colour (strokes, fills, glows) and a text colour, which keeps at least 4.5:1
contrast on `surface` in both appearances.

| Role | Use | Light | Dark |
|---|---|---|---|
| `background` | Window background behind cards | `#EEF2FA` | `#070A16` |
| `surface` | Cards, panels, popovers | `#FFFFFF` | `#0E1326` |
| `surfaceSunken` | Inset areas in a card: charts, wells | `#F6F8FD` | `#0A0F20` |
| `separator` | Card borders, grid lines, tracks | `#E3E8F2` | `#1E2644` |
| `separatorStrong` | Zero lines, radar rings | `#CFD7E8` | `#2A3459` |
| `textPrimary` | Headlines, primary values | `#0E1430` | `#E7EAF6` |
| `textSecondary` | Body text in rows and lists | `#262F52` | `#C9CFE6` |
| `textTertiary` | Labels next to values, explanations | `#475174` | `#A9B2D3` |
| `textQuaternary` | Section labels, captions, "—" | `#5F6A8C` | `#8F99BC` |
| `accent` / `accentText` | Live, brand, running bot, focus | `#0EA5A0` / `#0B766F` | `#2DD4BF` / `#5EEAD4` |
| `profit` / `profitText` | Gains, verified stop, healthy | `#10B981` / `#047857` | `#34D399` / `#6EE7B7` |
| `loss` / `lossText` | Losses, missing stop, alarm, destructive | `#EF4444` / `#B91C1C` | `#F87171` / `#FCA5A5` |
| `warning` / `warningText` | Paused, blocked, stale, closed gate, environment chip | `#F59E0B` / `#B45309` | `#FBBF24` / `#FCD34D` |
| `info` / `infoText` | Entries, orders, commands in flight | `#3B82F6` / `#1D4ED8` | `#60A5FA` / `#93C5FD` |
| `highlight` / `highlightText` | Recorded day, BACKLOG, observers | `#8B5CF6` / `#6D28D9` | `#A78BFA` / `#C4B5FD` |
| `seriesVWAP` | VWAP line | = `warning` | = `warning` |
| `seriesFastEMA` | EMA 9 line | = `accent` | = `accent` |
| `seriesSlowEMA` | EMA 20 line | = `highlight` | = `highlight` |
| `seriesATR` / `seriesATRText` | ATR pane | `#EC4899` / `#BE185D` | `#F472B6` / `#F9A8D4` |
| `seriesUniverse` | Universe stage of the live flow | = `seriesATR` | = `seriesATR` |
| `glowIndigo`, `glowTeal` | Light background corner glows (at `Opacity.glow`, reach 420 pt; teal centred on the right edge, a fifth down) | `#6366F1`, `#14B8A6` | not drawn |
| `shadow` | Light card shadow (at `Opacity.shadow`) | `#283C96` | not drawn |

A money result uses `profitText` above zero, `lossText` below and `textTertiary` at zero.

## Spacing (`Tokens.Space`), 4-point grid

| Token | pt | Use |
|---|---|---|
| `xxs` | 2 | Inside badges, value and unit |
| `xs` | 4 | Icon to label, lines of a compact row |
| `s` | 8 | Items in a row, rows of a list |
| `m` | 12 | Groups inside a card, banner padding |
| `l` | 16 | Between cards; card inner padding |
| `xl` | 24 | Around a screen's content, between sections |
| `xxl` | 32 | Large blocks on wide screens |

## Corner radius (`Tokens.Radius`)

| Token | pt | Use |
|---|---|---|
| `small` | 6 | Badges, tags, chips |
| `medium` | 10 | Banners, inset panels |
| `large` | 14 | Small cards (sidebar, menu-bar panel) |
| `card` | 18 | Standard cards |

## Typography (`Tokens.Typography`)

System font. Numbers, prices, symbols and protocol values are monospaced so digits line up. Text
in rows uses the platform text styles so Dynamic Type applies.

| Token | Font | Use |
|---|---|---|
| `title` | 28 pt bold | Screen header title (the product name, in `infoText`) |
| `subtitle` | 28 pt medium mono | The word next to a screen title ("Operator") |
| `display` | 44 pt bold mono | A headline figure set apart from cards (Overview's day result on the Mac) |
| `hero` | 34 pt bold mono | The one key figure of a screen inside a card |
| `metric` | 24 pt bold mono | Large figures in cards |
| `body` / `bodyMono` | `.body` | Values in rows |
| `callout` / `calloutMono` | `.callout` | Labels, explanations |
| `caption` / `captionMono` | `.caption` | Secondary notes |
| `label` | 11 pt semibold mono, uppercase, tracking 0.8 | Card section labels |
| `badge` | 10.5 pt bold mono, tracking 0.6 | Badges and tags |
| `annotation` / `annotationBold` | 10.5 pt mono | Chart axes, ticker, pipeline values |
| `symbol` | `Size.iconWellSymbol` semibold | SF Symbols in icon wells |
| `stageSymbol` | 20 pt semibold | SF Symbols in a live-flow stage |
| `button` | `.body` semibold | Command buttons (bot controls) |
| `chip` | `.callout` bold mono | Tabs and chips naming a symbol (position tabs) |

## Lines (`Tokens.Stroke`)

| Token | Value | Use |
|---|---|---|
| `hairline` | 0.5 pt | Grids, chart guides |
| `thin` | 1 pt | Card borders, separators, level lines |
| `regular` | 1.5 pt | Indicator lines, outlines |
| `bold` | 2 pt | Price lines, sparklines |
| `ring` | 12 pt | Rings |
| `dash` | 5 on, 4 off | Stop and entry levels |
| `dashFine` | 3 on, 3 off | Crosshair, planned outlines |

## Opacity (`Tokens.Opacity`)

| Token | Value | Use |
|---|---|---|
| `wash` | 0.10 | Banner and badge backgrounds |
| `glow` | 0.14 | Light background glows |
| `faint` | 0.35 | Volume bars, inactive fills |
| `shadow` | 0.12 | Light card shadow |
| `border` | 0.45 | Accent-tinted borders |
| `medium` | 0.70 | Inactive elements, pulse start |
| `overlay` | 0.85 | Readouts over content |

## Sizes (`Tokens.Size`)

| Token | pt | Use |
|---|---|---|
| `dot` / `dotSmall` | 8 / 6 | Status dots |
| `iconWell` / `iconWellSymbol` | 44 / 15 | Round icon wells |
| `stage` | 52 | Stages of the live flow |
| `dayResultWidth` | 300 | Overview's day result beside the header |
| `gridColumnMin` | 300 | Narrowest column of a card grid before it stacks |
| `logo` / `logoSmall` / `emptyMark` | 56 / 26 / 88 | Brand mark (`BrandMark`): the tick-shaped price line of the app icon |
| `sparkline` | 34 | Sparkline height |
| `bar` | 8 | Progress bar height |
| `ticker` | 22 | Ticker strip height |
| `sideColumn` | 320 | Side column of cards |
| `contentMaxWidth` | 1500 | Content stops growing and centres |
| `shadowRadius` / `shadowOffset` | 10 / 6 | Light card shadow |
| `riseOffset` | 12 | Rise-in distance |
| `ringHalo` | 60 | Reach of the halo behind a ring |

## Motion (`Tokens.Motion`)

| Token | Curve | Use |
|---|---|---|
| `quick` | snappy | Values rolling, toggles, selection |
| `standard` | spring 0.5 s, damping 0.85 | Views in and out, list changes, section switch |
| `entrance` | spring 0.7 s, damping 0.85 | Cards rising as a screen appears |
| `fill` | spring 1.2 s, damping 0.9 | Rings, bars, counters filling |
| `draw` | ease-out 1.4 s | Lines and charts drawing themselves |
| `stagger` | 0.05 s | Delay between cards of a screen |
| `pulseSeconds` / `pulseScale` | 2.4 s / ×2.2 | "Live" pulse ring |
| `breatheSeconds` / `breatheScale` | 2.4 s / ×1.08 | Glows and alarms breathing |
| `rotationSeconds` | 4 s per turn | Radar sweep |
| `tickerSpeed` | 22 pt/s | Event ticker (edges fade over 6% of its width) |
| `pipelineSeconds` | 4.2 s | Light travelling the live flow |

## Components

| Component | Where | Rule |
|---|---|---|
| Card | `apertureCard()` + `CardLabel` | `surface`, `Radius.card` (iOS) or `Radius.large` (Mac), `Space.l` padding, `separator` border; light mode adds `shadow`. Cards sharing a grid row are one height (`filling()` on the Mac) |
| Card grid (Mac) | `Grid` of cards | Fills the window's width: equal columns of at least `Size.gridColumnMin`, `Space.l` apart; a narrower window stacks into fewer columns |
| Section label | `CardLabel` | `Typography.label`, uppercase, `textQuaternary` |
| Stat row | label … value | label `callout` `textTertiary`, value `bodyMono` |
| Badge | tag | `Typography.badge`, role text colour, `Opacity.wash` fill, `Opacity.border` stroke, `Radius.small` |
| Command button | bot controls | `Typography.button`, `surfaceSunken` fill, `separatorStrong` stroke, `Radius.medium`; destructive: `lossText` on a `loss` wash and border |
| Live-flow stage | pipeline | `Size.stage` circle, `Stroke.bold` ring and a soft glow in the stage colour; name in the stage's text colour |
| Accent | `.tint` | `info` for links, selection and system controls on both apps, never the system blue |
| Planned tag | BACKLOG / NEEDS API | `highlightText`, dashed `dashFine` outline, `Radius.small` |
| Pulse dot | `PulseDot` | `Size.dot`, ring per `pulseSeconds` while live |
| Banner | headline | role text colour, `Opacity.wash` fill, `Radius.medium`, `Space.m` padding |

## Brand: app icon and launch screen

The product name people see is **Tickr** (bundle display name and the String Catalogs); code,
targets and the repository keep their code name. The mark is a price line drawn as a tick that
breaks upward, with a spark at its end.

- `apps/scripts/make_brand_assets.py` writes every brand file from one description, with colours
  from `Palette.swift`: the Icon Composer icon `AppIcon.icon` of each app (light, dark and tinted;
  the system adds Liquid Glass) and the iOS launch screen in `apps/ios/Aperture/Assets.xcassets`
  (`LaunchBackground` = `background`, `LaunchMark`). Change the script and run it; never edit the
  generated files. `tests/test_brand_assets.py` fails when they differ.
- In the apps the same line is `BrandMark` (ApertureDesign): it draws itself on appear and its
  spark then pulses while the bot's data is live; still otherwise and with Reduce Motion.
- Empty screens (nothing yet, no trades, bot unreachable) use `BrandMark.empty()` as the
  `ContentUnavailableView` illustration, muted (`.muted`) when the bot cannot be reached. Errors
  keep a warning SF Symbol, so they never look like a calm empty state.
- macOS has no launch screen (Apple HIG). The menu bar extra keeps an SF Symbol, because it shows
  the bot's state; notifications and the About panel use the app icon.
