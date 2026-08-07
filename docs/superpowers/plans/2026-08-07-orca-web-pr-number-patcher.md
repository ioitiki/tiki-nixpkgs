# Orca Web PR-Number Patcher Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the packaged Orca PR-number patch derive minified web WorktreeCard identifiers structurally so both Orca 1.4.167 and 1.4.176 patch successfully.

**Architecture:** A focused discovery function will identify the unique WorktreeCard title-row structure, trace its metadata visibility and resolved review bindings, and return the exact anchor, insertion, and JSX compaction calls needed by the existing byte-preserving patch routine. Unit tests use representative old/new minified byte sequences; final verification patches the real extracted ASAR archives before running the updater's Nix build and Cachix push pipeline.

**Tech Stack:** Python 3 standard library (`dataclasses`, `re`, `unittest`), Nix, Electron ASAR, Node.js syntax checking, Ruff, Cachix.

## Global Constraints

- Preserve the compact dynamic `#<PR>` label in both desktop and web WorktreeCard renderers.
- Preserve the exact `resources/app.asar` byte length.
- Require exactly one match at every structural discovery stage and fail with a stage-specific `refusing to patch Orca` error otherwise.
- Retain both right-sidebar overlay replacements, both positioned workspace rows, and both click-outside handlers.
- Preserve the updater-written Orca 1.4.176 version and hashes already present in `packages/orca/package.nix`.
- Do not modify, stage, or commit unrelated dirty changes in `packages/codex/package.nix` or `packages/qwen-code/package.nix`.
- A successful build or Cachix push is not live installation or activation.

---

## File structure

- Create `packages/orca/test_patch_floating_right_sidebar.py`: focused standard-library regression tests and representative minified WorktreeCard fixtures.
- Modify `packages/orca/patch-floating-right-sidebar.py`: structural web context discovery and integration with the existing byte-preserving insertion routine.
- Preserve `packages/orca/package.nix`: the failed updater already wrote the desired 1.4.176 version and hashes; it is an input to acceptance, not an implementation edit.

### Task 1: Discover web WorktreeCard patch context structurally

**Files:**
- Create: `packages/orca/test_patch_floating_right_sidebar.py`
- Modify: `packages/orca/patch-floating-right-sidebar.py:1-65`
- Modify: `packages/orca/patch-floating-right-sidebar.py:197-235`

**Interfaces:**
- Consumes: raw ASAR bytes containing one minified WorktreeCard title-row implementation.
- Produces: `WebPrNumberPatchContext(anchor: bytes, insertion: bytes, jsx_calls: tuple[tuple[bytes, bytes], ...])` and `discover_web_pr_number_context(data: bytes) -> WebPrNumberPatchContext`.

- [ ] **Step 1: Write regression tests for the 1.4.167 and 1.4.176 identifier relationships**

Create a `unittest` module that imports the hyphenated patch script by path and supplies representative one-line minified fixtures. Keep each assertion about a distinct behavior:

```python
import importlib.util
import sys
import unittest
from pathlib import Path


PATCH_PATH = Path(__file__).with_name("patch-floating-right-sidebar.py")
SPEC = importlib.util.spec_from_file_location("orca_sidebar_patcher", PATCH_PATH)
assert SPEC is not None and SPEC.loader is not None
patcher = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = patcher
SPEC.loader.exec_module(patcher)


def web_worktree_fixture(
    *,
    new_card: bytes,
    compact_cards: bytes,
    display: bytes,
    ports: bytes,
    inline_visibility: bytes,
    trailing_visibility: bytes,
    trailing_element: bytes,
    review: bytes,
    runtime: bytes = b"n",
) -> bytes:
    return b"".join(
        (
            display,
            b"=Wt({issue:xe,linearIssue:xt,jiraIssue:vt,review:",
            new_card,
            b"?null:",
            review,
            b",comment:jt,automationProvenance:Ge,cliProvenance:$e}),",
            inline_visibility,
            b"=!",
            new_card,
            b"&&!",
            compact_cards,
            b"&&(",
            display,
            b"||",
            ports,
            b"),",
            trailing_visibility,
            b"=(",
            new_card,
            b"||",
            compact_cards,
            b")&&(",
            display,
            b"||",
            ports,
            b"),",
            trailing_element,
            b"=",
            trailing_visibility,
            b"?(0,",
            runtime,
            b'.jsx)("div",{className:"ml-auto flex shrink-0 items-center gap-1 pr-1.5",children:Ds}):null,',
            b"(0,",
            runtime,
            b'.jsxs)("div",{className:"flex min-w-0 items-center justify-between gap-2",children:[(0,',
            runtime,
            b'.jsxs)("div",{className:"flex min-w-0 flex-1 items-center gap-1.5",children:[]}),',
            trailing_visibility,
            b"&&",
            trailing_element,
            b"]})",
        )
    )


ORCA_1_4_167 = web_worktree_fixture(
    new_card=b"w", compact_cards=b"J", display=b"Pt", ports=b"et",
    inline_visibility=b"ur", trailing_visibility=b"mr",
    trailing_element=b"Yo", review=b"Ke",
)
ORCA_1_4_176 = web_worktree_fixture(
    new_card=b"P", compact_cards=b"V", display=b"st", ports=b"We",
    inline_visibility=b"Ss", trailing_visibility=b"Rs",
    trailing_element=b"Vr", review=b"Re",
)


class WebPrNumberContextTests(unittest.TestCase):
    def discover(self, data: bytes):
        discover = getattr(patcher, "discover_web_pr_number_context", None)
        self.assertIsNotNone(discover, "structural discovery function is missing")
        return discover(data)

    def test_discovers_1_4_167_context(self):
        context = self.discover(ORCA_1_4_167)
        self.assertEqual(context.anchor, b",mr&&Yo]})")
        self.assertIn(b"!w&&!J&&Ke", context.insertion)
        self.assertIn(b'["#",Ke.number]', context.insertion)

    def test_discovers_1_4_176_context(self):
        context = self.discover(ORCA_1_4_176)
        self.assertEqual(context.anchor, b",Rs&&Vr]})")
        self.assertIn(b"!P&&!V&&Re", context.insertion)
        self.assertIn(b'["#",Re.number]', context.insertion)

    def test_rejects_ambiguous_worktree_context(self):
        with self.assertRaisesRegex(
            SystemExit,
            "expected one minified worktree-card title JSX call, found 2",
        ):
            self.discover(ORCA_1_4_176 + ORCA_1_4_176)

    def test_rejects_missing_review_relationship(self):
        malformed = ORCA_1_4_176.replace(b"review:P?null:Re", b"review:Q?null:Re")
        with self.assertRaisesRegex(
            SystemExit,
            "expected one minified worktree-card review binding, found 0",
        ):
            self.discover(malformed)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
python3 packages/orca/test_patch_floating_right_sidebar.py -v
```

Expected: all four tests fail at `structural discovery function is missing`. This proves the current hard-coded implementation does not provide the required structural interface.

- [ ] **Step 3: Add the context type, structural patterns, and discovery function**

In `patch-floating-right-sidebar.py`, import `dataclass`, add identifier-aware
patterns alongside the still-live fixed web constants, and add a separate
dynamic insertion template. Keeping the fixed constants through this task means
the independently committed discovery unit does not regress 1.4.167 before
Task 2 integrates it:

```python
from dataclasses import dataclass


IDENTIFIER = rb"[A-Za-z_$][A-Za-z0-9_$]*"
WORKTREE_PATCH_REGION_LOOKAHEAD = 32768
WEB_WORKTREE_TITLE_JSX_CALL = re.compile(
    rb"\(0,(?P<runtime>" + IDENTIFIER + rb")\.jsxs\)"
    rb'\("div",\{className:"flex min-w-0 items-center justify-between gap-2",'
    rb"children:\[\(0,(?P=runtime)\.jsxs\)"
    rb'\("div",\{className:"flex min-w-0 flex-1 items-center gap-1.5"'
)
WEB_PR_NUMBER_VISIBILITY_BINDINGS = re.compile(
    rb"(?P<inline>" + IDENTIFIER + rb")=!(?P<new_card>" + IDENTIFIER + rb")&&!"
    rb"(?P<compact_cards>" + IDENTIFIER + rb")&&\((?P<display>" + IDENTIFIER
    + rb")\|\|(?P<ports>" + IDENTIFIER + rb")\),(?P<trailing>" + IDENTIFIER
    + rb")=\((?P=new_card)\|\|(?P=compact_cards)\)&&"
    rb"\((?P=display)\|\|(?P=ports)\)"
)
WEB_PR_NUMBER_DYNAMIC_INSERTION_TEMPLATE = (
    b',!__NEW_CARD__&&!__COMPACT_CARDS__&&__REVIEW__&&(0,__RUNTIME__.jsx)("span",'
    b'{className:"ml-auto shrink-0 pr-1.5",'
    b'"data-worktree-card-pr-number":"",children:(0,__RUNTIME__.jsxs)("span",'
    b'{className:"block w-3.5 text-center text-[10px] font-medium leading-none '
    b'text-muted-foreground/80",children:["#",__REVIEW__.number]})})'
)


@dataclass(frozen=True)
class WebPrNumberPatchContext:
    anchor: bytes
    insertion: bytes
    jsx_calls: tuple[tuple[bytes, bytes], ...]
```

Implement `discover_web_pr_number_context(data)` with exact-one gates for the title call, visibility relationship, trailing metadata element, resolved review relationship, and final anchor. The core implementation is:

```python
def discover_web_pr_number_context(data: bytes) -> WebPrNumberPatchContext:
    title_calls = list(WEB_WORKTREE_TITLE_JSX_CALL.finditer(data))
    if len(title_calls) != 1:
        raise SystemExit(
            "refusing to patch Orca: expected one minified worktree-card title "
            f"JSX call, found {len(title_calls)}"
        )
    title_call = title_calls[0]
    runtime = title_call.group("runtime")
    region_start = max(0, title_call.start() - WORKTREE_PATCH_REGION_LOOKBEHIND)
    region_end = min(len(data), title_call.end() + WORKTREE_PATCH_REGION_LOOKAHEAD)
    region = data[region_start:region_end]
    before_title = region[: title_call.start() - region_start]

    visibility_matches = list(WEB_PR_NUMBER_VISIBILITY_BINDINGS.finditer(before_title))
    if len(visibility_matches) != 1:
        raise SystemExit(
            "refusing to patch Orca: expected one minified worktree-card "
            f"visibility binding, found {len(visibility_matches)}"
        )
    visibility = visibility_matches[0]

    trailing_pattern = re.compile(
        rb"(?P<element>" + IDENTIFIER + rb")="
        + re.escape(visibility.group("trailing")) + rb"\?\(0,"
        + re.escape(runtime)
        + rb'\.jsx\)\("div",\{className:"ml-auto flex shrink-0 items-center gap-1 pr-1.5",children:'
        + IDENTIFIER + rb"\}\):null"
    )
    trailing_matches = list(trailing_pattern.finditer(before_title))
    if len(trailing_matches) != 1:
        raise SystemExit(
            "refusing to patch Orca: expected one minified worktree-card "
            f"trailing metadata element, found {len(trailing_matches)}"
        )
    trailing_element = trailing_matches[0].group("element")

    review_pattern = re.compile(
        re.escape(visibility.group("display")) + rb"=" + IDENTIFIER
        + rb"\(\{issue:" + IDENTIFIER + rb",linearIssue:" + IDENTIFIER
        + rb",jiraIssue:" + IDENTIFIER + rb",review:"
        + re.escape(visibility.group("new_card"))
        + rb"\?null:(?P<review>" + IDENTIFIER + rb"),comment:"
    )
    review_matches = list(review_pattern.finditer(before_title))
    if len(review_matches) != 1:
        raise SystemExit(
            "refusing to patch Orca: expected one minified worktree-card "
            f"review binding, found {len(review_matches)}"
        )
    review = review_matches[0].group("review")

    anchor = b"," + visibility.group("trailing") + b"&&" + trailing_element + b"]})"
    anchor_offsets = occurrence_offsets(region, anchor)
    if len(anchor_offsets) != 1:
        raise SystemExit(
            "refusing to patch Orca: expected one web worktree-card PR-number "
            f"anchor, found {len(anchor_offsets)}"
        )

    insertion = WEB_PR_NUMBER_DYNAMIC_INSERTION_TEMPLATE
    for placeholder, value in (
        (b"__NEW_CARD__", visibility.group("new_card")),
        (b"__COMPACT_CARDS__", visibility.group("compact_cards")),
        (b"__REVIEW__", review),
        (b"__RUNTIME__", runtime),
    ):
        insertion = insertion.replace(placeholder, value)

    return WebPrNumberPatchContext(
        anchor=anchor,
        insertion=insertion,
        jsx_calls=(
            (b"(0," + runtime + b".jsx)", runtime + b".jsx"),
            (b"(0," + runtime + b".jsxs)", runtime + b".jsxs"),
        ),
    )
```

Do not change `patch_worktree_card_pr_numbers`, `WEB_PR_NUMBER_ANCHOR`,
`WEB_PR_NUMBER_BINDINGS`, or the existing `WEB_PR_NUMBER_INSERTION_TEMPLATE`
yet. Task 2 owns integration so its test can fail for the correct reason.

- [ ] **Step 4: Run the discovery tests and verify GREEN**

```bash
python3 packages/orca/test_patch_floating_right_sidebar.py -v
```

Expected: four tests pass. The old and new fixtures return their respective anchors and review identifiers; duplicate or malformed structures fail closed.

- [ ] **Step 5: Format and lint the focused files**

```bash
nix shell nixpkgs#ruff -c ruff format packages/orca/patch-floating-right-sidebar.py packages/orca/test_patch_floating_right_sidebar.py
nix shell nixpkgs#ruff -c ruff check packages/orca/patch-floating-right-sidebar.py packages/orca/test_patch_floating_right_sidebar.py
nix shell nixpkgs#ruff -c ruff format --check packages/orca/patch-floating-right-sidebar.py packages/orca/test_patch_floating_right_sidebar.py
```

Expected: both files are formatted and both checks exit 0.

- [ ] **Step 6: Commit the discovery unit**

Stage only the new test and patcher:

```bash
git add packages/orca/patch-floating-right-sidebar.py packages/orca/test_patch_floating_right_sidebar.py
git diff --cached --check
git commit -m "test: cover Orca web PR patch context"
```

Expected: the commit contains only the structural discovery API and its focused tests.

### Task 2: Integrate structural context with byte-preserving insertion

**Files:**
- Modify: `packages/orca/test_patch_floating_right_sidebar.py`
- Modify: `packages/orca/patch-floating-right-sidebar.py:237-290`

**Interfaces:**
- Consumes: `discover_web_pr_number_context(data: bytes) -> WebPrNumberPatchContext` from Task 1 and the existing `insert_pr_number_before_anchor(...)` routine.
- Produces: `patch_worktree_card_pr_numbers(data: bytearray) -> None` that supports both old and renamed minified identifiers without fixed web bindings.

- [ ] **Step 1: Add a failing end-to-end PR-number insertion test**

Append this test to `WebPrNumberContextTests`:

```python
def test_patches_pr_numbers_with_discovered_1_4_176_bindings(self):
    desktop_syntax_space = b"(0, import_jsx_runtime.jsx)" * 256
    web_syntax_space = b"(0,n.jsx)" * 256
    data = bytearray(
        desktop_syntax_space
        + patcher.RENDERER_PR_NUMBER_ANCHOR
        + web_syntax_space
        + ORCA_1_4_176
    )
    original_length = len(data)

    patcher.patch_worktree_card_pr_numbers(data)

    self.assertEqual(len(data), original_length)
    self.assertEqual(data.count(patcher.PR_NUMBER_MARKER), 2)
    self.assertIn(b'["#",Re.number]', data)
```

- [ ] **Step 2: Run the integration test and verify RED**

```bash
python3 packages/orca/test_patch_floating_right_sidebar.py WebPrNumberContextTests.test_patches_pr_numbers_with_discovered_1_4_176_bindings -v
```

Expected: FAIL with `expected one web worktree-card PR-number anchor, found 0` because `patch_worktree_card_pr_numbers` still uses the fixed 1.4.167 anchor.

- [ ] **Step 3: Replace fixed web validation with the discovered context**

Leave desktop insertion unchanged. Delete the fixed `WEB_PR_NUMBER_ANCHOR`,
`WEB_PR_NUMBER_BINDINGS`, and old fixed `WEB_PR_NUMBER_INSERTION_TEMPLATE`
constants. Keep `WEB_PR_NUMBER_DYNAMIC_INSERTION_TEMPLATE` and replace the old
web block in `patch_worktree_card_pr_numbers` with:

```python
web_context = discover_web_pr_number_context(bytes(data))
insert_pr_number_before_anchor(
    data,
    web_context.anchor,
    web_context.insertion,
    web_context.jsx_calls,
    "web",
)
```

Keep duplicate-marker detection and all final marker/count/byte-length checks in `main()` unchanged.

- [ ] **Step 4: Run all focused tests and verify GREEN**

```bash
python3 packages/orca/test_patch_floating_right_sidebar.py -v
```

Expected: five tests pass, including exact length preservation and two PR-number markers for the synthetic desktop plus 1.4.176 web input.

- [ ] **Step 5: Format, lint, and inspect the focused diff**

```bash
nix shell nixpkgs#ruff -c ruff format packages/orca/patch-floating-right-sidebar.py packages/orca/test_patch_floating_right_sidebar.py
nix shell nixpkgs#ruff -c ruff check packages/orca/patch-floating-right-sidebar.py packages/orca/test_patch_floating_right_sidebar.py
nix shell nixpkgs#ruff -c ruff format --check packages/orca/patch-floating-right-sidebar.py packages/orca/test_patch_floating_right_sidebar.py
git diff --check -- packages/orca/patch-floating-right-sidebar.py packages/orca/test_patch_floating_right_sidebar.py
git diff -- packages/orca/patch-floating-right-sidebar.py packages/orca/test_patch_floating_right_sidebar.py
```

Expected: all checks exit 0; the diff changes only web PR-number discovery/integration and focused tests.

- [ ] **Step 6: Commit the integration unit**

```bash
git add packages/orca/patch-floating-right-sidebar.py packages/orca/test_patch_floating_right_sidebar.py
git diff --cached --check
git commit -m "fix: derive Orca web PR patch bindings"
```

Expected: the commit contains only the integration change and its regression test.

### Task 3: Validate real ASAR archives and the build/push acceptance path

**Files:**
- Verify: `packages/orca/patch-floating-right-sidebar.py`
- Verify: `packages/orca/test_patch_floating_right_sidebar.py`
- Preserve dirty input: `packages/orca/package.nix`

**Interfaces:**
- Consumes: the completed patcher, extracted Orca 1.4.167 and 1.4.176 AppImage contents, and the updater-written 1.4.176 package metadata.
- Produces: evidence that both real archives patch safely and that `/home/andy/tiki-nixpkgs#orca-ide` builds and is pushed to `ioitiki`.

- [ ] **Step 1: Re-run local Python and diff checks**

```bash
python3 packages/orca/test_patch_floating_right_sidebar.py -v
nix shell nixpkgs#ruff -c ruff check packages/orca/patch-floating-right-sidebar.py packages/orca/test_patch_floating_right_sidebar.py
nix shell nixpkgs#ruff -c ruff format --check packages/orca/patch-floating-right-sidebar.py packages/orca/test_patch_floating_right_sidebar.py
git diff --check
```

Expected: five tests pass, Ruff exits 0, and `git diff --check` reports no whitespace errors.

- [ ] **Step 2: Patch writable copies of both real ASAR archives**

```bash
orca_verify_dir=$(mktemp -d)
old_asar=/nix/store/gm78i2cxz7s94gpv956ifm8x3s4rmzf2-orca-ide-1.4.167-extracted/resources/app.asar
new_asar=/nix/store/y9ld1aqskib9jwjab3wbdwrfd7z90a6k-orca-ide-1.4.176-extracted/resources/app.asar
cp --no-preserve=mode "$old_asar" "$orca_verify_dir/orca-1.4.167.asar"
cp --no-preserve=mode "$new_asar" "$orca_verify_dir/orca-1.4.176.asar"
wc -c "$old_asar" "$orca_verify_dir/orca-1.4.167.asar" "$new_asar" "$orca_verify_dir/orca-1.4.176.asar"
python3 packages/orca/patch-floating-right-sidebar.py "$orca_verify_dir/orca-1.4.167.asar"
python3 packages/orca/patch-floating-right-sidebar.py "$orca_verify_dir/orca-1.4.176.asar"
wc -c "$old_asar" "$orca_verify_dir/orca-1.4.167.asar" "$new_asar" "$orca_verify_dir/orca-1.4.176.asar"
```

Expected: both patch commands exit 0, and each patched copy has exactly the same byte count as its source archive.

- [ ] **Step 3: Verify exact markers in both patched archives**

```bash
for asar_file in "$orca_verify_dir/orca-1.4.167.asar" "$orca_verify_dir/orca-1.4.176.asar"; do
  test "$(rg -Fao 'absolute inset-y-0 right-0 z-30 flex' "$asar_file" | wc -l)" -eq 2
  test "$(rg -Fao 'relative flex flex-1 min-h-0 overflow-hidden' "$asar_file" | wc -l)" -eq 2
  test "$(rg -Fao 'event.target.closest(".absolute.right-0.z-30")' "$asar_file" | wc -l)" -eq 2
  test "$(rg -Fao 'data-worktree-card-pr-number' "$asar_file" | wc -l)" -eq 2
done
```

Expected: every `test` exits 0 for both releases.

- [ ] **Step 4: Syntax-check modified WorktreeCard and App modules**

```bash
for asar_file in "$orca_verify_dir/orca-1.4.167.asar" "$orca_verify_dir/orca-1.4.176.asar"; do
  archive_name=$(basename "$asar_file" .asar)
  nix shell nixpkgs#asar -c asar list "$asar_file" \
    | rg '^/out/(renderer|web)/assets/(App|WorktreeCard)-[^/]+\.js$' \
    | while read -r member; do
        member_dir="$orca_verify_dir/modules/$archive_name/$(dirname "${member#/}")"
        mkdir -p "$member_dir"
        (
          cd "$member_dir"
          nix shell nixpkgs#asar -c asar extract-file "$asar_file" "${member#/}"
          node --input-type=module --check < "$(basename "$member")"
        )
      done
done
```

Expected: every extracted ES module exits Node syntax checking with status 0.

- [ ] **Step 5: Run the exact updater build/push pipeline**

The updater already changed `package.nix` to 1.4.176 before failing, so run its inner acceptance pipeline directly:

```bash
nix build "$PWD#orca-ide" --no-link --accept-flake-config --print-out-paths \
  | cachix push ioitiki
```

Expected: the command prints the Orca 1.4.176 store output, exits 0, and Cachix reports the output pushed or already present in `ioitiki`.

- [ ] **Step 6: Verify the updater guard and final worktree scope**

```bash
./packages/orca/update.sh
git status --short
git log -3 --oneline --decorate
```

Expected: the updater reports 1.4.176 as latest and current, then exits with `Already at the latest version.` The worktree still shows the updater-written `packages/orca/package.nix` change plus the user's unrelated Codex/Qwen changes; implementation commits contain no unrelated files. Do not claim live activation.
