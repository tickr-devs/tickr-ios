"""TickrKit strings for the bot's codes (ApiText), in English and Russian.

`python3 apps/scripts/kit_api_strings.py` writes ApiCodes.swift, L10n+Codes.swift (a part of
the kit's L10n) and the kit's catalog entries; run apps/scripts/format_xcstrings.py after it.
`--check` writes nothing and fails when the committed files differ from this list
(tests/test_api_codes.py runs it, and also checks this list against the bot's own codes).
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / "apps/shared/Sources/TickrKit"

# (swift name, key, english, russian, doc)
S = []


def add(name, key, en, ru, doc):
    S.append((name, key, en, ru, doc))


# entry_block.cause
B = "Why entries are blocked: "
for code, en, ru in [
    ("bot_starting", "The bot is starting.", "Бот запускается."),
    ("bot_stopping", "The bot is stopping.", "Бот останавливается."),
    ("bot_stopped", "The bot is stopped.", "Бот остановлен."),
    ("trading_gate_closed", "The trading gate is closed.", "Торговый шлюз закрыт."),
    ("entry_stop", "Entries stopped by the operator.", "Входы остановлены оператором."),
    (
        "strategy_not_loaded",
        "The active strategy is not loaded.",
        "Активная стратегия не загружена.",
    ),
    (
        "entries_not_wired",
        "This build does not open trades on its own yet.",
        "Эта сборка пока не открывает сделки сама.",
    ),
    ("own_trade_open", "The bot already has a trade open.", "У бота уже открыта сделка."),
    ("no_session_today", "No regular session today.", "Сегодня нет основной сессии."),
    (
        "calendar_unknown",
        "The trading calendar cannot say whether the market is open.",
        "Торговый календарь не может сказать, открыт ли рынок.",
    ),
    ("outside_regular_session", "Outside the regular session.", "Вне основной сессии."),
    ("after_last_entry", "Past the last entry time.", "Время последнего входа прошло."),
    (
        "daily_money_unknown",
        "A trade closed today has fills without a known price.",
        "У сделки, закрытой сегодня, есть исполнения без известной цены.",
    ),
    (
        "daily_ceiling",
        "Too little room left under the daily loss limit.",
        "Под дневным лимитом убытка осталось слишком мало места.",
    ),
]:
    add("block_" + code, "kit.block." + code, en, ru, B + code)

# fence kinds (entry_block.cause uses them with "_" for "-")
F = "A fence (a block on new entries): "
for code, en, ru in [
    ("startup_reconcile", "Startup reconciliation not finished", "Сверка при запуске не завершена"),
    ("broker_read_failed", "Broker read failed", "Чтение брокера не удалось"),
    (
        "detail_budget",
        "Order detail request budget used up",
        "Лимит запросов деталей ордеров исчерпан",
    ),
    ("unknown_order", "An order's outcome is unknown", "Исход ордера неизвестен"),
    ("order_missing", "An order is missing at the broker", "Ордера нет у брокера"),
    (
        "detail_unreadable",
        "An order's detail cannot be read",
        "Детали ордера не читаются",
    ),
    ("status_unknown", "An order's status is unknown", "Статус ордера неизвестен"),
    ("unprotected", "A position has no verified stop", "У позиции нет подтверждённого стопа"),
    ("over_protected", "A position has more than one stop", "У позиции больше одного стопа"),
    (
        "unprotected_timeout",
        "A position stayed unprotected too long",
        "Позиция слишком долго без защиты",
    ),
    ("stop_rejected", "The broker rejected a stop", "Брокер отклонил стоп"),
    ("exit_refused", "An exit was refused", "Выход отклонён"),
    ("cancel_unknown", "A cancel's outcome is unknown", "Исход отмены неизвестен"),
    ("cancel_failed", "A cancel failed", "Отмена не удалась"),
    (
        "cancel_not_sent",
        "Cancels held back by the request budget",
        "Отмены задержаны лимитом запросов",
    ),
    ("resurrected", "A closed order came back", "Закрытый ордер вернулся"),
    ("foreign_position", "A position the bot did not open", "Позиция, которую бот не открывал"),
    ("foreign_order", "An order the bot did not send", "Ордер, который бот не отправлял"),
    (
        "quantity_mismatch",
        "Quantities differ from the broker's",
        "Количество расходится с брокером",
    ),
    ("shutting_down", "The bot is shutting down", "Бот завершает работу"),
    ("entry_stop", "Entries stopped by the operator", "Входы остановлены оператором"),
    ("replace_unresolved", "A stop change is not confirmed", "Изменение стопа не подтверждено"),
    ("stop_held", "No stop and no close sent", "Нет ни стопа, ни отправленного закрытия"),
    (
        "exit_not_filled",
        "A closing order is not filled in time",
        "Закрывающий ордер не исполнен вовремя",
    ),
    ("market_closed", "The market is closed", "Рынок закрыт"),
    (
        "watchdog_started",
        "Started by the watchdog: entries wait for you",
        "Запущен сторожем: входы ждут вашего решения",
    ),
]:
    add("fence_" + code, "kit.fence." + code, en, ru, F + code)

ORDER = "Order "
for name, en, ru in [
    ("side_BUY", "Buy", "Покупка"),
    ("side_SELL", "Sell", "Продажа"),
    ("type_MARKET", "Market", "Рыночный"),
    ("type_LIMIT", "Limit", "Лимитный"),
    ("type_STOP_LOSS", "Stop loss", "Стоп-лосс"),
    ("status_ACCEPTED", "Accepted", "Принят"),
    ("status_PARTIALLY_FILLED", "Partly filled", "Частично исполнен"),
    ("status_FILLED", "Filled", "Исполнен"),
    ("status_CANCELLED", "Cancelled", "Отменён"),
    ("status_REJECTED", "Rejected", "Отклонён"),
    ("status_EXPIRED", "Expired", "Истёк"),
    ("status_UNKNOWN", "Unknown", "Неизвестно"),
]:
    add("order_" + name, "kit.order." + name, en, ru, ORDER + name.replace("_", " ", 1).lower())

R = "Strategy check: "
for code, en, ru in [
    ("position_open", "Position open", "Позиция открыта"),
    ("bars_consistent", "Bars consistent", "Бары согласованы"),
    ("history_bars", "History bars", "Бары истории"),
    ("relative_volume", "Relative volume", "Относительный объём"),
    ("dollar_volume_usd", "Dollar volume, USD", "Объём в долларах, USD"),
    ("session_vwap_available", "Session VWAP available", "VWAP сессии доступен"),
    ("close_above_vwap", "Close above VWAP", "Закрытие выше VWAP"),
    ("fast_ema_above_slow_ema", "Fast EMA above slow EMA", "Быстрая EMA выше медленной"),
    ("atr", "ATR", "ATR"),
    ("quote_valid", "Quote valid", "Котировка годна"),
    ("spread_ratio", "Spread ratio", "Доля спреда"),
    ("bid_above_invalidation", "Bid above invalidation", "Бид выше уровня отмены"),
    ("ask_above_trigger", "Ask above trigger", "Аск выше триггера"),
    ("ask_within_price_window", "Ask within price window", "Аск в ценовом окне"),
    ("stop_distance", "Stop distance", "Расстояние до стопа"),
    ("round_trip_atr_ratio", "Round trip / ATR", "Круг / ATR"),
    ("round_trip_risk_ratio", "Round trip / risk", "Круг / риск"),
    ("daily_loss_budget_usd", "Daily loss budget, USD", "Дневной бюджет убытка, USD"),
    (
        "breakout_close_above_trigger",
        "Breakout: close above trigger",
        "Пробой: закрытие выше триггера",
    ),
    (
        "breakout_invalidation_below_trigger",
        "Breakout: invalidation below trigger",
        "Пробой: уровень отмены ниже триггера",
    ),
    (
        "continuation_invalidation_below_trigger",
        "Continuation: invalidation below trigger",
        "Продолжение: уровень отмены ниже триггера",
    ),
    ("spike_volume_ratio", "Spike: volume × average", "Всплеск: объём × средний"),
    ("spike_move_atr", "Spike: move in ATR", "Всплеск: движение в ATR"),
    (
        "spike_invalidation_below_trigger",
        "Spike: invalidation below trigger",
        "Всплеск: уровень отмены ниже триггера",
    ),
    ("spike_age_bars", "Spike: bars since it", "Всплеск: баров после него"),
    ("spike_low_held", "Spike: its low held", "Всплеск: минимум удержан"),
]:
    add("rule_" + code, "kit.rule." + code, en, ru, R + code)

# discovery refusal causes (data.discovery.Cause, symbols-v1 row cause)
DC = "Why discovery dropped a symbol: "
for code, en, ru in [
    ("CONFLICTING_ROWS", "Screeners disagree on it", "Скринеры расходятся по нему"),
    ("EXCHANGE_NOT_ALLOWED", "Exchange not allowed", "Биржа не разрешена"),
    ("CURRENCY_NOT_ALLOWED", "Currency not allowed", "Валюта не разрешена"),
    ("SECURITY_TYPE_UNKNOWN", "Security type unknown", "Тип бумаги неизвестен"),
    ("SECURITY_TYPE_NOT_ALLOWED", "Not a common stock", "Не обыкновенная акция"),
    ("NO_QUOTE", "No quote", "Нет котировки"),
    ("QUOTE_STALE", "Quote too old", "Котировка устарела"),
    ("QUOTE_FROM_FUTURE", "Quote time ahead of the clock", "Время котировки впереди часов"),
    ("QUOTE_INVALID", "Quote invalid", "Котировка негодна"),
    ("NO_BARS", "No minute bars", "Нет минутных баров"),
    ("SYMBOL_REFUSED", "Refused by the data provider", "Отклонён поставщиком данных"),
    ("STRATEGY_LIQUIDITY", "Strategy liquidity rule", "Правило ликвидности стратегии"),
]:
    add("discovery_" + code, "kit.discovery." + code, en, ru, DC + code)

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


def l10n_block():
    lines = [BEGIN]
    for name, key, en, _ru, doc in S:
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


def catalog_entry(key, en, ru, doc):
    return {
        "comment": doc,
        "extractionState": "manual",
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en}},
            "ru": {"stringUnit": {"state": "translated", "value": ru}},
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
    if (KIT / "L10n+Codes.swift").read_text() != l10n_swift():
        problems.append("L10n+Codes.swift differs from the generator")
    strings = json.loads((KIT / "Resources/Localizable.xcstrings").read_text())["strings"]
    for _name, key, en, ru, doc in S:
        if strings.get(key) != catalog_entry(key, en, ru, doc):
            problems.append(f"catalog entry {key} differs from the generator")
    return problems


def l10n_swift():
    head = [
        "// Generated by apps/scripts/kit_api_strings.py: the texts of the bot's codes."
        " Do not edit.",
        "",
        "import Foundation",
        "",
        "extension L10n {",
    ]
    return "\n".join(head) + "\n" + l10n_block() + "}\n"


def write():
    swift = KIT / "L10n.swift"
    text = swift.read_text()
    if BEGIN in text:
        text = text[: text.index(BEGIN)].rstrip() + "\n}\n"
        swift.write_text(text)
    (KIT / "L10n+Codes.swift").write_text(l10n_swift())
    (KIT / "ApiCodes.swift").write_text(codes_swift())
    cpath = KIT / "Resources/Localizable.xcstrings"
    cat = json.loads(cpath.read_text())
    for _name, key, en, ru, doc in S:
        cat["strings"][key] = catalog_entry(key, en, ru, doc)
    cat["strings"] = dict(sorted(cat["strings"].items()))
    cpath.write_text(json.dumps(cat, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    if sys.argv[1:] == ["--check"]:
        found = check()
        print("\n".join(found) or "bot codes up to date")
        sys.exit(1 if found else 0)
    write()
