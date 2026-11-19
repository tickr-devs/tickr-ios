"""TickrKit strings for the bot's codes (ApiText), in English and Spanish.

`python3 apps/scripts/kit_api_strings.py` writes ApiCodes.swift, L10n+Codes.swift and
L10n+Rules.swift (parts of the kit's L10n) and the kit's catalog entries; run
apps/scripts/format_xcstrings.py after it.
`--check` writes nothing and fails when the committed files differ from this list
(tests/test_api_codes.py runs it, and also checks this list against the bot's own codes).
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / "apps/shared/Sources/TickrKit"

# (swift name, key, english, spanish, doc)
S = []


def add(name, key, en, es, doc):
    S.append((name, key, en, es, doc))


# entry_block.cause
B = "Why entries are blocked: "
for code, en, es in [
    ("bot_starting", "The bot is starting.", "El bot está iniciando."),
    ("bot_stopping", "The bot is stopping.", "El bot se está deteniendo."),
    ("bot_stopped", "The bot is stopped.", "El bot está detenido."),
    ("trading_gate_closed", "The trading gate is closed.", "La puerta de trading está cerrada."),
    ("entry_stop", "Entries stopped by the operator.", "Entradas detenidas por el operador."),
    (
        "strategy_not_loaded",
        "The active strategy is not loaded.",
        "La estrategia activa no está cargada.",
    ),
    (
        "entries_not_wired",
        "This build does not open trades on its own yet.",
        "Esta compilación aún no abre operaciones por sí sola.",
    ),
    (
        "own_trade_open",
        "The bot already has a trade open.",
        "El bot ya tiene una operación abierta.",
    ),
    ("no_session_today", "No regular session today.", "Hoy no hay sesión regular."),
    (
        "calendar_unknown",
        "The trading calendar cannot say whether the market is open.",
        "El calendario bursátil no puede decir si el mercado está abierto.",
    ),
    ("outside_regular_session", "Outside the regular session.", "Fuera de la sesión regular."),
    ("after_last_entry", "Past the last entry time.", "Pasada la hora de la última entrada."),
    (
        "daily_money_unknown",
        "A trade closed today has fills without a known price.",
        "Una operación cerrada hoy tiene ejecuciones sin precio conocido.",
    ),
    (
        "daily_ceiling",
        "Too little room left under the daily loss limit.",
        "Queda muy poco margen bajo el límite de pérdida diaria.",
    ),
]:
    add("block_" + code, "kit.block." + code, en, es, B + code)

# fence kinds (entry_block.cause uses them with "_" for "-")
F = "A fence (a block on new entries): "
for code, en, es in [
    (
        "startup_reconcile",
        "Startup reconciliation not finished",
        "Conciliación de inicio sin terminar",
    ),
    ("broker_read_failed", "Broker read failed", "Falló la lectura del bróker"),
    (
        "detail_budget",
        "Order detail request budget used up",
        "Cupo de solicitudes de detalle de órdenes agotado",
    ),
    ("unknown_order", "An order's outcome is unknown", "Se desconoce el resultado de una orden"),
    ("order_missing", "An order is missing at the broker", "Falta una orden en el bróker"),
    (
        "detail_unreadable",
        "An order's detail cannot be read",
        "No se puede leer el detalle de una orden",
    ),
    ("status_unknown", "An order's status is unknown", "Se desconoce el estado de una orden"),
    ("unprotected", "A position has no verified stop", "Una posición no tiene stop verificado"),
    ("over_protected", "A position has more than one stop", "Una posición tiene más de un stop"),
    (
        "unprotected_timeout",
        "A position stayed unprotected too long",
        "Una posición estuvo sin protección demasiado tiempo",
    ),
    ("stop_rejected", "The broker rejected a stop", "El bróker rechazó un stop"),
    ("exit_refused", "An exit was refused", "Se rechazó una salida"),
    (
        "cancel_unknown",
        "A cancel's outcome is unknown",
        "Se desconoce el resultado de una cancelación",
    ),
    ("cancel_failed", "A cancel failed", "Falló una cancelación"),
    (
        "cancel_not_sent",
        "Cancels held back by the request budget",
        "Cancelaciones retenidas por el cupo de solicitudes",
    ),
    ("resurrected", "A closed order came back", "Una orden cerrada volvió"),
    ("foreign_position", "A position the bot did not open", "Una posición que el bot no abrió"),
    ("foreign_order", "An order the bot did not send", "Una orden que el bot no envió"),
    (
        "quantity_mismatch",
        "Quantities differ from the broker's",
        "Las cantidades difieren de las del bróker",
    ),
    ("shutting_down", "The bot is shutting down", "El bot se está apagando"),
    ("entry_stop", "Entries stopped by the operator", "Entradas detenidas por el operador"),
    (
        "replace_unresolved",
        "A stop change is not confirmed",
        "Un cambio de stop no está confirmado",
    ),
    ("stop_held", "No stop and no close sent", "Sin stop y sin cierre enviado"),
    (
        "exit_not_filled",
        "A closing order is not filled in time",
        "Una orden de cierre no se ejecuta a tiempo",
    ),
    ("market_closed", "The market is closed", "Mercado cerrado"),
    (
        "watchdog_started",
        "Started by the watchdog: entries wait for you",
        "Iniciado por el vigilante: las entradas te esperan",
    ),
]:
    add("fence_" + code, "kit.fence." + code, en, es, F + code)

ORDER = "Order "
for name, en, es in [
    ("side_BUY", "Buy", "Compra"),
    ("side_SELL", "Sell", "Venta"),
    ("type_MARKET", "Market", "Mercado"),
    ("type_LIMIT", "Limit", "Límite"),
    ("type_STOP_LOSS", "Stop loss", "Stop loss"),
    ("type_STOP_LOSS_LIMIT", "Stop limit", "Stop límite"),
    ("type_TRAILING_STOP_LOSS", "Trailing stop", "Trailing stop"),
    ("status_ACCEPTED", "Accepted", "Aceptada"),
    ("status_PARTIALLY_FILLED", "Partly filled", "Ejecutada en parte"),
    ("status_FILLED", "Filled", "Ejecutada"),
    ("status_CANCELLED", "Cancelled", "Cancelada"),
    ("status_REJECTED", "Rejected", "Rechazada"),
    ("status_EXPIRED", "Expired", "Vencida"),
    ("status_UNKNOWN", "Unknown", "Desconocido"),
]:
    add("order_" + name, "kit.order." + name, en, es, ORDER + name.replace("_", " ", 1).lower())

R = "Strategy check: "
for code, en, es in [
    ("position_open", "Position open", "Posición abierta"),
    ("bars_consistent", "Bars consistent", "Velas coherentes"),
    ("history_bars", "History bars", "Velas de historial"),
    ("relative_volume", "Relative volume", "Volumen relativo"),
    ("dollar_volume_usd", "Dollar volume, USD", "Volumen en dólares, USD"),
    ("session_vwap_available", "Session VWAP available", "VWAP de la sesión disponible"),
    ("close_above_vwap", "Close above VWAP", "Cierre por encima del VWAP"),
    ("fast_ema_above_slow_ema", "Fast EMA above slow EMA", "EMA rápida por encima de la EMA lenta"),
    ("atr", "ATR", "ATR"),
    ("quote_valid", "Quote valid", "Cotización válida"),
    ("spread_ratio", "Spread ratio", "Ratio del spread"),
    ("bid_above_invalidation", "Bid above invalidation", "Bid por encima de la invalidación"),
    ("ask_above_trigger", "Ask above trigger", "Ask por encima del disparador"),
    ("ask_within_price_window", "Ask within price window", "Ask dentro de la ventana de precio"),
    ("stop_distance", "Stop distance", "Distancia del stop"),
    ("round_trip_atr_ratio", "Round trip / ATR", "Ida y vuelta / ATR"),
    ("round_trip_risk_ratio", "Round trip / risk", "Ida y vuelta / riesgo"),
    ("daily_loss_budget_usd", "Daily loss budget, USD", "Presupuesto de pérdida diaria, USD"),
    (
        "breakout_close_above_trigger",
        "Breakout: close above trigger",
        "Ruptura: cierre por encima del disparador",
    ),
    (
        "breakout_invalidation_below_trigger",
        "Breakout: invalidation below trigger",
        "Ruptura: invalidación por debajo del disparador",
    ),
    (
        "continuation_invalidation_below_trigger",
        "Continuation: invalidation below trigger",
        "Continuación: invalidación por debajo del disparador",
    ),
    ("spike_volume_ratio", "Spike: volume × average", "Pico: volumen × promedio"),
    ("spike_move_atr", "Spike: move in ATR", "Pico: movimiento en ATR"),
    (
        "spike_invalidation_below_trigger",
        "Spike: invalidation below trigger",
        "Pico: invalidación por debajo del disparador",
    ),
    ("spike_age_bars", "Spike: bars since it", "Pico: velas desde él"),
    ("spike_low_held", "Spike: its low held", "Pico: su mínimo se mantuvo"),
    ("relative_volume_available", "Relative volume available", "Volumen relativo disponible"),
    ("impulse_atr", "Impulse in ATR", "Impulso en ATR"),
    ("base_range_atr", "Base range in ATR", "Rango de la base en ATR"),
    (
        "pre_breakout_distance_atr",
        "Distance below base high, ATR",
        "Distancia bajo el máximo de la base, ATR",
    ),
    (
        "breakout_pre_breakout_distance_atr",
        "Breakout: distance below trigger, ATR",
        "Ruptura: distancia bajo el disparador, ATR",
    ),
    ("sizing_risk_per_share", "Risk per share for sizing", "Riesgo por acción para el tamaño"),
    ("quantity", "Quantity", "Cantidad"),
]:
    add("rule_" + code, "kit.rule." + code, en, es, R + code)

# discovery refusal causes (data.discovery.Cause, symbols-v1 row cause)
DC = "Why discovery dropped a symbol: "
for code, en, es in [
    ("CONFLICTING_ROWS", "Screeners disagree on it", "Los filtros no coinciden en él"),
    ("EXCHANGE_NOT_ALLOWED", "Exchange not allowed", "Bolsa no permitida"),
    ("CURRENCY_NOT_ALLOWED", "Currency not allowed", "Moneda no permitida"),
    ("SECURITY_TYPE_UNKNOWN", "Security type unknown", "Tipo de valor desconocido"),
    ("SECURITY_TYPE_NOT_ALLOWED", "Not a common stock", "No es una acción común"),
    ("NO_QUOTE", "No quote", "Sin cotización"),
    ("QUOTE_STALE", "Quote too old", "Cotización vieja"),
    (
        "QUOTE_FROM_FUTURE",
        "Quote time ahead of the clock",
        "Hora de cotización adelantada al reloj",
    ),
    ("QUOTE_INVALID", "Quote invalid", "Cotización no válida"),
    ("NO_BARS", "No minute bars", "Sin velas de un minuto"),
    ("SYMBOL_REFUSED", "Refused by the data provider", "Rechazado por el proveedor de datos"),
    ("STRATEGY_LIQUIDITY", "Strategy liquidity rule", "Regla de liquidez de la estrategia"),
]:
    add("discovery_" + code, "kit.discovery." + code, en, es, DC + code)

BEGIN, END = (
    "  // MARK: Bot codes (ApiCodes.swift): generated by apps/scripts/kit_api_strings.py",
    "  // END Bot codes",
)


def camel(name):
    parts = name.replace("-", "_").split("_")
    out = parts[0].lower() + "".join(p[:1].upper() + p[1:].lower() for p in parts[1:])
    return out


GROUPS = [
    ("BlockCode", "block_", "Why entries are blocked (`EntryBlock.cause`)."),
    ("FenceKind", "fence_", 'A fence\'s kind: its name before ":", with "_" for "-".'),
    ("OrderSide", "order_side_", "An order's side."),
    ("OrderKind", "order_type_", "An order's type."),
    ("OrderStatus", "order_status_", "An order's state at the broker."),
    ("CheckRule", "rule_", "A strategy check's rule."),
    ("DiscoveryCause", "discovery_", "Why discovery dropped a symbol (`SymbolRowV1.cause`)."),
]


# The strategy check rules get a file of their own, so neither file passes SwiftLint's length.
RULES = "rule_"
FILES = [
    ("L10n+Codes.swift", lambda name: not name.startswith(RULES)),
    ("L10n+Rules.swift", lambda name: name.startswith(RULES)),
]


def l10n_block(keep):
    lines = [BEGIN]
    for name, key, en, _ru, doc in (entry for entry in S if keep(entry[0])):
        res = f'    LocalizedStringResource("{key}", defaultValue: "{en}", bundle: bundle)'
        if len(res) > 120:
            res = (
                f'    LocalizedStringResource("{key}",\n      defaultValue: "{en}", bundle: bundle)'
            )
        lines += [
            f"  /// {doc}",
            f"  static var {camel(name)}: LocalizedStringResource {{",
            res,
            "  }",
        ]
    lines.append(END)
    return "\n".join(lines) + "\n"


def codes_swift():
    out = [
        "// Generated by apps/scripts/kit_api_strings.py: the bot's codes and their texts in L10n."
        " Do not edit.",
        "",
        "import Foundation",
        "",
    ]
    for enum, prefix, doc in GROUPS:
        members = [n for n, *_ in S if n.startswith(prefix)]
        out += [
            f"/// {doc} An unknown code has no case; show the bot's own text then.",
            f"public enum {enum}: String, CaseIterable, Sendable {{",
        ]
        for n in members:
            raw = n[len(prefix) :]
            out.append(f'  case {camel(raw)} = "{raw}"')
        out += ["", "  public var title: LocalizedStringResource {", "    switch self {"]
        for n in members:
            out.append(f"    case .{camel(n[len(prefix) :])}: L10n.{camel(n)}")
        out += ["    }", "  }", "}", ""]
    return "\n".join(out).rstrip() + "\n"


def catalog_entry(key, en, es, doc):
    return {
        "comment": doc,
        "extractionState": "manual",
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en}},
            "es": {"stringUnit": {"state": "translated", "value": es}},
        },
    }


def codes(group):
    """The raw codes of one group (an enum name of GROUPS), as the bot sends them."""
    prefix = next(p for name, p, _ in GROUPS if name == group)
    return {n[len(prefix) :] for n, *_ in S if n.startswith(prefix)}


def check():
    """Differences between the committed files and this list; empty when they agree."""
    problems = []
    if (KIT / "ApiCodes.swift").read_text() != codes_swift():
        problems.append("ApiCodes.swift differs from the generator")
    for file, keep in FILES:
        path = KIT / file
        if not path.exists() or path.read_text() != l10n_swift(keep):
            problems.append(f"{file} differs from the generator")
    strings = json.loads((KIT / "Resources/Localizable.xcstrings").read_text())["strings"]
    for _name, key, en, es, doc in S:
        if strings.get(key) != catalog_entry(key, en, es, doc):
            problems.append(f"catalog entry {key} differs from the generator")
    return problems


def l10n_swift(keep):
    head = [
        "// Generated by apps/scripts/kit_api_strings.py: the texts of the bot's codes."
        " Do not edit.",
        "",
        "import Foundation",
        "",
        "extension L10n {",
    ]
    return "\n".join(head) + "\n" + l10n_block(keep) + "}\n"


def write():
    swift = KIT / "L10n.swift"
    text = swift.read_text()
    if BEGIN in text:
        text = text[: text.index(BEGIN)].rstrip() + "\n}\n"
        swift.write_text(text)
    for file, keep in FILES:
        (KIT / file).write_text(l10n_swift(keep))
    (KIT / "ApiCodes.swift").write_text(codes_swift())
    cpath = KIT / "Resources/Localizable.xcstrings"
    cat = json.loads(cpath.read_text())
    for _name, key, en, es, doc in S:
        cat["strings"][key] = catalog_entry(key, en, es, doc)
    cat["strings"] = dict(sorted(cat["strings"].items()))
    cpath.write_text(json.dumps(cat, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    if sys.argv[1:] == ["--check"]:
        found = check()
        print("\n".join(found) or "bot codes up to date")
        sys.exit(1 if found else 0)
    write()
