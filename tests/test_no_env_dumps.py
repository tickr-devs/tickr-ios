"""Tooling never prints the process environment (CLAUDE.md, hard rules 4 and 10).

An agent once ran `xctest --help` during screenshot work; its output holds the whole process
environment, so a credential value reached a tool transcript. This guard scans every script,
workflow and Python/Swift source of the repository for the ways a whole environment gets printed,
logged or passed on, and fails on each hit:

- `printenv`, a bare `env` command (alone, piped, redirected or `env -0`), `export -p`, a bare
  `set` or `declare -p`/`declare -x` in shell (scripts, workflow `run:` blocks, Python argv lists);
- `xctest --help` / `xctest -h` and `-showBuildSettings` (both print the environment);
- shell tracing (`set -x`, `set -o xtrace`, `sh -x`, `bash -x`): never in a shell script, and
  never in a workflow job (or workflow) that references `secrets.`;
- Python: `os.environ` printed, logged, stringified or iterated whole (`print(os.environ)`,
  `json.dumps(dict(os.environ))`, `os.environ.items()`, `f"{os.environ}"`);
- Swift: `ProcessInfo.processInfo.environment` used other than for one named read
  (`...environment["NAME"]`), so the whole dictionary is never bound, printed or forwarded.

Single named reads (`os.environ.get("NAME")`, `os.environ["NAME"]`, `environment["NAME"]`) and
`env NAME=value command` are allowed by the patterns themselves. Anything else that must stay is
listed in ALLOWED below with its reason; an entry that no longer matches a line fails the test, so
the allowlist cannot go stale.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Directories never scanned: build output, dependencies and VCS data.
SKIPPED_DIRS = {".git", ".build", "build", "DerivedData", "SourcePackages", ".venv",
                "node_modules", "__pycache__", ".scratch"}
SHELL_SUFFIXES = {".sh", ".bash", ".zsh"}
WORKFLOW_SUFFIXES = {".yml", ".yaml"}

# Files exempt as a whole, with the reason. The guard itself spells the patterns it looks for.
EXEMPT_FILES = {
    "tests/test_no_env_dumps.py": "the guard: its patterns and test data name every forbidden form",
}

# Exact exceptions: (repository path, stripped line, reason). Each entry must still match a line.
ALLOWED: list[tuple[str, str, str]] = []

# --- shell (scripts, workflow run blocks, quoted argv in Python) --------------------------------
# Where a command starts: line start, after a separator, a keyword, `sudo`, or a workflow `run:`.
_CMD_START = r"(?:^|[;&|({`]|\$\(|\bthen\b|\bdo\b|\belse\b|\bsudo\b|\brun:)\s*"
SHELL_DUMPS = [
    (re.compile(r"\bprintenv\b"), "printenv prints the environment"),
    (re.compile(_CMD_START + r"env\s*(?:$|[|>;&)`]|-0\b|--null\b)"),
     "a bare `env` prints the environment"),
    (re.compile(_CMD_START + r"export\s+-p\b"), "`export -p` prints the environment"),
    (re.compile(_CMD_START + r"declare\s+-[a-zA-Z]*[px]\b\s*(?:$|[|>;&)])"),
     "`declare -p`/`declare -x` prints the environment"),
    (re.compile(_CMD_START + r"set\s*(?:$|[|>;&)])"), "a bare `set` prints every variable"),
]
EVERYWHERE = [
    (re.compile(r"\bxctest\b[\"',\s]+-(?:-help|h)\b"), "`xctest --help` prints the environment"),
    (re.compile(r"-showBuildSettings\b"), "`-showBuildSettings` prints the build environment"),
]
XTRACE = re.compile(r"\bset\s+-[a-zA-Z]*x|\bset\s+-o\s+xtrace\b|\b(?:ba|z)?sh\s+-[a-zA-Z]*x\b")
SECRETS = re.compile(r"\bsecrets\.")

# --- Python ---------------------------------------------------------------------------------------
_ENVIRON = r"(?:dict\(\s*)?os\.environ\b(?!\s*(?:\[|\.get\b|\.pop\b|\.setdefault\b))"
PYTHON_DUMPS = [
    (re.compile(r"\b(?:print|pprint|pformat|repr|str|dumps|dump|write|echo|info|debug|warning|"
                r"error|critical|exception|log)\s*\(\s*(?:[^()]*,\s*)?\*{0,2}" + _ENVIRON),
     "os.environ printed, logged or stringified whole"),
    (re.compile(r"\bos\.environ\.(?:items|keys|values)\s*\("), "os.environ iterated whole"),
    (re.compile(r"\{\s*" + _ENVIRON + r"\s*[!:}]"), "os.environ formatted into a string"),
    (re.compile(r"[\"']printenv[\"']|[\[(,]\s*[\"']env[\"']\s*[\]),]"),
     "a subprocess that prints the environment"),
]

# --- Swift ----------------------------------------------------------------------------------------
SWIFT_DUMPS = [
    (re.compile(r"ProcessInfo(?:\.processInfo|\(\))\.environment\b(?!\s*\[)"),
     "ProcessInfo environment used whole: read one name, `environment[\"NAME\"]`"),
]


def _comment_free(line: str, marker: str) -> str:
    """The line without a trailing comment (good enough for these patterns: no `#`/`//` inside
    the strings they look for)."""
    index = line.find(marker)
    return line if index < 0 else line[:index]


def shell_violations(text: str) -> list[tuple[int, str]]:
    """Hits in a shell script: environment dumps, xtrace and the always-forbidden commands."""
    found: list[tuple[int, str]] = []
    for number, raw in enumerate(text.splitlines(), 1):
        line = _comment_free(raw, "#") if not raw.startswith("#!") else ""
        for pattern, why in SHELL_DUMPS + EVERYWHERE:
            if pattern.search(line):
                found.append((number, why))
        if XTRACE.search(line):
            found.append((number, "shell tracing (set -x) in a script"))
    return found


def _top_level(line: str) -> bool:
    return bool(line) and not line[0].isspace() and not line.startswith("#")


def workflow_violations(text: str) -> list[tuple[int, str]]:
    """Hits in a GitHub workflow: environment dumps anywhere, and shell tracing in a job that can
    see a secret (a `secrets.` reference in the job or at the workflow's top level)."""
    lines = text.splitlines()
    found: list[tuple[int, str]] = []
    for number, raw in enumerate(lines, 1):
        line = _comment_free(raw, "#")
        for pattern, why in SHELL_DUMPS + EVERYWHERE:
            if pattern.search(line):
                found.append((number, why))
    # Blocks: everything outside `jobs:` is the workflow level; each job id under it is a block.
    job_of: list[str] = []
    job = ""
    inside_jobs = False
    for raw in lines:
        if _top_level(raw):
            inside_jobs = raw.rstrip() == "jobs:"
            job = ""
        elif inside_jobs and re.match(r"^  [A-Za-z0-9_-]+:\s*$", raw):
            job = raw.strip()
        job_of.append(job)
    workflow_secret = any(SECRETS.search(_comment_free(raw, "#"))
                          for raw, owner in zip(lines, job_of, strict=True) if not owner)
    secret_jobs = {owner for raw, owner in zip(lines, job_of, strict=True)
                   if owner and SECRETS.search(_comment_free(raw, "#"))}
    for number, (raw, owner) in enumerate(zip(lines, job_of, strict=True), 1):
        if XTRACE.search(_comment_free(raw, "#")) and (workflow_secret or owner in secret_jobs):
            found.append((number, "shell tracing in a workflow job that sees a secret"))
    return found


def python_violations(text: str) -> list[tuple[int, str]]:
    found: list[tuple[int, str]] = []
    for number, raw in enumerate(text.splitlines(), 1):
        line = _comment_free(raw, "#")
        for pattern, why in PYTHON_DUMPS + EVERYWHERE:
            if pattern.search(line):
                found.append((number, why))
    return found


def swift_violations(text: str) -> list[tuple[int, str]]:
    found: list[tuple[int, str]] = []
    for number, raw in enumerate(text.splitlines(), 1):
        line = _comment_free(raw, "//")
        for pattern, why in SWIFT_DUMPS + EVERYWHERE:
            if pattern.search(line):
                found.append((number, why))
    return found


def checker_for(path: Path):
    """The scanner for a file, or None when the file is not tooling or code."""
    relative = path.relative_to(ROOT).as_posix()
    if path.suffix in WORKFLOW_SUFFIXES and relative.startswith(".github/workflows/"):
        return workflow_violations
    if path.suffix in SHELL_SUFFIXES:
        return shell_violations
    if path.suffix == ".py":
        return python_violations
    if path.suffix == ".swift":
        return swift_violations
    return None


def scanned_files(root: Path = ROOT) -> list[Path]:
    files: list[Path] = []
    for path in sorted(root.rglob("*")):
        parts = path.relative_to(root).parts
        if any(part in SKIPPED_DIRS for part in parts[:-1]) or not path.is_file():
            continue
        if parts[0] == ".github" and parts[:2] != (".github", "workflows"):
            continue
        if checker_for(path) is not None:
            files.append(path)
    return files


def repository_violations() -> tuple[list[str], set[int]]:
    """Every unallowed hit as `path:line: why`, and the indexes of ALLOWED entries that matched."""
    problems: list[str] = []
    used: set[int] = set()
    for path in scanned_files():
        relative = path.relative_to(ROOT).as_posix()
        if relative in EXEMPT_FILES:
            continue
        checker = checker_for(path)
        assert checker is not None
        text = path.read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        for number, why in checker(text):
            stripped = lines[number - 1].strip()
            allowed = [i for i, (where, line, _) in enumerate(ALLOWED)
                       if where == relative and line == stripped]
            if allowed:
                used.update(allowed)
            else:
                problems.append(f"{relative}:{number}: {why}")
    return problems, used


# --- the repository -----------------------------------------------------------------------------

def test_no_tooling_prints_the_process_environment():
    problems, _ = repository_violations()
    assert not problems, "\n".join(
        ["Never print the process environment; pass and read only named variables:", *problems])


def test_every_allowlist_entry_still_matches_a_line():
    _, used = repository_violations()
    stale = [f"{where}: {line}" for i, (where, line, _) in enumerate(ALLOWED) if i not in used]
    assert not stale, "remove stale ALLOWED entries:\n" + "\n".join(stale)


def test_every_exemption_names_an_existing_file_and_a_reason():
    for relative, reason in EXEMPT_FILES.items():
        assert (ROOT / relative).is_file(), relative
        assert reason.strip()
    for where, line, reason in ALLOWED:
        assert (ROOT / where).is_file() and line and reason.strip(), where


def test_the_scan_covers_scripts_workflows_and_test_code():
    relatives = {path.relative_to(ROOT).as_posix() for path in scanned_files()}
    assert any(r.startswith(".github/workflows/") for r in relatives)
    assert any(r.startswith("apps/") and r.endswith(".sh") for r in relatives)
    assert any(r.startswith("apps/scripts/") and r.endswith(".py") for r in relatives)
    assert any(r.startswith("tests/") and r.endswith(".py") for r in relatives)
    assert any(r.startswith("apps/") and r.endswith(".swift") for r in relatives)
    assert any("UITests" in r and r.endswith(".swift") for r in relatives)


# --- the guard itself ---------------------------------------------------------------------------

def lines_of(found: list[tuple[int, str]]) -> list[int]:
    """The lines with at least one hit, in order (a line may match several patterns)."""
    return sorted({number for number, _ in found})


def test_shell_dumps_are_found():
    source = "\n".join([
        "#!/bin/sh",
        "printenv",
        "env",
        "env | sort",
        "env > out.txt",
        "out=$(env)",
        "env -0",
        "export -p",
        "declare -p",
        "set",
        "set | grep KEY",
        "xctest --help",
        "xcrun xctest -h",
        "xcodebuild -showBuildSettings -scheme App",
        "set -x",
        "set -eux",
        "bash -x run.sh",
        "if true; then env; fi",
        "sudo env",
    ])
    assert lines_of(shell_violations(source)) == list(range(2, 20))


def test_shell_named_reads_and_env_with_assignments_pass():
    source = "\n".join([
        "#!/usr/bin/env sh",
        "set -eu",
        "set -a",
        '. "$TICKR_ENV_FILE"',
        "set +a",
        "env TICKR_FIXTURES=1 ./app",
        "env -i PATH=/usr/bin ./app",
        'echo "missing: TOUR_API"',
        'test -n "${TOUR_API:-}"',
        "# printenv in a comment",
        "environment=demo",
        "xcodebuild -version",
        "xcodebuild test -scheme App",
    ])
    assert shell_violations(source) == []


WORKFLOW = """\
name: demo
env:
  PLAIN: "1"
jobs:
  quiet-job:
    runs-on: ubuntu-latest
    steps:
      - run: |
          set -x
          make
  secret-job:
    runs-on: ubuntu-latest
    steps:
      - env:
          TOKEN: ${{ secrets.TOKEN }}
        run: |
          set -x
          make
  dump-job:
    runs-on: ubuntu-latest
    steps:
      - run: env
      - run: printenv | sort
      - name: env
        env:
          A: b
"""


def test_workflow_xtrace_only_where_a_secret_is_seen_and_dumps_everywhere():
    assert lines_of(workflow_violations(WORKFLOW)) == [17, 22, 23]


def test_workflow_level_secret_marks_every_job():
    text = WORKFLOW.replace('PLAIN: "1"', "KEY: ${{ secrets.KEY }}")
    assert (lines_of(workflow_violations(text))) == [9, 17, 22, 23]


def test_python_dumps_are_found():
    source = "\n".join([
        "import os",
        "print(os.environ)",
        "print(dict(os.environ))",
        "logger.info('env %s', os.environ)",
        "json.dumps(dict(os.environ))",
        "for k, v in os.environ.items(): pass",
        "names = os.environ.keys()",
        "message = f'{os.environ}'",
        "subprocess.run(['printenv'])",
        "subprocess.run(['env'])",
        "subprocess.run(['xcrun', 'xctest', '--help'])",
        "sys.stderr.write(str(os.environ))",
    ])
    assert lines_of(python_violations(source)) == list(range(2, 13))


def test_python_named_reads_and_passing_on_pass():
    source = "\n".join([
        "value = os.environ.get('TICKR_WRITE_FIXTURES')",
        "value = os.environ['NAME']",
        "os.environ.pop(name, None)",
        "print('missing', name)",
        "env = {**os.environ, 'PYTHONPATH': path}",
        "run_preflight(config_path, environ=os.environ)",
        "print(f'{name} is set: {name in os.environ}')",
        "env = cfg.environment",
        "# print(os.environ) in a comment",
    ])
    assert python_violations(source) == []


def test_swift_whole_environment_is_found():
    source = "\n".join([
        "let environment = ProcessInfo.processInfo.environment",
        "print(ProcessInfo.processInfo.environment)",
        "app.launchEnvironment = ProcessInfo.processInfo.environment",
        "dump(ProcessInfo().environment)",
        "for (k, v) in ProcessInfo.processInfo.environment {}",
    ])
    assert lines_of(swift_violations(source)) == [1, 2, 3, 4, 5]


def test_swift_named_reads_pass():
    source = "\n".join([
        'let api = ProcessInfo.processInfo.environment["TOUR_API"]',
        "guard ProcessInfo.processInfo.environment[Self.key] != nil else { return }",
        "app.launchEnvironment[Self.fixturesKey] = Self.fixturesOn",
        "let raw = model.status?.environment",
        "// ProcessInfo.processInfo.environment in a comment",
    ])
    assert swift_violations(source) == []
