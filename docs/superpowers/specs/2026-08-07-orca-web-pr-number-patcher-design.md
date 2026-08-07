# Orca Web PR-Number Patcher Compatibility Design

## Goal

Restore `./packages/orca/update.sh` for Orca 1.4.176 without removing the
packaged worktree-card `#<PR>` label. The repair must keep the existing desktop
and web customizations, preserve the exact `resources/app.asar` byte length,
fail closed when upstream structure is ambiguous, and complete the updater's
existing Nix build and Cachix push path.

## Root cause

The desktop WorktreeCard source-form anchor remains present in Orca 1.4.176.
The web bundle still renders the same title row, resolved review, metadata
visibility, and trailing metadata element, but minification renamed every local
identifier used by the patcher's hard-coded web anchor and binding checks. The
old `,mr&&Yo]})` anchor is therefore absent even though the intended insertion
point still exists.

Hard-coding the new 1.4.176 identifiers would restore this release but repeat
the same failure on a future harmless minifier rename. Repacking extracted ASAR
members would add tooling and could disturb archive offsets. The patcher will
instead derive the renamed identifiers from their stable structural
relationships inside the minified WorktreeCard implementation.

## Structural discovery

Add a focused web PR-number context discovery function to
`packages/orca/patch-floating-right-sidebar.py`. It will:

1. Find the unique paired visibility bindings for inline and trailing metadata.
   This relationship yields the new-card flag, compact-card flag, metadata
   display value, ports value, and trailing-visibility value.
2. Find the unique trailing metadata JSX element controlled by that visibility
   value and its stable class list. This yields the element name and JSX runtime.
3. Trace the metadata display construction back to its `review` property. This
   yields the resolved review object whose `number` is shown in the label.
4. Construct the exact trailing title-row anchor from the derived visibility
   and element names, then verify that the existing title-row JSX call is unique
   in the bounded WorktreeCard context.

The generated insertion will use the derived new-card flag, compact-card flag,
JSX runtime, and resolved review object. Existing syntax-space recovery and
padding will keep the renderer member and enclosing ASAR exactly the same size.

## Failure handling

Every discovery stage must produce exactly one match. Zero or multiple matches,
an inconsistent back-reference, a missing title-row call, an existing marker,
insufficient recoverable syntax space, or a byte-length mismatch will abort the
build with a stage-specific `refusing to patch Orca` message. The existing final
checks for two overlay sidebars, two positioned workspace rows, both
click-outside handlers, and two PR-number markers remain unchanged.

This retains the current fail-closed contract: an upstream semantic change
requires inspection instead of allowing a partially patched application.

## Testing and acceptance

Before changing production logic, add a focused regression test that presents
the 1.4.176 minified relationship and expects structural discovery to return its
renamed identifiers and resolved review object. Confirm that it fails against
the current hard-coded implementation. Cover the 1.4.167 relationship as a
compatibility case and malformed or ambiguous input as fail-closed cases.

After implementation, patch writable copies of the extracted 1.4.167 and
1.4.176 ASAR archives. For both versions, verify unchanged byte length, exactly
two PR-number markers, retained sidebar and click-outside markers, and syntax
validity of the extracted renderer modules. Run Ruff formatting and lint checks
on the patcher and `git diff --check` on the touched files.

Because the failed updater already wrote the 1.4.176 version and hashes into
`package.nix`, final acceptance will run its exact inner pipeline directly:
`nix build "$PWD#orca-ide" --no-link --accept-flake-config --print-out-paths |
cachix push ioitiki`. A subsequent `./packages/orca/update.sh` run must take its
latest-version guard successfully. A successful build or push does not imply
that the package was installed or activated on the live system.

## Scope and ownership

The implementation will touch only the Orca patcher and its focused regression
test. The updater's existing version and hashes in `packages/orca/package.nix`
are preserved. Unrelated dirty changes in the Codex and Qwen packages will not
be modified, staged, or committed. No live activation, branch publication, or
NixOS configuration change is part of this repair.
