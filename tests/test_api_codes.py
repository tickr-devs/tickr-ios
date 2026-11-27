"""The apps' translations of the bot's codes (apps/scripts/kit_api_strings.py and
kit_reason_strings.py) stay in step with the bot: every fence kind, entry-block cause, gate
reason and fence reason the bot can send has a translated case, a sentence names only values the
bot sends, and the committed Swift and catalog match the generators.

What the bot sends comes from `contract/codes.json`, which tickr-bot writes from its code
(tests/api/test_contract_codes.py there) and its contract-sync workflow copies here."""

from __future__ import annotations

import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "apps" / "scripts" / "kit_api_strings.py"
REASONS_SCRIPT = ROOT / "apps" / "scripts" / "kit_reason_strings.py"
KIT_CATALOG = ROOT / "apps/shared/Sources/TickrKit/Resources/Localizable.xcstrings"
SKIPPED_GROUPS = ROOT / "apps/shared/Sources/TickrKit/SkippedGroups.swift"
CODES = ROOT / "contract" / "codes.json"
FORMAT = 1  # the layout of codes.json this test reads


def load_script(path: Path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def load():
    return load_script(SCRIPT)


def load_reasons():
    return load_script(REASONS_SCRIPT)


def sent() -> dict:
    codes = json.loads(CODES.read_text(encoding="utf-8"))
    assert codes["format"] == FORMAT, "contract/codes.json has a layout this test does not read"
    return codes


def shapes(name: str) -> dict[str, list[set[str]]]:
    """A `*_reasons` table of codes.json: per code, the value names each of its shapes carries."""
    return {code: [set(shape) for shape in found] for code, found in sent()[name].items()}


def test_committed_files_match_the_generator():
    assert load().check() == []


def test_every_fence_kind_is_translated():
    assert load().codes("FenceKind") == set(sent()["fence_kinds"])


def test_every_discovery_cause_and_spike_rule_is_translated():
    module = load()
    assert module.codes("DiscoveryCause") == set(sent()["discovery_causes"])
    rules = set(sent()["spike_rules"])
    assert rules and rules <= module.codes("CheckRule")


def test_every_not_reached_cause_is_translated():
    assert load().codes("NotReachedCause") == set(sent()["not_reached_causes"])


def test_every_entry_block_cause_is_translated():
    module = load()
    known = module.codes("BlockCode") | module.codes("FenceKind")
    causes = set(sent()["entry_block_causes"])
    assert causes and causes <= known


def assert_sentences_fit_shapes(sent_shapes, sentences) -> None:
    """Every shape the bot writes a code in has a sentence naming only values that shape sends
    (so no shape falls back to English), and every sentence fits some shape."""
    assert set(sentences) == set(sent_shapes)
    for code, found in sent_shapes.items():
        for shape in found:
            assert any(names <= shape for names in sentences[code]), (code, shape)
        for names in sentences[code]:
            assert any(names <= shape for shape in found), (code, names)


def test_reason_sentences_match_the_generator():
    assert load_reasons().check() == []


def test_every_gate_and_fence_shape_has_a_sentence_naming_only_values_the_bot_sends():
    module = load_reasons()
    assert_sentences_fit_shapes(shapes("gate_reasons"), module.codes("GateReason"))
    assert_sentences_fit_shapes(shapes("fence_reasons"), module.codes("FenceReason"))


def test_every_refusal_shape_has_a_sentence_naming_only_values_the_bot_sends():
    sentences = load_reasons().codes("RefusalReason")
    assert set(sentences) <= set(sent()["admission_causes"])
    assert_sentences_fit_shapes(shapes("refusal_reasons"), sentences)


def test_every_prose_shape_has_a_sentence_naming_only_values_the_bot_sends():
    assert_sentences_fit_shapes(shapes("prose_reasons"), load_reasons().codes("ProseReason"))


def test_every_translation_names_the_same_values_as_the_english():
    strings = json.loads(KIT_CATALOG.read_text(encoding="utf-8"))["strings"]
    token = re.compile(r"\{\w+\}")
    for key, entry in strings.items():
        if not key.startswith(("kit.gate.", "kit.fenceReason.", "kit.refusal.", "kit.prose.")):
            continue
        units = {lang: entry["localizations"][lang]["stringUnit"]["value"] for lang in ("en", "es")}
        assert set(token.findall(units["en"])) == set(token.findall(units["es"])), key


def swift_refusal_codes() -> set[str]:
    """Raw values of the Swift `RefusalCode` enum, which the apps put in words."""
    source = SKIPPED_GROUPS.read_text(encoding="utf-8")
    body = re.search(r"public enum RefusalCode\b.*?\n}\n", source, re.S)
    assert body, "no RefusalCode enum in SkippedGroups.swift: update this test"
    return set(re.findall(r'^  case \w+ = "(\w+)"$', body.group(0), re.M))


def test_every_refusal_code_the_api_sends_has_words_in_the_apps():
    # codes.json leaves out UNKNOWN (a cause the API cannot read exactly) on purpose: the apps
    # show "Other reason" for it, as for a code from a newer bot.
    assert swift_refusal_codes() == set(sent()["refusal_codes"])
