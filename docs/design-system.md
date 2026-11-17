# Tickr design system

The single definition of how the operator apps (macOS and iOS) look and move. It is derived from
the approved design canvas. Code follows it one to one:

- Colours: `apps/shared/Sources/TickrDesign/Palette.swift`.
- Everything else: `apps/shared/Sources/TickrDesign/Tokens.swift`.
- Changing a value means changing this table and the Swift file in the same pull request.

## Rules

1. **Screens use tokens and roles only.** They contain no number, colour or duration of their own.
   - `apps/scripts/check_swift_rules.py` (rule `numbers`, using `check_swift_literals.py`) fails CI on a number other than 0 and 1 unless it is a documented `static let` constant, an enum raw value, a subscript index or a halving `/ 2`.
   - SwiftLint (`.swiftlint.yml`) fails CI on a colour made outside `Palette.swift`, a hue name instead of a role, and a font size outside `Tokens.Typography`.
   - A screen may define its own documented constant only for a value no other screen uses (a chart's padding ratio, say); anything shared belongs in `Tokens`.
   - Rules `result`, `format` and `stopsymbol` check `apps/macos` and `apps/ios` only (the shared package holds the one map they point to): a result's colour only through `Palette.result` / `Tone.result`, numbers only through `Formatting.swift`, a shield SF Symbol only from `StopState` (a shield meaning something else is marked `// symbol: <meaning>`). See "One meaning, one look".
   - The rules check covers `apps/shared`, `apps/macos` and `apps/ios` in the `swift-rules` workflow on every pull request. It has no baseline: every violation fails. The `python-tests` job also runs the check (`tests/test_swift_rules.py`). SwiftLint runs in the same workflow and covers `apps/shared`, `apps/macos` and `apps/ios`; an app's own `.swiftlint.yml` may relax SwiftLint's size limits only, until its long files are split.
2. **No user-facing text in code.** Every string a person reads is defined once, in the target's `L10n.swift`, as `LocalizedStringResource("key", defaultValue: "English")`, and translated in the String Catalog (`Localizable.xcstrings`) beside it. A catalog is committed exactly as Xcode writes it (`apps/scripts/format_xcstrings.py` rewrites it so), and a key's `table:` is a string literal or left out: Xcode's extraction cannot follow a constant, so it would copy the keys into `Localizable.xcstrings` on every build.
   - Views use `L10n` entries. `Text("…")`, `Button("…")`, `Text(verbatim: "…")` and computed properties returning English all fail CI (rule `text`). Other string literals may only be SF Symbol names, documented `static let` identifiers and enum raw values; the one capitalised protocol token allowed in a documented constant is the HTTP scheme `Bearer`.
   - CI fails when an `L10n` key has no Russian translation in the catalog (rule `catalog`).
   - English is the development language, with a Russian translation, and the app follows the system language.
   - Protocol values from the bot (`exit_reason`, fence `kind`) are shown through a localized title and never translated in place.
3. **System appearance only.** Light and dark follow macOS/iOS; there is no theme switch. Light is designed on its own (soft glows and a tinted shadow), not as an inverted dark.
4. **Components carry the spacing.** Cards, rows, section labels, badges and tags come from shared components. A screen arranges components; it does not restyle them.
5. **Motion has meaning and respects Reduce Motion.** Every animation uses a `Tokens.Motion` curve. With Reduce Motion on, every piece shows its still final state. Anything that reads as data or activity (status dots, flow stages, alarms, counts) moves only when the bot's data changes: one pulse, flight or fade per real event, still in between, never on a timer. Only pure ornament may loop, marked `// decorative: <why>` in code: the brand mark's spark halo, the empty-positions radar (sweep and blips), the event ticker's and the screener chips' scroll, the Lab's AI advisor title shine (owner wants the design's motion, 2026-11-16), and the Settings session card's drifting pre/post-market stripes (owner's request, 2026-11-16). Each loops only while `OrnamentGate` holds (macOS and iOS: Reduce Motion off, the live day shown, fresh status, the bot running), still otherwise. The one exception is loading (mockup v102, see "Loading" below): the skeleton's shimmer and the button spinner mark only that a read or a command is in flight and are on screen only while one is, so they move whenever they show, in Core Animation like the brand halo and `ShineBand`; under Reduce Motion nothing sweeps or turns and they pulse gently in opacity instead. The `loop` rule of `check_swift_rules.py` rejects any other `repeatForever`, `TimelineView(.animation)` or Core Animation `repeatCount = .infinity` (owner, 2026-11-15).
6. **Formatting: Swift uses 2-space indentation.**
   - `.editorconfig`, SwiftLint's `indentation_width` (every app) and the rules check (rule `indent`, every app) enforce it.
   - Planned with each app's move: the Xcode projects' text settings get the same values, so Xcode indents with 2.
7. **Current Apple stack only.** macOS and iOS 26, Swift 6 with strict concurrency, Swift Testing, Observation, dependencies through Factory, async/await, NavigationStack/SplitView, Swift Charts, String Catalogs, `#Preview`; no deprecated API. The rules check (rule `legacy`, tests included) rejects the old ones; the full list is in CLAUDE.md.

## Colour roles

Each meaning has a fill colour (strokes, fills, glows) and a text colour, which keeps at least 4.5:1
contrast on `surface` in both appearances.

**Text on a solid fill passes WCAG AA too (4.5:1, normal text), in both appearances**, with any
opacity the text is drawn at and any shade over the fill (pressed, a hold's sweep, a tag)
blended in first. A meaning's fill colour (`loss` and the like) is for strokes, washes, halos and
charts; when text or a symbol sits on a solid red, the fill is `lossFill`, with `onLoss` on it.
`PaletteContrastTests` (apps/shared) computes every text and fill pair of the destructive and
emergency command tiers from the palette's values (`Swatch`) and fails below 4.5:1.

| Role | Use | Light | Dark |
|---|---|---|---|
| `background` | Window background behind cards | `#EEF2FA` | `#070A16` |
| `surface` | Cards, panels, popovers | `#FFFFFF` | `#0E1326` |
| `surfaceSunken` | Inset areas in a card: charts, wells | `#F6F8FD` | `#0A0F20` |
| `separator` | Card borders, grid lines, tracks | `#E3E8F2` | `#1E2644` |
| `separatorStrong` | Zero lines, radar rings, skeleton blocks (mixed into `surfaceSunken`) | `#CFD7E8` | `#2A3459` |
| `titleBar` | Mac title bar above the sidebar and the screen | `#F3F6FC` | `#0B1022` |
| `sidebar` | Mac sidebar column | `#F1F4FB` | `#0A0E1E` |
| `selection` | Selected sidebar row (with a `separatorStrong` hairline) | `#E3EBFF` | `#172046` |
| `textPrimary` | Headlines, primary values | `#0E1430` | `#E7EAF6` |
| `textSecondary` | Body text in rows and lists | `#262F52` | `#C9CFE6` |
| `textTertiary` | Labels next to values, explanations | `#475174` | `#A9B2D3` |
| `textQuaternary` | Captions, hints, "—" | `#5F6A8C` | `#8F99BC` |
| `textLabel` | Uppercase section labels: `CardLabel`, card headers, metric names (the boards' `.lbl`); 4.6:1 on `surface` | `#6A7495` | `#8F99BC` |
| `accent` / `accentText` | Live, brand, running bot, focus | `#0EA5A0` / `#0B766F` | `#2DD4BF` / `#5EEAD4` |
| `profit` / `profitText` | Gains, verified stop, healthy | `#10B981` / `#047857` | `#34D399` / `#6EE7B7` |
| `loss` / `lossText` | Losses, missing stop, alarm, destructive | `#EF4444` / `#B91C1C` | `#F87171` / `#FCA5A5` |
| `lossFill` / `onLoss` | A solid red with text or a symbol on it: the emergency stop, a destructive command's glyph tile (white on it 6.5:1 light, 8.3:1 dark) | `#B91C1C` / `#FFFFFF` | `#991B1B` / `#FFFFFF` |
| `warning` / `warningText` | Paused, blocked, stale, closed gate, the Sandbox `EnvironmentBadge` | `#F59E0B` / `#B45309` | `#FBBF24` / `#FCD34D` |
| `info` / `infoText` | Entries, orders, commands in flight | `#3B82F6` / `#1D4ED8` | `#60A5FA` / `#93C5FD` |
| `highlight` / `highlightText` | Recorded day, BACKLOG, observers | `#8B5CF6` / `#6D28D9` | `#A78BFA` / `#C4B5FD` |
| `chipFill` | The Mac title bar's buttons (`.titleBar`); chips draw on `surfaceSunken` (`ChipFace`) | `#F3F6FD` | `#111834` |
| `accentFill` / `onAccent` | Primary button fill and its text | `#0B766F` / `#FFFFFF` | `#2DD4BF` / `#04131A` |
| `sheen` | Light gradient across a filled control (at `Opacity.wash`) | `#FFFFFF` | `#FFFFFF` |
| `seriesVWAP` | VWAP line | = `warning` | = `warning` |
| `seriesFastEMA` | EMA 9 line | = `accent` | = `accent` |
| `seriesSlowEMA` | EMA 20 line | = `highlight` | = `highlight` |
| `seriesATR` / `seriesATRText` | ATR pane | `#EC4899` / `#BE185D` | `#F472B6` / `#F9A8D4` |
| `seriesUniverse` | Universe stage of the live flow | = `seriesATR` | = `seriesATR` |
| `glowIndigo`, `glowTeal` | Light background corner glows (at `Opacity.glow`, reach 420 pt; teal centred on the right edge, a fifth down) | `#6366F1`, `#14B8A6` | not drawn |
| `shadow` | Light card shadow (at `Opacity.shadow`) | `#283C96` | not drawn |
| `scrim` | Dimmed backdrop behind a Mac overlay panel (at `Opacity.faint`) and that panel's shadow; the emergency stop's hold sweep (at `Command.sweepOpacity`) | `#080C1E` | `#080C1E` |

A money result uses `profitText` above zero, `seriesATRText` (the series pink) below and
`textTertiary` at zero (mockup v100: money losses are pink everywhere; `loss`/`lossText` red is
kept for danger: a missing or rejected stop, alarms, destructive actions). The sign is taken from
the value as shown, rounded to its decimals (cents by default), so "−0.004" shown as "$0.00" is
neutral. Only through `Palette.result` / `Tone.result` (rule `result` of the rules check rejects a
hand-written `>= 0 ? … profit : … loss` in the apps). Text is drawn only in a text role: a fill
(`info`, `loss`) is never text (`PaletteContrastTests` checks every `Tone`'s and every verdict's
text colour at 4.5:1 on `surface` and shows that `info` fails it).

## One meaning, one look (`Meanings.swift`, `Formatting.swift`)

Operator-facing safety and money signals look the same on every screen of both apps (owner rule
2026-11-16). Each has one map in TickrDesign (which builds on TickrKit's models); screens never
pick these colours, symbols or number formats themselves.

| Meaning | Shared piece | Look |
|---|---|---|
| A stop's protection | `StopState.isProtected` (TickrKit), `StopState.symbol` / `.tone`, `StopState.worst` / `combinedTone` / `combinedSymbol` / `stageTone`, `StopGlyph`, `StopDot` | Mockup v100: verified `checkmark.shield` `profit` (green); pending `hourglass` `warning` (amber); missing `xmark.shield` and unknown `exclamationmark.shield` `loss` (red). A stop's price level: `StopState.levelSymbol` (`shield`) in the state's tone. `StopGlyph(state:symbol:price:style:)` is the glyph tile beside a position's symbol (`.tile` on the Mac Positions card, `.compact` in rows and the menu bar, iOS Home); its label is "ABCD · pending". `StopDot` is on every position tab (both apps) in the state's tone, and the tab's accessibility value says the state. A set of stops (the Mac "Broker stops" safety tile) takes the worst state's tone and symbol (`combinedTone`, `combinedSymbol`: never a fixed check; the bare shield, neutral, with no position). The live flow's broker-stop stage (Mac Overview, Mac menu bar, iOS Home) is `stageTone`: neutral with no open position unless a trade of the day ended without a confirmed stop, else the worst of the open and the day's stops. The Symbols screen's stop stage is named by the bare shield |
| The status headline | `Severity.tone`, `Headline.tone`, `EntryGate.tone`, `HeadlineBanner` | Mockup v108. Tone by severity only: calm `accent` (teal), attention `warning` (amber), alarm `loss` (red); a recorded day `highlight`. `HeadlineBanner` is one pill that hugs its text: `PulseDot` in the tone's fill, the title bold in `textPrimary` and the detail (`Headline.detail`: open positions and how many are protected, or "No open position"; after the holding headline "stops verified", mockup v111: "Holding 2 positions · stops verified", «Позиции: 2 · стопы подтверждены») in `textTertiary`, on the tone at `Headline.tint` (12 %) inside a `Headline.border` (45 %) `Stroke.thin` edge, corners `Headline.pillRadius` (a capsule). `.inline` (Mac Overview, menu-bar panel): title · detail on one line in `Headline.title`/`detail` (13 pt), the title's own full stop dropped when a detail follows (both arrangements; an alarm keeps it). `.stacked` (iOS Home, on its own row above the day ring): title over detail (14 / 12.5 pt Dynamic Type styles), corners `Headline.stackedRadius`. Beside it one unsplittable group (`.fixedSize`): a clock, the countdown (`SessionCountdown`, from the bot's `/jobs` on the bot's clock, redrawn every minute, mockup v111: "Closes in 42 m" inside today's regular session; otherwise to the next regular open (`next_session`), "Opens in 10 h 25 m" under a day, overnight too, and from a day away its weekday and New York time, "Opens Mon 09:30" («Откроется Пн 09:30»); hidden only when the calendar cannot answer) and the gate `Badge` (`EntryGate`: "Gate open" `profit`, "Entries paused" `warning`, "Gate closed" `neutral` grey with `Symbols.gateClosed`, the lock, before its words, mockup v109), live day only. Headline priority (mockup v109): alarm, then a block that needs the operator (warning), then held positions ("Holding N …"), then a trading gate closed in config (a calm "Entries off · trading gate closed in config", never a warning), then the calm rest; with the gate closed the grey "Gate closed" badge stands beside whichever headline is shown (an alarm hides it). Layout by fit (`ViewThatFits`), never by character counts: pill and facts on one row, else the facts under the pill, else the pill takes the row and wraps with corners `Headline.wrappedRadius` (12). An alarm always takes the whole row: `Headline.alarmTint` (16 %), the full tone at `Stroke.regular`, title in the tone's text colour, detail `textSecondary`, no gate badge |
| A verdict | `Verdict.color` | ENTER and HOLD `accentText`, WATCH `infoText`, IGNORE `seriesATRText`, EXIT `warningText`: the Chart's explain card and decisions, Watching closely (tag and bar), both apps |
| A trade's reason tag | `Tone.exit(_:)` (on `Board.exitLook`), `Tone.openPosition`, `Tone.refused`, `Tone.notEvaluated` | By the reason, never the result (mockup v99, MacTrades and IOSActivity): OPEN and STRATEGY EXIT `accent`, STOPPED OUT `series` (pink), CLOSED, END-OF-DAY and every other close (operator, lost stream, an entry not filled, a reason this app does not know) `neutral`; a protection failure (stop rejected, unprotected too long; no board draws one) `loss`; REFUSED `warning`, NOT EVALUATED `neutral` |
| A bot event | `Tone(Board.Event.Tone)` | The bot's event tones (ticker, journal, stage details) mapped once to design tones |

**Numbers** come only from `Formatting.swift` (rule `format`): locale-independent, a "." separator
and the U+2212 minus in every language, so a figure reads the same on both apps in English and
Russian.

| API | Output | Use |
|---|---|---|
| `Money.price` | "0.4567", "0.5000", "1.00", "12.35" (half away from zero), "1,234.50" | Every price: chart axes, readouts, tags, positions, trades, stops, entries. Owner rule: below $1 four decimals, from $1 two (`subPennyBelow`, `subPennyDigits`); from a thousand grouped with "," in every language. A chart `Double` is read through its shortest text (`Money.decimal`), so 12.345 shows 12.35 |
| `Money.value` | "0.4567", "−0.0123", "1,234.50" | A chart study's value or scale (VWAP, EMA, MACD, RSI, ATR): a price's tick with its minus |
| `Money.signedUSD` | "+$11.80", "−$1,234.50", "$0.00" | A money result (a day, a trade, an open position, MAE/MFE), zero unsigned, grouped with "," |
| `Money.signed` | "+0.6", "−1.0" | A signed figure that is not money, with its digits named (R, a delta of a count); a calendar cell's compact day result is the one figure on purpose without "$", marked `// figure:` |
| `Money.priceChange` | "+0.06", "−0.0012" | A price's move per share, at that price's tick (the prices after an exit, the chart's change): a move, not an amount, so no "$" |
| `Money.usd` | "$250.00", "$1,000,011.80", "−$4.10" | An amount that is not a result: room, limits, balances, fees (never a plus), grouped with "," |
| `Money.plain`, `Money.number` | "12.30" / "−0.12" | A plain figure that is not money (statistics, seconds; not grouped), its digits named; with its minus only below zero |
| `ClockText.minutes` / `.seconds` (TickrKit) | "14:06" / "16:58:34" | Every clock time: New York, 24-hour in every language (never "4:58:34 PM") |
| `Percent.signed(fraction:)` / `(points:)` | "+6.21%", "−0.40%" | A price change: `changeDigits` 2 (the Chart's day change and readout, both apps); a screener's change `moverDigits` 1 |
| `Percent.plain` | "52%" | A share or win rate (`StatDigits.percent`) |
| `Volume.compact` | "950", "23.4K", "1.2M" | A share volume (en_US short names in every language) |
| `DayText.day` | "Mon Nov 16", "пн 16 нояб." | A trading day: weekday, then the date, no comma, the New York day, in the person's language |

Money is always in dollars: the `format` rule of `check_swift_rules.py` fails a `Money.signed`,
`Money.plain` or `Money.number` call at the cents default (an amount without its "$"), the bot's raw
text of a money or price field (`fill.feesUsd?.text`), and "USD" written after an amount in an
L10n text. A money tone that only means something when there is some (a realized loss, a
reservation) is neutral at "$0.00": `Tone.loss`, `Tone.amount`.

A chart value that is not a number (NaN, infinity) shows the shared dash `Money.missing` ("—"),
never "0.0000". A line setting an `accessibilityValue` may let VoiceOver read a number in the
person's locale.

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
| `small` | 6 | Badges, tags |
| `chip` | 6 | Every chip (`ChipFace`: choice, on/off, menu label, small data chip), as the boards' `.u-chip` |
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
| `panelFigure` | 32 pt bold mono, tracking −1 | The day result in the Mac menu-bar panel |
| `metric` | 24 pt bold mono | Large figures in cards |
| `heading` | 22 pt bold | A screen's heading in its content ("Today · Mon Nov 16" on Trades) |
| `quote` | 20 pt semibold mono | A price beside a symbol heading (the Chart's last price) |
| `figure` | 18 pt bold mono | Figures in compact tiles and stat rows (Trades' day figures, performance) |
| `body` / `bodyMono` | `.body` | Values in rows |
| `callout` / `calloutMono` | `.callout` | Labels, explanations |
| `caption` / `captionMono` | `.caption` | Secondary notes |
| `subheadlineMono` | `.subheadline` mono | A detail line under a figure or beside a symbol (menu-bar panel); the Mac title bar's connection status |
| `headingMono` | `.title3` mono | A symbol heading a compact row (menu-bar panel positions) |
| `dayStepper` | 11.5 pt mono | The Mac title bar's day stepper |
| `label` | 11 pt semibold mono, uppercase, tracking 0.8 | Card section labels |
| `badge` | 10.5 pt bold mono, tracking 0.6 | Badges and tags |
| `annotation` / `annotationBold` | 10.5 pt mono | Chart axes, ticker, pipeline values |
| `symbol` | `Size.iconWellSymbol` semibold | SF Symbols in icon wells |
| `symbolCompact` | 13 pt semibold | SF Symbols in compact round icon buttons |
| `button` | `.body` semibold | Command buttons (bot controls) |
| `chip` | `.callout` bold mono | Figures naming a symbol (position tabs, flow chips) |
| `chipTitle` / `chipSmallTitle` | 13 / 11 pt bold mono (iOS footnote / caption2) | A chip's title (`ChipFace`), a small chip's (`.u-chip.sm`) |
| `segment` | 12.5 pt semibold (iOS footnote) | A `SegmentSwitch` segment's title |
| `buttonCompact` | `.callout` semibold | Compact buttons |
| `chipValue` | `.headline` bold mono | Figures of metric chips, icon metrics, large delta tags |
| `chevron` | `.caption2` bold | Chevrons and direction triangles |
| `link` | 12 pt semibold | A card header link (`HeaderLink`) |
| `footerLink` | 12.5 pt semibold | A card footer link's title (`CardFooterLink`) |
| `backTitle` / `backChevron` | 15 pt medium / 17 pt semibold | The back capsule's name and chevron (`BackCapsule`) |

Sizes above are the Mac's (macOS has no Dynamic Type). On iOS every role follows a text style, so
Dynamic Type scales it: `label`, `badge`, `annotation` → `.caption2`; `metric` → `.title2`; `hero`
and `display` → `.largeTitle`; `heading` → `.title2`; `quote` → `.title3`; `figure` → `.headline`; `title` and `subtitle` → `.title`; `symbol` → `.subheadline`;
`panelFigure` → `.largeTitle`; `symbolCompact` → `.footnote`; `link` → `.footnote`; `footerLink` and `backTitle` → `.subheadline`; `backChevron` → `.body`. At the default text size these match the design within a point or two.

## Lines (`Tokens.Stroke`)

| Token | Value | Use |
|---|---|---|
| `hairline` | 0.5 pt | Grids, chart guides |
| `thin` | 1 pt | Card borders, separators, level lines |
| `regular` | 1.5 pt | Indicator lines, outlines |
| `bold` | 2 pt | Price lines, sparklines |
| `ring` | 12 pt | Rings |
| `gauge` | 5 pt | Small gauge ring (`MiniRing`) |
| `dash` | 5 on, 4 off | Stop and entry levels |
| `dashFine` | 3 on, 3 off | Crosshair, planned outlines |

## Opacity (`Tokens.Opacity`)

| Token | Value | Use |
|---|---|---|
| `wash` | 0.10 | Banner backgrounds, a selected chip's wash |
| `glow` | 0.14 | Light background glows |
| `faint` | 0.35 | Volume bars, inactive fills |
| `shadow` | 0.12 | Light card shadow |
| `border` | 0.45 | Accent-tinted borders |
| `muted` | 0.55 | A faded mark (the loader's beam tail, the live brand mark's fade) |
| `medium` | 0.70 | Inactive elements, pulse start |
| `overlay` | 0.85 | Readouts over content |
| `flash` | 0.22 | A new row's tint as it arrives (`arrivalFlash`) |
| `rowHover` | 0.06 | A footer link's row under the pointer (`CardFooterLink`) |
| `tint` | 0.14 | A tinted chip's fill (the footer link's chevron chip) |
| `badgeFill` | 0.14 | A `Badge`'s fill (`.u-badge`) |
| `linkHover` / `linkOutline` | 0.20 / 0.22 | A header link's fill under the pointer and its tinted outline (`HeaderLink`) |

## Text is never cut

Owner rule (2026-11-16): no truncated or clipped text anywhere in the apps, in English and Russian.
A text that does not fit wraps, or its layout adapts (a row stacks, a column widens, a card grows
or its pane scrolls); a font never shrinks below its token, and nothing is hidden to make room.
A text that must stay on one line (a chip, a badge, a figure) takes its whole width with
`.fixedSize()`, and the layout around it makes the room. So the apps use no `.lineLimit`,
`.truncationMode`, `.minimumScaleFactor` or `.allowsTightening`: rule `truncation` of
`apps/scripts/check_swift_rules.py` rejects them on every pull request, and the layout sweep
(`.github/workflows/layout-sweep.yml`) reads every picture with `apps/scripts/find_truncated_text.swift`
and fails on any text that ends in an ellipsis the String Catalogs do not have.

A card link ("Open chart", "Details") ends only with the disclosure chevron (`HeaderLink`,
`CardFooterLink` in TickrDesign); its title carries no arrow. "→" stays only inside data
("7.15 → 7.48").

## One look per element

Owner rule (2026-11-16): the same element looks the same on every screen of both apps, and the
apps follow the design boards. A control drawn on both apps is one TickrDesign component; an app
arranges components and never restyles them. `apps/scripts/check_swift_rules.py` checks it in
apps/macos and apps/ios on every pull request:

- rule `styles`: no `ButtonStyle`, `PrimitiveButtonStyle`, `ToggleStyle` or `LabelStyle` of an
  app's own; every control look lives in TickrDesign;
- rule `system-buttons`: no system button look (`.bordered`, `.borderedProminent`,
  `.borderless`, `.link`, `.buttonBorderShape`). A button whose label is its own face (a
  `HeaderIcon`, a bare glyph in a row, a calendar's arrows) takes `.buttonStyle(.glyph)`;
- rule `controls`: no system segmented `Picker` (`.pickerStyle(.segmented)`,
  `SegmentedPickerStyle`), only `SegmentSwitch`; no chip look of an app's own (a `ViewModifier`
  named …Chip…), only `ChipFace` and the `.chip` styles;
- rule `symbols`: one SF Symbol per meaning (`Symbols` below); a symbol competing with a shared
  one (`chevron.left` for "previous", the outlined triangle for "failed") fails;
- rule `components`: no view or style type name declared in both apps. A screen or card of one
  app (a name ending in View, Card, Page, Sheet, Panel, Section, Screen or Chart) is that app's own
  arrangement; the pairs written before the rule are listed in the script (`KNOWN_TWINS`) until
  they move into TickrDesign, and a test keeps that list from going stale.

Which component shows which fact, on both apps:

| Fact | Component | Board |
|---|---|---|
| Configuration valid / invalid | `StatusPill` with `Symbols.passed` / `Symbols.failed` (Mac Settings › Config, iOS Settings and Configuration) | MacSystem, IOSSystem ("✓ VALID") |
| Trading gate open / closed | `Badge` (`profitText` open, `warning` closed; the cause in the hint or the caption under it): Mac Overview header, iOS Settings | Main ("GATE OPEN") |
| A strategy version ("v3") | `Badge(verbatim:color:keepingCase: true)` / `Badge(keepingCase:)`: a version keeps its own case, never "V3" | MacLab, IOSHome |
| Planned, not built yet | `Badge(_:tone: .highlight, planned: true)` (the Mac's `Badge.backlog` adds the BACKLOG hint) | every board's `.bl` |
| A day's clean-day verdict | `Badge` (`profitText` "Clean day · broker and records agree", `warningText` "Needs a look"), words only: Mac Trades and Overview headers (`CleanBadge`, the causes in the tooltip), iOS Home's recorded day (the first cause under it) | MacTrades, Main, IOSHome |
| A segmented switch (Mac Settings theme, Chart range and type, Lab replay span, Activity panes, Watching closely sort) | `SegmentSwitch`; `fit:` sizes segments to their titles (Mac Chart); a `DesignGlyph` may lead a segment (the chart type: candles / line, both apps, a row of its own on iPhone) | Controls, Activity (`.u-seg`) |
| A chip (Chart symbols, ranges' intervals, studies, LIVE, zoom; Lab version and day pickers; a symbol's screeners) | `ChipFace`: `.buttonStyle(.chip(selected:tone:))`, `.toggleStyle(.chip)`, `.chipFace(selected:tone:)` on a `Menu` label, `.chipFace(selected: false, small: true)` for data | Controls (`.u-chip`, `.u-chip.sm`) |
| A Lab version's role (active / trades, observer, candidate) | `Badge(_:tone:)`: `accent`, `highlight`, `warning`; no dot, no symbol | MacLab, IOSLab |
| The configuration as running (Mac Settings › Config) | `Badge(_:tone:)`: "Same as running" `neutral`, "Changed since start" `warning` | MacSystem |
| A symbol's outcome (Mac Symbols) | `Badge`: Passed `profitText`, "At <stage>" `infoText`, "Dropped · <stage>" `seriesATRText`, "Not reached · <stage>" `warningText`; the detail after it in `textSecondary`; WATCH as a blue `Badge` beside it (`VerdictTag`) | MacSymbols |
| A verdict tag (WATCH, IGNORE) | `Badge` in the verdict's colour (Mac `VerdictTag`, iOS `WatchingRow`) | Main, IOSPosition, MacSymbols |
| A trade's reason tag (OPEN, an exit reason, REFUSED, NOT EVALUATED) | `Badge` (Mac Trades table, iOS Activity rows); the tones are `ui-one-meaning`'s exit map | MacTrades, IOSActivity |
| A stop's state in a position's detail (VERIFIED) | `Badge`: `profitText` verified, otherwise `warningText` (Mac "Position on chart") or `lossText` (iOS position chain) | MacChart, IOSPosition |
| "Show all N" under a card's rows | `CardFooterLink` with the count and the hint "closest 3 of N" (Mac Overview and iOS Home Watching closely) | Controls, Main |
| A link in a card's header | `HeaderLink`; one that pushes a screen is a `NavigationLink` with a `HeaderLinkLabel`, styled `.headerLink()` (iOS Home live flow "slots 2 of 3 ›") | Controls, IOSHome (`.hlink`) |
| The demo day | Once per screen: the header's `EnvironmentBadge` (dashed violet DEMO), as IOSHome `envLabel` and Main draw it; Mac Settings › General shows the same badge beside its switch. Every command while the demo is on carries a `CommandTag` (dashed violet DEMO, IOSHome `.dm`, Main `.demo-tag`). No second chip next to the day | IOSHome, Main |
| Retry after a failed read | `.action(.secondary, size: .compact)` | Controls, IOSPosition |
| The way back to today | `TodayButton`: the Mac title bar's Today, the iPhone's Home day line and Activity calendar | Mac boards (`.tbtn`) |
| The way back from a pushed screen | `BackCapsule` + `.backCapsule` (iOS `BackButton`, the Mac Lab's advisor page) | Controls |
| The Mac title bar's buttons (sidebar, ‹ ›, Today) | `TitleBarButtonStyle` (`.titleBar(square:)`), one size: `width` × `height` 32 × 28 pt (macOS's regular control height), radius 7 | Mac boards (`.tbtn`) |
| A header's icon button (iOS) | `HeaderIcon` in a `.glyph` button: the 40 pt glass circle in a 44 pt touch target | iOS boards (`.gbtn`) |

Mockups v98 and v99 settled the boards that drew an element more than one way (segmented
switches, chips, the Lab version role, the clean day): each is now the one component above.
`check_swift_rules.py` rule `controls` keeps it so: no system segmented `Picker` and no chip look
of an app's own in the apps. Still to come, each in its own change: the Chart rail's past-day tags
(TRADED, WATCHED, SKIPPED) once the API gives a past day's symbols; `EnvironmentBadge` and the demo
chip (after #499).

On iOS every chip and every link answers taps over `Size.touchTarget` (`touchTarget()`), drawn
size unchanged.

## Symbols (`Symbols`, TickrDesign)

| Symbol | SF Symbol | Meaning |
|---|---|---|
| `previous` / `next` | `chevron.backward` / `chevron.forward` | One step back or on (days, months, the back capsule, a link's disclosure chevron); turn with the reading direction |
| `pause` | `pause.fill` | Paused: entries paused, the Pause command |
| `failure` | `exclamationmark.triangle.fill` | A read or an action that failed (a failed day, chart bars that did not load) |
| `passed` / `failed` | `checkmark.circle.fill` / `xmark.circle.fill` | A check that passed or failed: a valid configuration, a verified backup, a command done or refused |

## Sizes (`Tokens.Size`)

| Token | pt | Use |
|---|---|---|
| `dot` / `dotSmall` | 8 / 6 | Status dots |
| `iconWell` / `iconWellSymbol` | 44 / 15 | Round icon wells |
| `stage` | 52 | Stages of the live flow |
| `stageGlyph` | 22 | The line glyph in a live-flow stage (`DesignGlyph`, the board's own paths, 2 grid units = 1.8 pt stroke) |
| `menuGlyph` | 13 | The settings gear (`DesignGlyph.settings`) in the macOS menu-bar panel, at `Stroke.glyphHeavy` (2.2 grid units); elsewhere the gear is stroked at `Stroke.gear` (1.9). Both apps draw this one gear for Settings (iOS Home header, Mac menu bar, Mac Settings General tab), never an SF Symbol |
| `dayResultWidth` | 300 | Overview's day result beside the header |
| `gridColumnMin` | 300 | Narrowest column of a card grid before it stacks |
| `logo` / `logoSmall` / `emptyMark` | 64 / 26 / 88 | Brand mark (`BrandMark`): the tick-shaped price line of the app icon |
| `sparkline` | 34 | Sparkline height |
| `bar` | 8 | Progress bar height |
| `barThin` | 4 | Thin progress bar inside a row (Watching closely) |
| `ticker` | 22 | Ticker strip height |
| `flowMark` | 7 | A symbol's dot on the live flow board |
| `flowChip` | 96 | Least width of a live-flow symbol chip |
| `sideColumn` | 378 | Side column of cards |
| `contentMaxWidth` | 1500 | Content stops growing and centres |
| `shadowRadius` / `shadowOffset` | 10 / 6 | Light card shadow |
| `riseOffset` | 12 | Rise-in distance |
| `touchTarget` | 44 | Least height of a large button |
| `iconButton` / `iconButtonCompact` | 36 / 28 | Round icon buttons |
| `glyph` / `glyphCompact` | 30 / 22 | State glyph tiles |
| `rowSymbol` | 16 | Symbol column of a `ValueRow` |
| `miniRing` | 52 | Small gauge ring |
| `hintMaxWidth` | 260 | Widest hint bubble |
| `popover` | 340 | Widest a detail popover grows (a live-flow stage's details); it narrows and wraps where the screen is narrower, never clips |
| `glowRadius` | 8 | Glow under a primary button |
| `ringHalo` | 60 | Reach of the halo behind a ring |
| `glassShadowRadius` / `glassShadowOffset` | 7 / 4 | Soft shadow under a glass control (`glassSurface`: back capsule, header icons) |
| `headerLink` | 24 (Mac) / 30 (iOS) | A card header link's capsule (`HeaderLink`); on iOS its touch target is `touchTarget` |
| `footerLink` / `footerChip` | 36 (Mac) / 44 (iOS), 22 | A card footer link's row and its round chevron chip (`CardFooterLink`) |

## Motion (`Tokens.Motion`)

| Token | Curve | Use |
|---|---|---|
| `quick` | snappy | Values rolling, toggles, selection |
| `standard` | spring 0.5 s, damping 0.85 | Views in and out, list changes, section switch |
| `entrance` | spring 0.7 s, damping 0.85 | Cards rising as a screen appears |
| `fill` | spring 1.2 s, damping 0.9 | Rings, bars, counters filling |
| `draw` | ease-out 1.4 s | Lines and charts drawing themselves |
| `stagger` | 0.05 s | Delay between cards of a screen |
| `pulseSeconds` / `pulseScale` | 2.4 s / ×2.2 | One pulse ring per real event (never a loop) |
| `breatheSeconds` / `breatheScale` | 2.4 s / ×1.08 | One swell of a glow when its value changes (never a loop) |
| `rotationSeconds` | 3 s per turn | Radar sweep; it and the blips move only while the bot runs with live, fresh status (`OrnamentGate`), still otherwise |
| `blipScale` / `blipLagSeconds` | ×1.9 / 0.8 s | The radar's two blips: each one's ring (every `pulseSeconds`, ornament) and the second one's lag; also the session now dot's ring, once each time now passes a mark of the session (open, last entry, flatten, close) |
| `openingSparkDelaySeconds` / `openingSpark` | 0.45 s / ease-out 0.25 s | macOS opening: the spark pops in as the line nearly ends |
| `cellStagger` | 0.025 s | Delay between the tiles of a grid filling in (Trades calendar, on appear and month change) |
| `hoverLift` / `cellLift` | 1 pt / 2 pt | Rise of a button, and of a calendar tile, under the pointer (`quick`) |
| `flash` / `flashSeconds` | ease-out 1.6 s | A genuinely new row's tint fading out (journal, not-taken signals), once per row |
| `themeFadeSeconds` | 0.4 s, ease-in-out | Cross-fade when the appearance is switched in Settings (`ThemeFade`: a picture of each window in the old appearance fades out; the sidebar's glass and the title bar switch at once) |
| `tickerSpeed` | 22 pt/s | Event ticker (edges fade over 6% of its width) |
| `tickerLoopSeconds` | 45 s | iOS Home ticker: the whole row passes once (the board's marquee) |
| `pop` / `popStagger` | spring 0.5 s, damping 0.55 / 0.4 s | A dot popping in (`popIn`): the protection chain's steps, one after another, and again when a step changes |
| `bump` / `bumpSeconds` / `bumpScale` | ease-in-out, two halves of 0.6 s / ×1.35 (iPhone), ×1.25 (Mac) | A count growing and settling once when it rises (`bumps(on:)`: Lab refusal counts), never when it falls or first appears |
| `pressScale` | ×0.97 | Buttons and chips while pressed |
| `rowPressScale` / `backPressScale` | ×0.99 / ×0.96 | A footer link's row and the back capsule while pressed |
| `linkNudge` | 2 pt | A footer link's chevron chip moving on under the pointer |
| `glyphPulseScale` | ×1.35 | Pulse outline of a live state glyph, once per event; also today's Trades calendar tile, once per change of today's trading (a trade closed, a position opened or closed) |
| `shineSeconds` | 3.5 s | One pass of the light across the Lab's AI advisor title (ornament, `OrnamentGate`); Core Animation runs the sweep (`ShineBand`), like the brand halo and the ticker |
| `hintDelay` | 0.45 s | Hover before a hint appears (Mac) |
| `clockTickSeconds` | 1 s | Redraw of clocks, ages ("3 s ago") and the session bar's cursor |
| `nowGlide` | linear, `clockTickSeconds` (1 s) | The session strip's now line (Settings) gliding to each new minute, at an even pace: one move per real change of the time |

## Loss-room ring (`Tokens.Room`)

| Token | Share of the daily limit | Use |
|---|---|---|
| `calm` | 0.5 | Room below it turns the ring amber |
| `alarm` | 0.2 | Room below it turns the ring red |

## Candle charts (`Tokens.Chart`)

| Token | Value | Use |
|---|---|---|
| `pricePadding` | 0.08 | Space above and below the visible prices, share of their range |
| `volumeShare` | 0.22 | Height of the volume bars, share of the price range |
| `zoomStep` | ×1.5 | Candles shown per zoom step |
| `studyPaneHeight` | 44 | Each study pane under the Mac's price pane (volume, ATR, RSI, MACD, stochastic), fixed |
| `priceMinHeight` / `priceMaxHeight` | 240 / 420 | The Mac's price pane fills what the study panes leave of the card, clamped (420 with the default panes) |
| `timeAxisHeight` | 22 | The time axis's labels under the Mac chart's bottom pane |
| `axisLabelHeight` / `levelTagHeight` | 13 / 17 | A price axis label and a level tag; a label closer to a tag than half of both is hidden |

The Mac chart's panes (`PaneStack`, mockup v103) ask for exactly price + panes + time axis, so the
card holds them whole: nothing is clipped and nothing scrolls inside. The price axis's own labels
give way to the level tags (last price, entry, stop, H / L) on both apps (`AxisLabels` in
TickrKit): "11.80" is never drawn under "L 11.78".

The price scale holds the candles on screen, the levels drawn across the chart (an open
position's entry and stop) and every line that is switched on over them (VWAP, the EMAs, the
moving averages, the Bollinger bands), so a VWAP far above the price is drawn, not cut
(`ChartPriceSpan`). Every series and marker is clipped to the plot: a value off the scale ends at
the plot's edge and never draws over the controls around the chart.

Statistics on the Lab and performance cards use `StatDigits` (`Formatting.swift`): mean R and
profit factor with 2 decimals, win rate and confidence in whole percents.

## Components

| Component | Where | Rule |
|---|---|---|
| Card | `tickrCard()` + `CardLabel` | `surface` (`surfaceSunken` for the Mac journal's console), `Radius.card` (iOS) or `Radius.large` (Mac), `Space.l` padding, `separator` border; light mode adds `shadow`. Cards sharing a grid row are one height (`filling()` on the Mac); in a row of a set height a card scrolls under its header when its content is taller (`ScrollsWhenTall`) |
| Card grid (Mac) | `Grid` of cards | Fills the window's width: equal columns of at least `Size.gridColumnMin`, `Space.l` apart; a narrower window stacks into fewer columns |
| Overview grid (Mac) | `WeightedColumns` | As the Main board: Live flow across the width; Watching closely, Positions, Safety with the bot at 1 : 1.4 : 1 in a 298-point row (cards scroll inside). The "Safety · bot" card has the bot's state pill in its header, the safety facts as `surfaceSunken` tiles in two columns (compact glyph, name in `caption`, value in `annotation` in its tone), then every command as small labelled buttons in two columns; the tiles scroll when the card is short, the commands never do; Risk room, Observers, the journal at 1 : 1 : 1.4 filling the rest of the window's height (at least 150 points). Below a 1040-point screen: Positions across, then the cards in two equal columns |
| Header link | `HeaderLink` (TickrDesign); `HeaderLinkLabel` + `.headerLink()` for a `NavigationLink` | A card header's way elsewhere (Details, Lab, Open chart, Full chart, Review, the iOS live flow's "slots 2 of 3"): a capsule `Size.headerLink` tall, its tone (`info`; `highlight` in the advisor's box) at `Opacity.wash` fill (`linkHover` under the pointer) and `linkOutline` stroke, text in the tone's text colour in `Typography.link`, an optional leading symbol, the disclosure chevron last (never an arrow) |
| Footer link | `CardFooterLink` (TickrDesign) | A card's "Show all" (Watching closely on both apps): the card's last row, across its whole width under a `separator` hairline, `Size.footerLink` tall and one button: title in `footerLink` `textPrimary`, a count capsule (`annotationBold`, `surfaceSunken`), an optional hint right-aligned in `annotation` `textQuaternary`, then a `footerChip` circle of `info` at `Opacity.tint` holding the chevron in `infoText`; under the pointer the row tints `info` at `rowHover` and the chip moves on `linkNudge` |
| Back capsule | `BackCapsule` + `.backCapsule` (TickrDesign) | The way back from a pushed screen (iOS `BackButton`, the Mac Lab's advisor page; available to the Mac's Symbols screen): glass capsule `Size.iconButton` tall, chevron and name both `textPrimary`; pressed ×`backPressScale`, dimmed to `Opacity.medium` |
| Loading | `Skeleton`, `.inFlight(_:)`, `ProgressLine` (TickrDesign) | See "Loading" below: a skeleton for content, a spinner in the button for a command in flight, a 2 pt line for an operation of known length; never a radar, never the system spinner |
| Section label | `CardLabel` | `Typography.label`, uppercase, `textLabel` |
| Stat row | label … value | label `callout` `textTertiary`, value `bodyMono` |
| Badge | `Badge` (TickrDesign) | The apps' one badge (`.u-badge`), for a fact (exit reason, version, role, the trading gate, a day's clean verdict, an outcome): `Typography.badge` uppercase, tone text colour, `Opacity.badgeFill` (14 %) fill, `Opacity.border` (45 %) stroke, `Radius.small`, `Space.xs` × `Space.s` padding; words only, but for a leading symbol where a board draws one (`Badge(_:symbol:tone:)`: the closed gate's lock in `Typography.badgeSymbol`); `planned:` draws it dashed; a version keeps its own case (`keepingCase`) |
| Environment badge | `EnvironmentBadge` (TickrDesign) | The environment the bot runs in, the one look on every screen of both apps (Mac window header, Mac menu-bar panel, Mac Settings › Environment, iOS Home header, iOS Settings › Environment); never a hand-built chip, `StatusPill` or plain `Badge`. A `Badge`: the localized name in capitals, `Typography.badge`, `Radius.small`, `Opacity.badgeFill` fill and `Opacity.border` stroke in the tone that `EnvironmentBadge.Kind` picks from the status value: Sandbox `warning`, Production `loss`, the demo day `highlight` with a `dashFine` dashed edge, an unknown value `neutral`. VoiceOver reads "Environment: Sandbox" everywhere (`ApiText.environmentLabel`, a required argument). Mac Settings › Environment shows the gate's open/closed `Badge` beside it, as the Overview header does. No size variants |
| Command button | bot controls | `ActionButtonStyle` below |
| Live-flow chips (Mac) | `Marquee` | The screeners' symbols scroll across the top of the live flow: symbol in `chip`, below it the screener and change % in `annotation`, coloured by screener (gainers `profitText`, top actives `infoText`, losers `seriesATRText`; left out of the universe "skipped" in `textQuaternary`, struck through, the cause on hover); `surfaceSunken` fill, `separator` hairline, `Radius.medium`, at least `Size.flowChip` wide. Still on a recorded day. The latest event sits in the card's header before the clock, cut first when the title needs the room |
| Watching row (Mac) | `WatchingRow` | `surfaceSunken` box with `separator` hairline, `Radius.medium`: symbol in `chip`, verdict as a `Badge` (`VerdictTag`; IGNORE in `seriesATRText`), time in `annotation`; the deciding check in `captionMono`; closeness as a `barThin` capsule in the tag's colour, a dashed `dashFine` outline when unknown |
| Live-flow board (Mac) | `Pipeline` dots | Under each stage's value, today's symbols whose furthest stage it is (`FlowBoard`), as `flowMark` dots in the stage colour, at most 8 then "+N", wrapping within 104 points; amber while the broker stop waits, red if never confirmed. Universe and risk have a dashed tray, "left out" (`textQuaternary`) or "refused" (`seriesATRText`), naming the first two symbols and how many more, each one's reason on hover. A stage with no symbols shows nothing under it. A dot flies to its new stage (`matchedGeometryEffect`, `Motion.standard`) only when a new read moves it; hover names the symbol and the reason |
| Live-flow stage | pipeline | `Size.stage` circle filled with the stage colour at `Opacity.glow` over the card, `Stroke.bold` ring and a soft glow in the stage colour; name in the stage's text colour |
| Accent | `.tint` | `info` for links, selection and system controls on both apps, never the system blue |
| Planned tag | `Badge(planned: true)` (Mac: `Badge.backlog`) | BACKLOG: the `Badge` in `highlight`, dashed `dashFine` outline, no fill, `Radius.small` |
| Planned stretch | `Hatch` (TickrDesign) | `highlight` stripes running down to the right, 6 pt (Mac) or 4 pt (iPhone) wide with gaps as wide, at 18% (Mac) or 25% (iPhone); `moving:` drifts them right at 28.3 pt/s (the design's 34 px per 1.2 s, Core Animation), an owner-requested ornament only while the bot runs with live, fresh status (`OrnamentGate`) |
| Pulse dot | `PulseDot` | `Size.dot`; while `pulsing`, one ring of `pulseSeconds` each time its `event` changes (a new status read, a fill). Still without an event: nothing on screen moves except on real events |
| Headline pill | `HeadlineBanner` (`Tokens.Headline`) | See "One meaning, one look": the pill and, beside it, the countdown and the gate badge (mockup v108) |

## Loading (`Tokens.Loading`, mockup v102)

Loading uses a skeleton or a spinner, never a radar: the radar is only the empty "no positions"
state's ornament (Mac Overview). Mac and iOS are identical, except the spinner's size. The `loaders`
rule of `check_swift_rules.py` rejects anything else in the apps: `ProgressView`, `TickrLoader`
(removed), `.redacted(reason: .placeholder)`, a `…Shimmer…`, `…Spinner…` or `…Loader…` type of
an app's own, and a radar outside the empty-positions state.

| Piece | Component | Rule |
|---|---|---|
| Content loading | `Skeleton` + `SkeletonBlock`, `SkeletonGridLine`, and the shapes `SkeletonLines`, `SkeletonRows`, `SkeletonTiles`, `SkeletonCandles`, `SkeletonPane`, `SkeletonTimeAxis` | The shape of the real layout, in its own frame and column grid; nothing real is shown until the data is ready. Blocks: `separatorStrong` mixed 60% into `surfaceSunken`, radius 5; a text line 9 high (radius 4), a value 16, a pill 20 (radius 6). Grid lines `separator` at 45%. Shimmer: a 110° band, clear → `textPrimary` at 5% → clear (stops 35/50/65%) over 250% of the width, sweeping from 120% to −20% in 1.6 s ease-in-out, again and again. Reduce Motion: no sweep; the skeleton pulses 1 → 0.6 → 1 over 2.4 s. One VoiceOver element, "Loading…" (or the Chart's caption) |
| Chart loading (both apps) | `LoadingChart` of each app | The axis grid, a faint candle silhouette, the price and time axes, every enabled study pane, and the header's price, change and OHLC (Mac) or day's high, low and volume (iOS) as skeleton; the toolbar stays live; "Loading ABCD · 1 min bars" in the plot's top left |
| Symbols loading | each app's `SymbolsSkeleton` | Mac: 18 skeleton rows in the rows' column grid and a skeleton detail card; iOS: 9 two-line rows |
| Command in flight | `.inFlight(_:)` on a `.command` or `.action` button | `Spinner` in the glyph's place (Mac 16 pt / 2 pt stroke, iOS 20 pt / 2.5 pt; track `textTertiary` at 22%, a quarter arc in `textTertiary`, one turn in 0.9 s, linear; Reduce Motion: still, pulsing), the label becomes the in-progress words ("Closing ABCD position", `OperatorCommand.inFlightTitle`, `InFlightText`); the button is not dimmed, a second click does nothing, VoiceOver reads the words |
| Known length | `ProgressLine` | 2 pt, radius 2, track `info` at 18%, fill `info`, its width easing to a new value in 0.3 s (at once under Reduce Motion); the caller writes the caption ("Replay · 12 of 30 days · 40%"). Not wired yet: the Lab replay API reports no share done |

## Controls (`Controls.swift`)

Screens show states, figures and actions as these controls, not as bare text or system-styled
buttons. Prefer a symbol, a gauge or a coloured shape to a word whenever the meaning is clear;
the word then goes into the control's `hint` (tooltip) and its accessibility label, so VoiceOver
still reads it. Every control takes a `Tone`.

| Control | Use | Look |
|---|---|---|
| `Tone` | The meaning of a control | `neutral`, `accent`, `profit`, `loss`, `warning`, `info`, `highlight`, `series` (the ATR pink: a stop-out's tag): each maps to a role's fill and text colour; `Tone.result(_:)` for money |
| `.buttonStyle(.action(.primary))` | The one main action of a view | `accentFill` with a `sheen` gradient on top, `onAccent` text, accent glow (`Size.glowRadius`), `Radius.medium` |
| `.action(.secondary)` | Ordinary commands | `surfaceSunken`, `separatorStrong` border, accent border on hover; `role: .destructive` draws it destructive |
| `.action(.ghost)` | Quiet link-like actions ("Open chart" + `Chevron`) | `accentText`, accent wash on hover or press |
| `.action(.destructive)` | Destructive actions outside the bot's commands | `lossText` on a `loss` wash and border |
| sizes | `.compact` (inline), `.regular`, `.large` (phone sheets, at least `Size.touchTarget` tall) | `Typography.buttonCompact` / `button` |
| `.buttonStyle(.icon(tone))` | One-symbol actions | `Size.iconButton` circle (`iconButtonCompact`), tone wash and border; needs a `hint` |
| `.buttonStyle(.glyph)` | A button whose label is its own face (`HeaderIcon`, a bare glyph in a row, a calendar's arrows); never the system's borderless look | No chrome or colour of its own; pressed ×`pressScale` and dimmed to `Opacity.medium`; a label that fades while disabled takes `dimmedWhenDisabled()` |
| `.buttonStyle(.washPress(color))` | A tile that opens its details (the iOS live flow's stages) | Its colour at `Opacity.wash` behind it while held, ×`pressScale` (none under Reduce Motion) |
| `.buttonStyle(.titleBar(square:))` (Mac) | The title bar's sidebar, ‹ › and Today | `chipFill`, `separatorStrong` hairline, label `textTertiary`; 32 × 28 pt, radius 7; a titled one as tall with `Space.s` sides |
| `TodayButton` | The way back to today, wherever a day can be changed | Mac: a titled `.titleBar`; iOS: `.action(.ghost, size: .compact)` |
| `.buttonStyle(.command(tier))` | The bot's commands (both apps): `.secondary(tone)` pause, resume, cancel orders; `.destructive` close a position, Close all, stop the bot; `.primary` start the bot | A `Command.glyph` tile (`Command.glyphRadius`) then the title left-aligned, wrapping, never cut; `Command.height` (36 pt Mac, 50 pt iOS; `compact` 32 pt), `Command.radius`, soft shadow. Secondary: `surface`, `separatorStrong` border, glyph in its tone on an `Opacity.glow` tile. Destructive: `loss` wash, `loss` border, `lossText`, solid `lossFill` tile with an `onLoss` glyph. `detail:` puts a few mono words after the title in the command's colour, always whole (the menu bar's Close all: "2 positions", plural forms from the String Catalog). `tag:` puts a violet `CommandTag` ("DEMO") at the end. A trailing "…" in a title means it asks first |
| `EmergencyButton` | The emergency stop, always last, after a `LastResortDivider` | Full width, solid `lossFill`, `onLoss` bold title with a second line (`Command.detailOpacity`), `loss` `Command.halo` ring. With `hold:` (Mac) it acts only after `Command.holdSeconds` held, a dark `scrim` sweep filling from its glyph; release or moving away cancels; the accessibility action skips the hold; Reduce Motion stills the sweep |
| `CommandColumns(columns:)` | A row of commands | Equal columns, as many as fit each title on one line, down to one per row; one height per row |
| `ChipFace` / `.buttonStyle(.chip(selected:))` / `.chipFace(selected:)` | Every chip: one of a few choices side by side (position tabs, the Chart's symbols and intervals, zoom, LIVE), a `Menu`'s label (Lab version and day pickers), a symbol's screeners (`small`) | The boards' `.u-chip`: `chipTitle` in `textSecondary` on `surfaceSunken`, `separatorStrong` hairline, `Radius.chip` (6 pt), `Space.xs` × `Space.s` padding; selected: `textPrimary`, outlined in its tone with an `Opacity.wash` wash; `small`: `chipSmallTitle`, `Space.xxs` × 6 pt; on iOS at least 32 pt tall, answering taps over `Size.touchTarget` |
| `SegmentSwitch` | The one segmented switch of both apps (the iOS Activity panes, the Chart range and type, the Lab replay span, Watching closely sort, the Mac theme); never `Picker(.segmented)` (rule `controls`) | The boards' `.u-seg`: segments on a `surface` track with a `separator` hairline, 12 pt corners, 3 pt padding, `Space.xs` gaps; titles `segment` in `textTertiary`, wrapping rather than cut, an optional 12 pt `DesignGlyph` before; chosen: `textPrimary` on a 9 pt `surfaceSunken` tile with a `separatorStrong` line under it; at least 32 pt (iOS) / 28 pt (Mac) tall; `fit:` sizes segments to their titles; on iOS each segment answers taps over 44 pt. `init(options:shown:)` shows a choice made elsewhere (the iPhone Settings environment: Sandbox \| Production): nothing to tap; an option with `locked:` carries `lock.fill` and a dashed `separatorStrong` edge in `textQuaternary` |
| `.toggleStyle(.chip)` | An on/off choice among chips (the Chart's studies, trade marks, both apps) | The chip above, title uppercase; on: the selected chip; off: the plain chip |
| `StateGlyph` | A state without a word (paused, stream fresh, gate closed; a stop's protection through `StopGlyph`) | SF Symbol on a `Size.glyph` tile in the tone, `Opacity.glow` fill; `live` pulses the outline (`Motion.glyphPulseScale`) |
| `StatusPill` | A state that needs its word (bot running, a stop's state in a row) | Capsule, `PulseDot` (one pulse per `event` while live) or a `systemImage` in its place, `Typography.badge` uppercase |
| `IconMetric` | A figure named by a symbol (entry, stop, quantity, time) | Symbol in the tone, `Typography.chipValue` figure, sunken `Radius.medium` chip; the name is its hint. `compact`: a `Radius.small` chip that fits its figure (`captionMono`), in rows under a list item |
| `ChipFlow` | A row of chips under a list item | Layout that wraps chips onto new lines (`Space.xs` apart) instead of clipping on a narrow phone or at large Dynamic Type |
| `MetricChip` | A figure whose label must stay visible | Uppercase `label`, `chipValue` figure, unit in `captionMono`, tone rail on the leading edge |
| `DeltaTag` | A money change | Triangle up or down, signed figure, `Tone.result` wash |
| `MeterBar` | A share of a whole, a price between two levels (a gauge; never an operation's progress, which is `ProgressLine`) | `Size.bar` capsule track, glowing gradient fill that grows on appear (`Motion.fill`), optional `MeterMark` figures under it |
| `MiniRing` | A share in a small space | `Size.miniRing`, `Stroke.gauge` track and fill, figure inside |
| `.grows(with:step:)` | A bar showing a value (observer results, refusal counts, advisor intervals) | Grows in from its leading edge on appear (`Motion.fill`, `stagger` apart), then moves to its new length only when its value changes |
| `.drawsIn(on:)` | A line or chart (sparklines, Trades' R curve, the Lab's day curves) | Draws in from the left on appear and once per change of its data (`Motion.draw`) |
| `CountingText` | A figure (Trades' performance figures, Risk's balances) | Counts up from zero on appear and on to each new value (`Motion.fill`) |
| `.arrivalFlash` / `.onArrival` | A row the bot just added (journal line, not-taken signal) | One `Opacity.flash` tint fading out (`Motion.flash`); none for the first rows shown or a whole new list |
| `ValueRow` | "◷ label … value" rows | Symbol in a `Size.rowSymbol` column, `callout` label in `textTertiary`, `bodyMono` value |
| `SectionHeader` | A section's heading with a count and an accessory | Glowing tone tick (`labelSize` tall), uppercase `label`, count capsule |
| `InfoCaption` | Where a value comes from, why something is off | `caption` with a leading symbol |
| `WarningBanner` | A standing state that changes where commands go (the demo day), on every command surface | Symbol and `callout` semibold title in the tone, `caption` detail in `textSecondary`; the tone's fill at `Opacity.wash`, `Stroke.thin` border at `Opacity.border`, `Radius.medium`, `Space.m` padding |
| `UnavailableState` | A view with nothing to show because its read was refused or failed (the chart's "Bars Unavailable" in both apps) | `ContentUnavailableView` with the warning symbol (`Symbols.failure`), the title, and the cause alone in the person's language (`ErrorText.cause`: never the API's status, error code or words); the plain message when there is no cause; the calm waiting caption while the link is down |
| `ConnectionNotice` | The link to the bot is down or not set up (TickrKit `ConnectionState`), the same on every screen of both apps (mockup v82, calm connection banner): `banner` over the last known data (drawn at `lastKnownOpacity`, 60%), `empty` in the card area when nothing was read | Neutral `tickrCard` (`Radius.large`) with an amber 28 pt glyph chip (`wifi.exclamationmark`), the title semibold (15 iOS / 13 Mac), one mono `annotation` line in `textTertiary` ("showing data from … · retrying every N s · commands off"), a compact secondary Retry and a ghost Settings link on the right (under the text when the row is narrow), then a quiet "Details" disclosure. No red, no pulse. Technical detail (address, the API's own words) only under Details, in `captionMono`, selectable |
| `.hint(_:)` | The apps' tooltip | Mac: a `Radius.medium` bubble on `surface` above the view (below it when there is no room) after `Motion.hintDelay` of hover, at most `Size.hintMaxWidth` wide, kept inside the window. It is drawn by `.hintHost()`, which every Mac window and panel root carries; a hint outside a host does not show. Phone: long press shows it in a context menu, which cancels the tap of the button it explains |

## Brand: app icon and launch screen

The product name people see is **Tickr** (bundle display name and the String Catalogs); code,
targets and the repository keep their code name. The mark is a price line drawn as a tick that
breaks upward, with a spark at its end.

- `apps/scripts/make_brand_assets.py` writes every brand file from one description, with colours
  from `Palette.swift`: the Icon Composer icon `AppIcon.icon` of each app (light, dark and tinted;
  the system adds Liquid Glass) and the iOS launch screen in `apps/ios/Tickr/Assets.xcassets`
  (`LaunchBackground` = `background`, `LaunchMark`). Change the script and run it; never edit the
  generated files. `tests/test_brand_assets.py` fails when they differ.
- In the apps the same line is `BrandMark` (TickrDesign): it draws itself on appear and its
  spark then sends out a halo ring (from the spark's size to `pulseScale`, fading from
  `Opacity.muted`, every `pulseSeconds`; ornament) while the bot's data is current (macOS
  Overview header, iOS Home bar); still otherwise and with Reduce Motion.
- iOS opening (`LaunchHandoff`): the app starts exactly as the launch screen, flashes the spark
  once, then flies the mark into Home's bar mark while the background fades (`launchHoldSeconds`,
  `launchFly`). Reduce Motion: a cross-fade (`launchFadeSeconds`).
- macOS opening (`BrandOpening`, macOS has no launch screen): the first window of a launch opens
  on the background with the mark (`openingMark`) in its centre, the line draws itself
  (`openingDrawSeconds`, once the window is on screen and key or active) and its spark pops in
  as the line nearly ends (`openingSpark`), then the mark flies into Overview's header mark
  (`openingFly`) while the background fades and the screen shows through, its cards rising one
  after another (`risesHeld` holds them until the flight starts). The header's own mark stays hidden until the flying one lands on it, so two marks are
  never seen. About 1 s in all. Once per launch (`AppModel.openingPlayed`), not on reopening the window.
  Reduce Motion: the same cross-fade.
- Empty screens (nothing yet, no trades, bot unreachable) use `BrandMark.empty()` as the
  `ContentUnavailableView` illustration, muted (`.muted`) when the bot cannot be reached. Errors
  keep a warning SF Symbol, so they never look like a calm empty state.
- macOS has no launch screen (Apple HIG). The menu bar extra keeps an SF Symbol, because it shows
  the bot's state; notifications and the About panel use the app icon.
